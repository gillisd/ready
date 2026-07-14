module Ready
  module Bench
    ##
    # One command's headline verdict: its cold and hot full startup times, in
    # milliseconds, side by side. Identified by the command as typed
    # ("ri TCPServer"), so the same executable on two inputs stays two
    # comparisons.
    class Comparison < Data.define(:command, :cold_milliseconds, :hot_milliseconds)
      def speedup
        cold_milliseconds / hot_milliseconds
      end

      # What ready removes from every invocation -- the pitch, as a number.
      def eliminated_milliseconds
        cold_milliseconds - hot_milliseconds
      end
    end
  end
end
