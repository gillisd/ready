require "command_kit/command"
require "English"
require "rbconfig"
require "tmpdir"

module Ready
  module Bench
    ##
    # Development-only ergonomic front door for the benchmark rake tasks. It
    # owns no benchmark logic: flags become the BENCH_* environment the tasks
    # already read, each executable gets its own proven `rake bench` run, and
    # --plot charts the collected results with youplot afterwards. Only what
    # the user chose is exported, so the rake task's own defaults cover
    # everything else.
    class CLI < CommandKit::Command
      command_name "bench"

      usage "[options] [EXECUTABLE ...]"

      option :readyfile, value: { type: String, usage: "PATH" },
                         desc: "Readyfile whose gems: the warm server preloads; with no " \
                               "EXECUTABLEs given, every executable it declares is benched"

      option :args, value: { type: String, usage: "STRING" },
                    desc: "Arguments making the tool do real work, applied to each " \
                          "executable (default: TCPServer, for the default ri)"

      option :rounds, value: { type: Integer, usage: "N" },
                      desc: "Measured rounds per arm (default: 15)"

      option :warmups, value: { type: Integer, usage: "N" },
                       desc: "Warmup rounds, recorded but excluded (default: 3)"

      option :verbose, short: "-v",
                       desc: "Append the span legend and the terms table"

      option :plot, desc: "Chart the cold vs hot full times with youplot after the runs"

      argument :executables, required: false,
                             repeats: true,
                             usage: "EXECUTABLE",
                             desc: "Executables under test (default: ri, or the readyfile's)"

      description "Benchmark CLIs cold (fresh boot) vs hot (ready dispatch); needs zsh + by-server + rbenv"

      examples [
        "",
        "--readyfile readyfile ri ronin kamal",
        "--readyfile readyfile --plot",
        "ri --args TCPServer --rounds 5 --warmups 1 --verbose",
      ]

      #
      # One proven rake run per executable, then the optional chart.
      #
      def run(*executables)
        executables_under_test(executables).each do |executable|
          run_rake(environment_for(executable), task_name)
        end
        plot_results if options[:plot]
      end

      #
      # The executables to bench: the positional ones, else everything the
      # readyfile declares, else [nil] -- one run on the rake task's default.
      #
      def executables_under_test(executables)
        return executables unless executables.empty?
        return [nil] unless readyfile

        readyfile.executable_names
      end

      #
      # The BENCH_* environment for one rake run: only the knobs the user
      # actually turned.
      #
      def environment_for(executable)
        {
          "BENCH_EXE" => executable,
          "BENCH_ARGS" => options[:args],
          "BENCH_READYFILE" => options[:readyfile],
          "BENCH_RUNS" => options[:rounds]&.to_s,
          "BENCH_WARMUPS" => options[:warmups]&.to_s,
          "BENCH_RESULTS" => (results_path.to_s if options[:plot]),
        }.compact
      end

      #
      # Which of the two proven tasks to run.
      #
      def task_name
        options[:verbose] ? "bench:verbose" : "bench"
      end

      private

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

      # Feeds "label,value" lines to youplot's barplot -- one bar per
      # executable+arm, so cold and hot sit side by side.
      def plot_results
        bars = results_path.readlines(chomp: true).map do |row|
          executable, arm, full_milliseconds = row.split(",")
          "#{executable} #{arm},#{Float(full_milliseconds).round(1)}"
        end
        uplot = Gem.bin_path("youplot", "uplot")
        IO.popen([RbConfig.ruby, uplot, "bar", "-d", ",", "-t", "full startup (ms): cold vs hot"], "w") do |pipe|
          pipe.puts(bars)
        end
      end

      def run_rake(environment, task)
        return if system(environment, RbConfig.ruby, "-S", "rake", task, chdir: Ready.root.to_s)

        exit($CHILD_STATUS&.exitstatus || 1)
      end
    end
  end
end
