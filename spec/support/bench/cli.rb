require "command_kit/command"
require "English"
require "rbconfig"

module Ready
  module Bench
    ##
    # Development-only ergonomic front door for the benchmark rake tasks. It
    # owns no benchmark logic: flags become the BENCH_* environment the tasks
    # already read, --verbose picks bench:verbose over bench, and rake does
    # the proven work. Only what the user chose is exported, so the rake
    # task's own defaults cover everything else.
    class CLI < CommandKit::Command
      command_name "bench"

      usage "[options] [EXECUTABLE [ARGUMENT ...]]"

      option :library, value: { type: String, usage: "NAME" },
                       desc: "Gem that ships EXECUTABLE, preloaded into the warm server so the " \
                             "hot arm's requires are already paid (default: rdoc, which ships ri)"

      option :rounds, value: { type: Integer, usage: "N" },
                      desc: "Measured rounds per arm (default: 15)"

      option :warmups, value: { type: Integer, usage: "N" },
                       desc: "Warmup rounds, recorded but excluded (default: 3)"

      option :verbose, short: "-v",
                       desc: "Append the span legend and the terms table"

      argument :executable, required: false,
                            usage: "EXECUTABLE",
                            desc: "Executable under test (default: ri)"

      argument :arguments, required: false,
                           repeats: true,
                           usage: "ARGUMENT",
                           desc: "Arguments that make it do real work (default: TCPServer)"

      description "Benchmark a CLI cold (fresh boot) vs hot (ready dispatch); needs zsh + by-server + rbenv"

      examples [
        "",
        "ronin help --library ronin",
        "--rounds 5 --warmups 1 --verbose",
      ]

      #
      # Translates the parsed invocation into environment + task and hands
      # off to rake.
      #
      def run(executable = nil, *arguments)
        run_rake(environment_for(executable, arguments), task_name)
      end

      #
      # The BENCH_* environment for the rake task: only the knobs the user
      # actually turned.
      #
      def environment_for(executable, arguments)
        {
          "BENCH_EXE" => executable,
          "BENCH_ARGS" => arguments.empty? ? nil : arguments.join(" "),
          "BENCH_LIB" => options[:library],
          "BENCH_RUNS" => options[:rounds]&.to_s,
          "BENCH_WARMUPS" => options[:warmups]&.to_s,
        }.compact
      end

      #
      # Which of the two proven tasks to run.
      #
      def task_name
        options[:verbose] ? "bench:verbose" : "bench"
      end

      private

      def run_rake(environment, task)
        return if system(environment, RbConfig.ruby, "-S", "rake", task, chdir: Ready.root.to_s)

        exit($CHILD_STATUS&.exitstatus || 1)
      end
    end
  end
end
