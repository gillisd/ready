module Ready
  module Bench
    module Plot
      ##
      # One bar per command on a shared scale, hot and cold stacked into a
      # single line: the leading segment is what you still pay hot, the rest
      # is what ready eliminates -- together, the cold total.
      class Stacked
        WIDTH = 40
        HOT_CELL = "#".freeze
        ELIMINATED_CELL = ".".freeze

        def initialize(comparisons)
          @comparisons = comparisons
        end

        def render
          puts "full startup (ms) -- #{HOT_CELL} hot, #{ELIMINATED_CELL} eliminated by ready"
          @comparisons.each { render_bar(it) }
        end

        private

        # Cells per millisecond, sized so the slowest measurement of either arm
        # spans WIDTH -- so a regression (hot > cold) can never overflow.
        def scale
          @scale ||= WIDTH / @comparisons.flat_map { [it.cold_milliseconds, it.hot_milliseconds] }.max
        end

        # The command column widens to the longest command so no label
        # overflows and shoves the numbers out of line.
        def command_width
          @command_width ||= @comparisons.map { it.command.length }.max
        end

        def render_bar(comparison)
          row_format = "%<command>-#{command_width}s %<bar>-#{WIDTH}s " \
                       "%<hot>7.1f hot / %<cold>7.1f cold  (%<speedup>.1fx)"
          puts format(row_format,
                      command: comparison.command, bar: bar_for(comparison),
                      hot: comparison.hot_milliseconds, cold: comparison.cold_milliseconds,
                      speedup: comparison.speedup)
        end

        def bar_for(comparison)
          hot_cells = [(comparison.hot_milliseconds * scale).round, 1].max
          cold_cells = [(comparison.cold_milliseconds * scale).round, hot_cells].max
          (HOT_CELL * hot_cells) + (ELIMINATED_CELL * (cold_cells - hot_cells))
        end
      end
    end
  end
end
