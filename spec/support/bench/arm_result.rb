module Ready
  module Bench
    ##
    # One arm's accumulated measurements (:cold boots fresh processes, :hot
    # dispatches to the warm server). Records a Measurement per run, excludes
    # the warmup runs from every number it reports, and summarizes on demand.
    class ArmResult
      attr_reader :name

      def initialize(name:, warmups:)
        @name = name
        @warmups = warmups
        @measurements = []
      end

      def record(measurement)
        @measurements << measurement
      end

      def summary
        Waterfall.summarizing(measured.map(&:waterfall))
      end

      def duration_of(label)
        summary.duration_of(label)
      end

      def samples_of(label)
        measured.filter_map { it.waterfall.duration_of(label) }
      end

      def median_wall_clock_milliseconds
        Stats.median(measured.map(&:wall_clock_seconds)) * 1000.0
      end

      private

      def measured
        @measurements.drop(@warmups)
      end
    end
  end
end
