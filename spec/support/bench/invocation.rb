module Ready
  module Bench
    ##
    # One command line to benchmark, exactly as the user would type it: the
    # executable and the arguments that make it do real work.
    class Invocation < Data.define(:executable_name, :arguments)
      def self.parse(words)
        new(executable_name: words.first, arguments: words[1..])
      end

      def self.bare(executable_name)
        new(executable_name:, arguments: [])
      end
    end
  end
end
