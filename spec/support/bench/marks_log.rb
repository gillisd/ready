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
        Run.new(id:, mark_times: mark_times_for(id))
      end

      private

      # A malformed line (e.g. a mark whose shell left the timestamp empty) is
      # skipped rather than crashing the run: the span that needed it simply
      # goes unmeasured.
      def mark_times_for(id)
        return {} unless path.exist?

        path.readlines
            .map(&:split)
            .select { |fields| fields.length == 3 && fields.first == id }
            .to_h { |_run_id, mark_name, seconds| [mark_name.to_sym, Float(seconds)] }
      end
    end
  end
end
