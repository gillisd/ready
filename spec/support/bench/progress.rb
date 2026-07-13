module Ready
  module Bench
    ##
    # Narrates a run to stderr so a long, otherwise-silent benchmark never
    # looks hung: it announces the one-time sandbox build, then the warmup and
    # the measured rounds as separate phases (so the measured count matches
    # what the user asked for), ticking once per round. Output goes to stderr,
    # leaving stdout for the report itself.
    class Progress
      def initialize(command:, io: $stderr)
        @command = command
        @io = io
      end

      def building
        @io.print "#{@command}: building sandbox -- compiling stubs, booting the server (one-time setup)..."
        @io.flush
      end

      def warming_up(rounds)
        start_phase("warming up (#{count(rounds)})")
      end

      def measuring(rounds)
        start_phase("measuring #{count(rounds)}")
      end

      def tick
        @io.print "."
        @io.flush
      end

      def done
        @io.puts " done"
      end

      private

      def start_phase(label)
        @io.print "\n#{@command}: #{label} "
        @io.flush
      end

      def count(rounds)
        "#{rounds} #{rounds == 1 ? "round" : "rounds"}"
      end
    end
  end
end
