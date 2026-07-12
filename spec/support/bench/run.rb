module Ready
  module Bench
    ##
    # One timed invocation of the tool under one arm, identified by its run id
    # ("cold.3" is round 3's cold invocation). A run holds the wall-clock
    # instant of every mark its instrumented layers recorded; Spans measure
    # themselves by asking the run for the time between two marks.
    class Run
      attr_reader :id

      def initialize(id:, mark_times:)
        @id = id
        @mark_times = mark_times.dup.freeze
      end

      def recorded?(mark_name) = @mark_times.key?(mark_name)

      def milliseconds_between(opening_mark, closing_mark)
        (@mark_times.fetch(closing_mark) - @mark_times.fetch(opening_mark)) * 1000.0
      end
    end
  end
end
