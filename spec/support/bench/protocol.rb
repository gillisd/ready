module Ready
  module Bench
    ##
    # What one benchmark actually tested and how: the executable under test,
    # the arguments that make it do real work, the gems the hot server
    # preloads, and the round counts (measured rounds per arm, plus warmups
    # that are recorded but excluded from every reported number).
    class Protocol < Data.define(:executable_name, :arguments, :preload_gems, :rounds, :warmups)
      # The standard target: ri rendering real documentation -- a genuine CLI
      # workload, present on every machine.
      def self.default
        new(executable_name: "ri", arguments: ["TCPServer"], preload_gems: ["rdoc"],
            rounds: 15, warmups: 3)
      end

      # The exact command line the harness times, minus redirections.
      def invocation
        [executable_name, *arguments].join(" ")
      end
    end
  end
end
