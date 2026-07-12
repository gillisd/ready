require "command_kit/command"
require "English"
require "rbconfig"
require "tmpdir"

module Ready
  module Bench
    ##
    # Development-only ergonomic front door for the benchmark rake tasks. It
    # owns no benchmark logic: flags become the BENCH_* environment the tasks
    # already read, each command gets its own proven `rake bench` run, and
    # --plot charts the collected results with youplot afterwards. Only what
    # the user chose is exported, so the rake task's own defaults cover
    # everything else.
    class CLI < CommandKit::Command
      command_name "bench"

      usage "[options] [COMMAND [ARGUMENT ...]] [-- COMMAND [ARGUMENT ...]]..."

      option :readyfile, value: { type: String, usage: "PATH" },
                         desc: "Readyfile whose gems: the warm server preloads; with no " \
                               "COMMANDs given, every executable it declares is benched"

      option :rounds, value: { type: Integer, usage: "N" },
                      desc: "Measured rounds per arm (default: 15)"

      option :warmups, value: { type: Integer, usage: "N" },
                       desc: "Warmup rounds, recorded but excluded (default: 3)"

      option :verbose, short: "-v",
                       desc: "Append the span legend and the terms table"

      option :plot, value: {
                      type: { "stacked" => :stacked, "youplot" => :youplot },
                    },
                    desc: "Chart cold vs hot per command after the runs: stacked draws one " \
                          "bar per command (hot segment + what ready eliminates), youplot " \
                          "draws stock side-by-side pairs"

      argument :command, required: false,
                         repeats: true,
                         usage: "COMMAND [ARGUMENT ...]",
                         desc: "Command to benchmark, exactly as you would type it; " \
                               "separate several with -- (default: ri TCPServer)"

      description "Benchmark CLIs cold (fresh boot) vs hot (ready dispatch); needs zsh + by-server + rbenv"

      examples [
        "",
        "ri TCPServer",
        "--readyfile readyfile ri TCPServer -- ronin help -- kamal version",
        "--readyfile readyfile --plot stacked",
      ]

      #
      # Splits argv into command segments on `--` before options are parsed
      # (OptionParser would otherwise eat the first separator). Flags belong
      # in the first segment; later segments are commands, verbatim.
      #
      def self.command_segments(argv)
        argv.each_with_object([[]]) do |word, segments|
          word == "--" ? segments << [] : segments.last << word
        end
      end

      def main(argv = [])
        first_segment, *rest = self.class.command_segments(argv)
        @extra_command_segments = rest
        super(first_segment || [])
      end

      #
      # One proven rake run per command, then the optional chart.
      #
      def run(*command_words)
        segments = [command_words, *@extra_command_segments].reject(&:empty?)
        invocations_under_test(segments).each do |invocation|
          run_rake(environment_for(invocation), task_name)
        end
        plot_results if options[:plot]
      end

      #
      # The commands to bench: the typed segments, else everything the
      # readyfile declares (bare), else [nil] -- one run on the rake task's
      # default.
      #
      def invocations_under_test(segments)
        return segments.map { Invocation.parse(it) } unless segments.empty?
        return [nil] unless readyfile

        readyfile.executable_names.map { Invocation.bare(it) }
      end

      #
      # The BENCH_* environment for one rake run: only the knobs the user
      # actually turned. A typed command is exported verbatim -- executable
      # and arguments both -- so what you typed is what runs.
      #
      def environment_for(invocation)
        flag_environment.merge(command_environment(invocation)).compact
      end

      #
      # Which of the two proven tasks to run.
      #
      def task_name
        options[:verbose] ? "bench:verbose" : "bench"
      end

      #
      # The renderer for the chosen --plot style: our stacked bars, or the
      # stock youplot pairs.
      #
      def plotter_for(style, comparisons)
        case style
        in :stacked then Plot::Stacked.new(comparisons)
        in :youplot then Plot::Youplot.new(comparisons)
        end
      end

      private

      def flag_environment
        {
          "BENCH_READYFILE" => options[:readyfile],
          "BENCH_RUNS" => options[:rounds]&.to_s,
          "BENCH_WARMUPS" => options[:warmups]&.to_s,
          "BENCH_RESULTS" => (results_path.to_s if options[:plot]),
        }
      end

      def command_environment(invocation)
        return {} unless invocation

        {
          "BENCH_EXE" => invocation.executable_name,
          "BENCH_ARGS" => invocation.arguments.join(" "),
        }
      end

      # Only gem/executable names are read; Readyfile demands an existing
      # build_dir regardless, so the readyfile's own parent satisfies it.
      def readyfile
        return nil unless options[:readyfile]

        @readyfile ||= begin
          path = Pathname(options[:readyfile])
          Ready::Readyfile.open(path, build_dir: path.expand_path.parent)
        end
      end

      # Where each rake run appends its "executable,arm,full_ms" rows.
      def results_path
        @results_path ||= Pathname(Dir.mktmpdir("bench")) / "results.csv"
      end

      # Reads back every run's results and renders them in the chosen style.
      def plot_results
        comparisons = ResultsLog.new(results_path).comparisons
        plotter_for(options[:plot], comparisons).render
      end

      def run_rake(environment, task)
        return if system(environment, RbConfig.ruby, "-S", "rake", task, chdir: Ready.root.to_s)

        exit($CHILD_STATUS&.exitstatus || 1)
      end
    end
  end
end
