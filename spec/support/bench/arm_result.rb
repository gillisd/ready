module Ready
  module Bench
    ##
    # One arm's accumulated measurements (:cold boots fresh processes, :hot
    # dispatches to the warm server). Records each run's waterfall alongside
    # the pty-observed wall clock, excludes the warmup runs from every number
    # it reports, and summarizes on demand.
    class ArmResult
      attr_reader :name

      def initialize(name:, warmups:)
        @name = name
        @warmups = warmups
        @waterfalls = []
        @wall_clock_seconds = []
      end

      def record(waterfall:, wall_seconds:)
        @waterfalls << waterfall
        @wall_clock_seconds << wall_seconds
      end

      def summary = Waterfall.summarizing(measured_waterfalls)

      def duration_of(label) = summary.duration_of(label)

      def samples_of(label) = measured_waterfalls.filter_map { it.duration_of(label) }

      def median_wall_clock_milliseconds = Stats.median(@wall_clock_seconds.drop(@warmups)) * 1000.0

      private

      def measured_waterfalls = @waterfalls.drop(@warmups)
    end
  end
end
