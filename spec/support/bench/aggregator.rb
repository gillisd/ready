module Ready
  module Bench
    ##
    # Collapses many per-run span hashes into one, applying min to
    # process-creation spans (jittery, so the floor is the structural number) and
    # median to in-process spans.
    class Aggregator
      def initialize(span_kind:)
        @span_kind = span_kind
      end

      def combine(runs)
        labels = runs.flat_map(&:keys).uniq
        labels.each_with_object({}) do |label, out|
          values = runs.filter_map { |r| r[label] }
          next if values.empty?

          out[label] = @span_kind[label] == :min ? values.min : Stats.median(values)
        end
      end
    end
  end
end
