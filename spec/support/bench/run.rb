module Ready
  module Bench
    ##
    # One timed invocation of the tool under one arm, identified by its run id
    # ("cold.3" is round 3's cold invocation). A run holds the wall-clock
    # instant of every mark its instrumented layers recorded; Spans measure
    # themselves by asking the run for the time between two marks.
    class Run
      attr_reader :id, :exit_status

      def initialize(id:, mark_times:, exit_status: nil)
        @id = id
        @mark_times = mark_times.dup.freeze
        @exit_status = exit_status
      end

      # True only when the invocation ran to completion and exited 0. A missing
      # status (the process was killed before recording one) counts as failure.
      def succeeded?
        @exit_status&.zero? || false
      end

      def failure_reason
        @exit_status.nil? ? "recorded no exit status (killed before finishing)" : "exited #{@exit_status}"
      end

      def recorded?(mark_name)
        @mark_times.key?(mark_name)
      end

      def milliseconds_between(opening_mark, closing_mark)
        (@mark_times.fetch(closing_mark) - @mark_times.fetch(opening_mark)) * 1000.0
      end
    end
  end
end
