module Ready
  module Bench
    ##
    # One interleaved pass of the benchmark: it times both arms once, in an
    # order that alternates each round to cancel run-order drift. Warmup rounds
    # run identically but are excluded from the reported numbers. A round owns
    # the run ids its arms report under -- "cold.3" is round 3's cold run.
    class Round < Data.define(:number, :warmup)
      def warmup?
        warmup
      end

      # Cold-first on even rounds, ready-first on odd, so run-order drift
      # cancels across the session.
      def arm_order
        number.even? ? %i[cold hot] : %i[hot cold]
      end

      def run_id(arm)
        "#{arm}.#{number}"
      end
    end
  end
end
