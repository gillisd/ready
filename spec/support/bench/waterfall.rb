module Ready
  module Bench
    ##
    # The measured spans of one run, as span label to milliseconds; the
    # summarizing constructor instead collapses many runs' waterfalls into one
    # using each span's own summary statistic. Only spans whose marks were
    # actually recorded appear: a hot run has no :launch row, a cold run no
    # :dispatch_overhead row.
    class Waterfall
      def self.of(run)
        Span.table
            .select { it.measured_by?(run) }
            .to_h { [it.label, it.measure(run)] }
            .then { new(it) }
      end

      def self.summarizing(waterfalls)
        Span.table
            .map { |span| [span, waterfalls.filter_map { it.duration_of(span.label) }] }
            .reject { |_span, samples| samples.empty? }
            .to_h { |span, samples| [span.label, span.summarize(samples)] }
            .then { new(it) }
      end

      def initialize(durations)
        @durations = durations.dup.freeze
      end

      def duration_of(label) = @durations[label]

      def measured?(label) = @durations.key?(label)
    end
  end
end
