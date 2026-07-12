require "bundler"
require "English"
require "fileutils"
require "tmpdir"
require "rbconfig"

module Ready
  module Bench
    ##
    # Orchestrates the interleaved cold/hot layer benchmark: builds a warm
    # sandbox, runs the cold (instrumented rbenv/rubygems copies) and hot (ready
    # dispatch) arms interleaved, aggregates per-span, and renders the waterfall.
    class Runner
      PROCESS_SPANS = %w[shell launch dispatch_infra full].freeze

      attr_reader :cold, :hot, :rbenv_overhead, :exe

      def initialize(exe: "irb", lib: "irb", runs: 15, warmups: 3, rbenv: nil)
        @exe = exe
        @lib = lib
        @runs = runs
        @warmups = warmups
        @rbenv = rbenv || system("command -v rbenv >/dev/null 2>&1")
        @cold_runs = []
        @hot_runs = []
        @rbenv_launch = []
      end

      def call
        build
        (1..(@runs + @warmups)).each { |i| round(i) }
        agg = Aggregator.new(span_kind: PROCESS_SPANS.to_h { |s| [s, :min] })
        @cold = agg.combine(@cold_runs.drop(@warmups))
        @hot = agg.combine(@hot_runs.drop(@warmups))
        derive_rbenv_overhead
        self
      ensure
        teardown
      end

      def report
        Report.new(
          { "cold" => [@cold], "hot" => [@hot] },
          { "cold" => walls(@cold_runs), "hot" => walls(@hot_runs) },
        )
      end

      def render
        report.render
        return unless @rbenv_overhead

        puts format("\nrbenv shim overhead (cold, eliminated hot): +%<o>.1fms  " \
                    "(real cold full ~= %<t>.1fms)", o: @rbenv_overhead, t: @cold["full"] + @rbenv_overhead)
      end

      def teardown
        @sandbox&.teardown
        FileUtils.rm_rf(@tmp) if @tmp
      end

      private

      def walls(runs)
        runs.drop(@warmups).filter_map { |s| s["full"]&./(1000.0) }
      end

      def derive_rbenv_overhead
        return unless @rbenv

        floor = @rbenv_launch.drop(@warmups).min
        @rbenv_overhead = floor && @cold["launch"] ? floor - @cold["launch"] : nil
      end

      def build
        @tmp = Pathname(Dir.mktmpdir("bench"))
        @marks = @tmp / "marks"
        @marks.write("")
        @sandbox = Ready::Sandbox.build(executables: ["rake"], gems: [@lib])
        @exe_path = resolve_exe_path
        @cold_arm = ColdArm.new(exe: @exe, workdir: @tmp / "cold", marks_path: @marks)
        @cold_arm.instrument!
        @hot_arm = HotArm.new(exe: @exe, exe_path: @exe_path, sandbox: @sandbox, marks_path: @marks)
        (@tmp / "stub.zsh").write(@hot_arm.stub_function)
      end

      # irb is a default (unbundled) gem, so resolve its exe in a scrubbed env
      # where GEM_PATH/GEM_HOME/BUNDLE point at ruby's own default gems. The
      # returned path contains "exe", so Executable inlines it via its direct
      # branch without a resolver change.
      def resolve_exe_path
        expr = "print Gem.activate_bin_path(#{@lib.inspect}, #{@exe.inspect})"
        out = Bundler.with_unbundled_env do
          IO.popen({ "GEM_HOME" => nil, "GEM_PATH" => nil }, [RbConfig.ruby, "-e", expr], &:read)
        end
        raise "cannot resolve #{@exe} exe path: #{out}" unless $CHILD_STATUS.success? && !out.empty?

        Pathname(out.strip)
      end

      def round(iteration)
        order = iteration.even? ? %i[cold hot] : %i[hot cold]
        order.each { |arm| send(:"run_#{arm}", "#{arm}.#{iteration}") }
        run_rbenv("rbenv.#{iteration}") if @rbenv
      end

      def run_cold(run_id) = cold_dispatch(run_id, direct: true) { |s| @cold_runs << s }
      def run_rbenv(run_id) = cold_dispatch(run_id, direct: false) { |s| @rbenv_launch << s["launch"] if s["launch"] }

      def cold_dispatch(run_id, direct:)
        Bundler.with_unbundled_env do
          drop_stale_gem_home
          shell = Ready::PtyShell.new(@cold_arm.env(run_id:))
          shell.run("source #{Ready.root / "bench" / "prof.zsh"}")
          shell.run("bench_envelope #{run_id} -- #{@cold_arm.command(direct:)} --version >/dev/null 2>&1")
          yield spans_for(run_id)
        ensure
          shell&.close
        end
      end

      # Dispatch from a bundler-free shell (a real user terminal is unbundled) so
      # the by client isn't slowed by an inherited RUBYOPT=-rbundler/setup.
      def run_hot(run_id)
        Bundler.with_unbundled_env do
          drop_stale_gem_home
          shell = Ready::PtyShell.new(@sandbox.shell_env)
          shell.run(hot_setup(run_id))
          shell.run("bench_envelope #{run_id} -- ready_#{@exe} --version >/dev/null 2>&1")
          @hot_runs << spans_for(run_id)
        ensure
          shell&.close
        end
      end

      def hot_setup(run_id)
        ["source #{@sandbox.plugin_path}",
         "source #{Ready.root / "bench" / "prof.zsh"}",
         @hot_arm.shell_setup(run_id:),
         "source #{@tmp / "stub.zsh"}"].join("; ")
      end

      def spans_for(run_id)
        Marks.spans(Marks.parse(@marks.to_s)[run_id] || {})
      end

      def drop_stale_gem_home
        %w[GEM_HOME GEM_PATH].each { |v| ENV.delete(v) if ENV[v] && !File.directory?(ENV[v]) }
      end
    end
  end
end
