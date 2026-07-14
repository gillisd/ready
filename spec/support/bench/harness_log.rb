module Ready
  module Bench
    ##
    # The append-only log every measured command tees its stdout+stderr into,
    # so a tool that fails silently leaves evidence in ./log/bench.log instead
    # of being timed as a fast "success". Persisted in the project tree so it
    # survives across runs; each run's output is headed by its run id.
    class HarnessLog
      attr_reader :path

      def initialize(invocation:)
        @invocation = invocation
        @path = Ready.root / "log" / "bench.log"
      end

      # Creates ./log and heads this run's section so appended runs stay legible.
      def open!
        path.dirname.mkpath
        path.open("a") { it.puts("\n===== #{@invocation} =====") }
        self
      end

      # Shell fragment teeing a command's stdout+stderr here under a run-id
      # header; the pty still sees nothing (>/dev/null), so marker sync holds.
      def tee(run_id, command)
        "{ print -r -- '### #{run_id} ###'; #{command}; } 2>&1 | tee -a #{path} >/dev/null"
      end
    end
  end
end
