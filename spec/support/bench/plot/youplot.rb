require "rbconfig"

module Ready
  module Bench
    module Plot
      ##
      # Delegates to the stock youplot barplot: cold vs ready. With a single
      # command the command names the plot (title) and the bars are just
      # "cold" / "ready"; with several, each bar carries its command so they
      # stay distinct.
      class Youplot
        def initialize(comparisons)
          @comparisons = comparisons
        end

        def render
          uplot = Gem.bin_path("youplot", "uplot")
          IO.popen([RbConfig.ruby, uplot, "bar", "-d", ",", "-t", title], "w") do |pipe|
            @comparisons.each { write_bars(pipe, it) }
          end
        end

        private

        def title
          single? ? "full startup (ms): #{@comparisons.first.command}" : "full startup (ms): cold vs ready"
        end

        def write_bars(pipe, comparison)
          pipe.puts "#{label(comparison, "cold")},#{comparison.cold_milliseconds.round(1)}"
          pipe.puts "#{label(comparison, "ready")},#{comparison.hot_milliseconds.round(1)}"
        end

        # One command -> bare arm labels (the command is the title); several ->
        # prefix each with its command so the bars are distinguishable.
        def label(comparison, arm)
          single? ? arm : "#{comparison.command} #{arm}"
        end

        def single?
          @comparisons.one?
        end
      end
    end
  end
end
