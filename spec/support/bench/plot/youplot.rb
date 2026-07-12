require "rbconfig"

module Ready
  module Bench
    module Plot
      ##
      # Delegates to the stock youplot barplot: one bar per command and arm,
      # cold and hot side by side.
      class Youplot
        TITLE = "full startup (ms): cold vs hot".freeze

        def initialize(comparisons)
          @comparisons = comparisons
        end

        def render
          uplot = Gem.bin_path("youplot", "uplot")
          IO.popen([RbConfig.ruby, uplot, "bar", "-d", ",", "-t", TITLE], "w") do |pipe|
            @comparisons.each { write_bars(pipe, it) }
          end
        end

        private

        def write_bars(pipe, comparison)
          pipe.puts "#{comparison.command} cold,#{comparison.cold_milliseconds.round(1)}"
          pipe.puts "#{comparison.command} hot,#{comparison.hot_milliseconds.round(1)}"
        end
      end
    end
  end
end
