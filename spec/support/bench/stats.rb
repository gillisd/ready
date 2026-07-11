module Ready
  module Bench
    ##
    # Median helper over span samples.
    module Stats
      def self.median(values)
        s = values.sort
        mid = s.size / 2
        s.size.odd? ? s[mid] : (s[mid - 1] + s[mid]) / 2.0
      end
    end
  end
end
