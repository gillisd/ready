module Ready
  module Bench
    ##
    # The cold-startup breakdown condensed to the few layers an audience can
    # hold at once -- the version meant for a slide. Each line pairs a plain
    # label with the cold arm's floor (minimum) milliseconds for the matching
    # span. The Ruby VM boot is its own line, kept separate from "rubygems": both
    # arms pay the boot (ready's by client boots a VM too), but only the cold arm
    # loads rubygems -- folding them would falsely imply ready eliminates the
    # boot. Using the floor -- the same statistic the headline's
    # cold total uses -- keeps the layers summing to that total rather than
    # overshooting it (median layers can exceed the whole once a tool drags in a
    # big dependency graph); the tiny reap and the slack between the layer
    # floors and the full floor fall under the tilde on the total.
    class SlideSummary
      TITLE = "where the cold startup goes (slide summary)".freeze

      # One labeled row, its raw milliseconds and the prefix its value prints
      # with: "~" marks the total as approximate, layers carry none.
      Line = Data.define(:label, :milliseconds, :prefix) do
        def rounded_milliseconds
          milliseconds.round
        end

        def value
          "#{prefix}#{rounded_milliseconds}"
        end
      end

      # A friendly slide label over the cold span(s) whose durations it sums.
      Layer = Data.define(:label, :spans)

      LAYERS = [
        Layer.new(label: "shell", spans: [:shell]),
        Layer.new(label: "ruby vm boot", spans: [:launch]),
        Layer.new(label: "rubygems", spans: [:rubygems]),
        Layer.new(label: "activate deps", spans: [:activation]),
        Layer.new(label: "the tool", spans: [:tool_run]),
      ].freeze

      def initialize(cold:, rbenv_shim_overhead: nil)
        @cold = cold
        @rbenv_shim_overhead = rbenv_shim_overhead
      end

      # The layer lines in the order a cold invocation pays them, with the
      # rbenv shim slotted in after the shell when a real shim was measured.
      def lines
        layers = LAYERS.map { layer_line(it) }
        shim = rbenv_line
        layers.insert(1, shim) if shim
        layers
      end

      def total_line
        Line.new(label: "total", milliseconds: total_milliseconds, prefix: "~")
      end

      def render
        [TITLE, *displayed_lines.map { row(it) }].join("\n")
      end

      private

      def displayed_lines
        @displayed_lines ||= [*lines, total_line]
      end

      def layer_line(layer)
        milliseconds = layer.spans.sum { minimum_of(it) }
        Line.new(label: layer.label, milliseconds:, prefix: "")
      end

      # A span's structural floor: its minimum across measured runs. The slide
      # sums floors (not medians) so the layers add up to the min-based cold
      # total the headline reports instead of overshooting it.
      def minimum_of(span)
        samples = @cold.samples_of(span)
        samples.empty? ? 0.0 : samples.min
      end

      def rbenv_line
        return nil unless @rbenv_shim_overhead

        Line.new(label: "rbenv shim", milliseconds: @rbenv_shim_overhead, prefix: "")
      end

      def total_milliseconds
        @cold.duration_of(:full) + (@rbenv_shim_overhead || 0.0)
      end

      def row(line)
        "  #{line.label.ljust(label_width)}  #{line.value.rjust(value_width)} ms"
      end

      def label_width
        @label_width ||= displayed_lines.map { it.label.length }.max
      end

      def value_width
        @value_width ||= displayed_lines.map { it.value.length }.max
      end
    end
  end
end
