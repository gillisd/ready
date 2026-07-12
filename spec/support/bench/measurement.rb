module Ready
  module Bench
    ##
    # Everything one run yielded: the Waterfall of its marked spans, plus the
    # wall clock (a Float of seconds, CLOCK_MONOTONIC) the pty driver observed
    # from OUTSIDE the shell -- the independent cross-check on the in-shell
    # marks.
    Measurement = Data.define(:waterfall, :wall_clock_seconds)
  end
end
