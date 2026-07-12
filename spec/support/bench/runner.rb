require "bundler"
require "English"
require "fileutils"
require "tmpdir"
require "rbconfig"

module Ready
  module Bench
    ##
    # Orchestrates the interleaved cold/hot layer benchmark. Each round runs
    # both arms (order alternating to cancel drift), every run's marks land in
    # one MarksLog, and each arm accumulates its runs' waterfalls in an
    # ArmResult. When rbenv is present, each round also probes the real rbenv
    # shim to derive the shim overhead the hot path eliminates.
    class Runner
      attr_reader :rbenv_shim_overhead

      def initialize(executable: "irb", library: "irb", rounds: 15, warmups: 3, rbenv: rbenv_available?)
        @protocol = Protocol.new(executable_name: executable, library:, rounds:, warmups:)
        @rbenv = rbenv
        @cold_result = ArmResult.new(name: :cold, warmups:)
        @hot_result = ArmResult.new(name: :hot, warmups:)
        @rbenv_launch_samples = []
      end

      def executable_name
        @protocol.executable_name
      end

      def call
        build
        (1..(@protocol.rounds + @protocol.warmups)).each { round(it) }
        derive_rbenv_shim_overhead
        self
      ensure
        teardown
      end

      def cold_summary
        @cold_result.summary
      end

      def hot_summary
        @hot_result.summary
      end

      def report(verbose: false)
        Report.new(cold: @cold_result, hot: @hot_result, protocol: @protocol,
                   rbenv_shim_overhead:, verbose:)
      end

      def render(verbose: false)
        report(verbose:).render
      end

      def teardown
        @sandbox&.teardown
        FileUtils.rm_rf(@tmp) if @tmp
      end

      private

      def build
        @tmp = Pathname(Dir.mktmpdir("bench"))
        @marks_log = MarksLog.new(@tmp / "marks")
        @sandbox = Ready::Sandbox.build(executables: ["rake"], gems: [@protocol.library])
        @cold_arm = ColdArm.new(executable_name:, workdir: @tmp / "cold", marks_log: @marks_log)
        @cold_arm.instrument!
        @hot_arm = HotArm.new(executable_name:, rendered_source: render_production_source,
                              sandbox: @sandbox, marks_log: @marks_log)
        (@tmp / "stub.zsh").write(@hot_arm.stub_function)
      end

      # Renders the hot stub source the way production `ready gem <name>`
      # does: by NAME, so Executable resolves via Gem.bin_path and reads the
      # real file whether the binstub lives in bin/ or exe/. Runs in a
      # scrubbed, unbundled subprocess because the bench itself runs under
      # this project's bundle, where the target (e.g. ronin) is not a bundled
      # gem.
      def render_production_source
        script = "require \"ready\"; print Ready::Executable.new(#{executable_name.inspect}).render"
        output = Bundler.with_unbundled_env do
          IO.popen({ "GEM_HOME" => nil, "GEM_PATH" => nil },
                   [RbConfig.ruby, "-I", (Ready.root / "lib").to_s, "-e", script], &:read)
        end
        raise "cannot render #{executable_name}: #{output}" unless $CHILD_STATUS.success? && !output.empty?

        output
      end

      # Cold-first on even rounds, hot-first on odd, so run-order drift
      # cancels out across the session.
      def round(number)
        if number.even?
          run_cold("cold.#{number}")
          run_hot("hot.#{number}")
        else
          run_hot("hot.#{number}")
          run_cold("cold.#{number}")
        end
        probe_rbenv_shim("rbenv.#{number}") if @rbenv
      end

      def run_cold(run_id)
        measurement = cold_invocation(run_id, shim: @cold_arm.direct_shim)
        @cold_result.record(measurement)
      end

      # The rbenv variant exists only to isolate the real shim's cost: its
      # :launch also carries the `rbenv exec` chain, so min(rbenv launch)
      # minus the direct arm's launch floor is the shim overhead.
      def probe_rbenv_shim(run_id)
        measurement = cold_invocation(run_id, shim: @cold_arm.rbenv_shim)
        launch = measurement.waterfall.duration_of(:launch)
        @rbenv_launch_samples << launch if launch
      end

      def cold_invocation(run_id, shim:)
        Bundler.with_unbundled_env do
          drop_stale_gem_home
          shell = Ready::PtyShell.new(@cold_arm.environment_for(run_id:))
          shell.run("source #{profiler_path}")
          harness_run = shell.run(harness_command(run_id, shim.command_word))
          measurement_for(run_id, harness_run)
        ensure
          shell&.close
        end
      end

      # Dispatches from a bundler-free shell (a real user terminal is
      # unbundled) so the by client isn't slowed by a bundler/setup require
      # inherited through RUBYOPT.
      def run_hot(run_id)
        Bundler.with_unbundled_env do
          drop_stale_gem_home
          shell = Ready::PtyShell.new(@sandbox.shell_env)
          shell.run(hot_setup(run_id))
          harness_run = shell.run(harness_command(run_id, "ready_#{executable_name}"))
          measurement = measurement_for(run_id, harness_run)
          @hot_result.record(measurement)
        ensure
          shell&.close
        end
      end

      def harness_command(run_id, command_word)
        "bench_harness #{run_id} -- #{command_word} --version >/dev/null 2>&1"
      end

      def hot_setup(run_id)
        ["source #{@sandbox.plugin_path}",
         "source #{profiler_path}",
         @hot_arm.shell_setup(run_id:),
         "source #{@tmp / "stub.zsh"}"].join("; ")
      end

      def profiler_path
        Ready.root / "bench" / "prof.zsh"
      end

      # Pairs the run's in-shell waterfall with the wall clock the pty driver
      # observed for the harness command.
      def measurement_for(run_id, harness_run)
        run = @marks_log.run(run_id)
        Measurement.new(waterfall: Waterfall.of(run), wall_clock_seconds: harness_run.wall_clock_seconds)
      end

      def derive_rbenv_shim_overhead
        return unless @rbenv

        samples = @rbenv_launch_samples.drop(@protocol.warmups)
        direct_launch = cold_summary.duration_of(:launch)
        return if samples.empty? || direct_launch.nil?

        @rbenv_shim_overhead = samples.min - direct_launch
      end

      def drop_stale_gem_home
        %w[GEM_HOME GEM_PATH].each { ENV.delete(it) if ENV[it] && !File.directory?(ENV[it]) }
      end

      # Evaluated only when the caller lets rbenv default: the cold arm cannot
      # resolve stubs without rbenv, so a missing rbenv fails fast here rather
      # than deep inside the first round. Tests that skip the rbenv probe pass
      # rbenv: false explicitly and never reach this.
      def rbenv_available?
        system("command -v rbenv >/dev/null 2>&1", exception: true)
      end
    end
  end
end
