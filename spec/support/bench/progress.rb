module Ready
  module Bench
    ##
    # Narrates a run to stderr so a long, otherwise-silent benchmark never
    # looks hung: it announces the one-time sandbox build (the slow, opaque
    # step) and then ticks once per round. Output goes to stderr, leaving
    # stdout for the report itself.
    class Progress
      def initialize(command:, io: $stderr)
        @command = command
        @io = io
      end

      def building
        @io.puts "#{@command}: building sandbox -- compiling stubs, booting the server (one-time setup)..."
      end

      def running(rounds)
        @io.print "#{@command}: running #{rounds} rounds "
        @io.flush
      end

      def tick
        @io.print "."
        @io.flush
      end

      def done
        @io.puts " done"
      end
    end
  end
end
