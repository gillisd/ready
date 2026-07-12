module Ready
  module Bench
    ##
    # Median helper over span samples.
    module Stats
      def self.median(values)
        sorted = values.sort
        middle = sorted.size / 2
        sorted.size.odd? ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2.0
      end
    end
  end
end
