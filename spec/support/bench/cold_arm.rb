require "fileutils"
require "rbconfig"

module Ready
  module Bench
    ##
    # Generates faithful, mark-instrumented COPIES of the real rbenv shim and
    # rubygems stub for a gem executable, so a cold invocation can be attributed
    # per layer without touching any real file. Two shim variants: `rbenv` runs
    # the real `rbenv exec` chain (its launch span carries the rbenv cost),
    # `direct` execs the instrumented stub copy under the version ruby (no rbenv)
    # and carries the stub sub-spans.
    class ColdArm
      # Mark helper + at_exit, inserted verbatim (single-quoted heredoc keeps the
      # interpolations literal, so they run inside the instrumented stub).
      HELPER = <<~'RUBY'.freeze
        def __bmark(n)
          File.write(ENV.fetch("READY_MARKS"), "#{ENV.fetch('READY_RUN_ID')} #{n} #{Process.clock_gettime(Process::CLOCK_REALTIME)}\n", mode: "a")
        end
        at_exit { __bmark("ruby_exit") }
      RUBY

      # The two stub forms that activate + load the tool, each capturing (indent,
      # gem-exe-version args) so we can split activation from the require.
      ACTIVATION_LINES = [
        /^(\s*)Gem\.activate_and_load_bin_path\((.*)\)/,
        /^(\s*)load Gem\.activate_bin_path\((.*)\)/,
      ].freeze

      # Rewrites a standard rubygems stub so it emits rubygems_ready /
      # dep_activated / bin_path_resolved, splitting Gem activation from the
      # tool require so each is its own span.
      def self.instrument_stub(src)
        out = src.sub(/\A(#!.*\n)?/) { "#{Regexp.last_match(1)}#{HELPER}" }
        out = out.sub(/(Gem\.use_gemdeps.*\n)/) { "#{Regexp.last_match(1)}__bmark('rubygems_ready')\n" }
        ACTIVATION_LINES.each do |re|
          out = out.gsub(re) { split_activation(Regexp.last_match(1), Regexp.last_match(2)) }
        end
        out
      end

      def self.split_activation(indent, args)
        "#{indent}__bmark('dep_activated'); " \
          "__bp = Gem.activate_bin_path(#{args}); " \
          "__bmark('bin_path_resolved'); load __bp"
      end

      def initialize(exe:, workdir:, marks_path:)
        @exe = exe
        @workdir = Pathname(workdir)
        @marks_path = Pathname(marks_path)
      end

      def real_shim = Pathname(File.expand_path("~/.rbenv/shims/#{@exe}"))
      def real_stub = Pathname(`rbenv which #{@exe}`.strip)

      def instrument!
        FileUtils.mkdir_p(@workdir)
        (@workdir / "stub").write(self.class.instrument_stub(real_stub.read))
        write_shim(@workdir / @exe, rbenv: true)
        write_shim(@workdir / "#{@exe}_direct", rbenv: false)
      end

      # Command word for a run: `<exe>` (rbenv arm) or `<exe>_direct`.
      def command(direct:) = direct ? "#{@exe}_direct" : @exe

      # Env a shell must export before running the arm.
      def env(run_id:)
        {
          "READY_MARKS" => @marks_path.to_s,
          "READY_RUN_ID" => run_id,
          "PATH" => "#{@workdir}:#{ENV.fetch("PATH", nil)}",
        }
      end

      private

      def write_shim(path, rbenv:)
        prelude = Ready.root / "bench" / "prelude.rb"
        target = if rbenv
                   %(exec rbenv exec "#{@exe}" "$@")
                 else
                   %(exec "#{RbConfig.ruby}" "#{@workdir / "stub"}" "$@")
                 end
        path.write(<<~SH)
          #!/usr/bin/env bash
          set -e
          printf '%s shim_start %s\\n' "$READY_RUN_ID" "$EPOCHREALTIME" >> "$READY_MARKS"
          export RUBYOPT="-r#{prelude}${RUBYOPT:+ $RUBYOPT}"
          export RBENV_ROOT="$HOME/.rbenv"
          #{target}
        SH
        path.chmod(0o755)
      end
    end
  end
end
