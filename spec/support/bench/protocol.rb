module Ready
  module Bench
    ##
    # What the benchmark actually tested and how: the executable under test,
    # the arguments that make it do real work, the library the hot server
    # preloads for it, and the round counts (measured rounds per arm, plus
    # warmups that are recorded but excluded from every reported number).
    class Protocol < Data.define(:executable_name, :library, :arguments, :rounds, :warmups)
      # The standard target: ri rendering real documentation -- a genuine CLI
      # workload, present on every machine.
      def self.default
        new(executable_name: "ri", library: "rdoc", arguments: ["TCPServer"], rounds: 15, warmups: 3)
      end

      # The exact command line the harness times, minus redirections.
      def invocation
        [executable_name, *arguments].join(" ")
      end
    end
  end
end
