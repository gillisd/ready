module Ready
  module Bench
    ##
    # The shared append-only file every instrumented process writes marks
    # into, one line per mark: "<run_id> <mark_name> <clock_realtime_seconds>".
    # zsh's $EPOCHREALTIME and Ruby's Process::CLOCK_REALTIME read the same
    # wall clock, so lines from either side subtract cleanly.
    class MarksLog
      attr_reader :path

      def initialize(path)
        @path = Pathname(path)
      end

      def run(id)
        lines = lines_for(id)
        Run.new(id:, mark_times: mark_times(lines), exit_status: exit_status(lines))
      end

      private

      def lines_for(id)
        return [] unless path.exist?

        path.readlines.map(&:split).select { |line| line.length == 3 && line.first == id }
      end

      # A malformed line (e.g. a mark whose shell left the timestamp empty) is
      # skipped rather than crashing the run: the span that needed it simply
      # goes unmeasured. The exit_status line is not a timestamp, so it is
      # excluded here and read separately.
      def mark_times(lines)
        lines.reject { |line| line[1] == "exit_status" }
             .to_h { |_run_id, mark_name, seconds| [mark_name.to_sym, Float(seconds)] }
      end

      def exit_status(lines)
        status = lines.find { |line| line[1] == "exit_status" }
        status && Integer(status[2])
      end
    end
  end
end
