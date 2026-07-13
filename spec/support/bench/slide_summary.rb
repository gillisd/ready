module Ready
  module Bench
    ##
    # The cold-startup breakdown condensed to the few layers an audience can
    # hold at once -- the version meant for a slide. Each line pairs a plain
    # label with the real measured milliseconds of the cold arm's matching
    # span(s): Ruby's interpreter boot rides under "rubygems" (the phase people
    # know by that name) and the tiny reap is left to the tilde on the total,
    # which reports the real end-to-end cold time, not the rounded rows' sum.
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
        Layer.new(label: "rubygems", spans: [:launch, :rubygems]),
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
        milliseconds = layer.spans.sum { @cold.duration_of(it) || 0.0 }
        Line.new(label: layer.label, milliseconds:, prefix: "")
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
