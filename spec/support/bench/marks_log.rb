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

      def mark_times_for(id)
        return {} unless path.exist?

        path.readlines
            .map(&:split)
            .select { |run_id, _mark_name, _seconds| run_id == id }
            .to_h { |_run_id, mark_name, seconds| [mark_name.to_sym, Float(seconds)] }
      end
    end
  end
end
