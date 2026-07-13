module Ready
  module Bench
    ##
    # Renders the benchmark: a headline verdict (the caveat-less cold/hot times
    # and the speedup), a preamble saying exactly what ran, a waterfall table
    # with one statistic per column plus a per-layer delta, a note reconciling
    # the table's cold with the rbenv shim, a cross-check of the in-shell
    # numbers against the pty driver's independently observed wall clock, and
    # -- when verbose -- a legend and the harness vocabulary.
    class Report
      ROW = "%<span>-18s %<cold_median>12s %<cold_minimum>12s " \
            "%<hot_median>12s %<hot_minimum>12s %<delta>12s".freeze
      LEGEND_ROW = "%<span>-18s %<interval>-41s %<summary>-8s %<description>s".freeze
      TERM_ROW = "%<term>-13s %<meaning>s".freeze
      # The fast arm is the product: display it as "ready", not "hot".
      ARM_LABEL = { cold: "cold", hot: "ready" }.freeze

      TERMS = {
        arm: "one side of the comparison -- cold boots a fresh process per run, " \
             "hot dispatches to the warm by-server",
        round: "one interleaved pass timing both arms once (a cold run and a hot " \
               "run), order alternating per round to cancel drift",
        run: "a single timed invocation inside an arm, identified <arm>.<round> " \
             "(cold.3 is round 3's cold run)",
        delta: "cold minus hot for that layer: what ready saves there " \
               "(negative = ready's own overhead)",
        "cross-check": "the pty driver's outside wall clock against the in-shell " \
                       "marks; the delta is driver overhead",
      }.freeze

      def initialize(cold:, hot:, protocol:, rbenv_shim_overhead: nil, verbose: false)
        @cold = cold
        @hot = hot
        @arms = [cold, hot]
        @protocol = protocol
        @rbenv_shim_overhead = rbenv_shim_overhead
        @verbose = verbose
      end

      def render
        render_headline
        render_preamble
        render_table
        render_rbenv_note
        @arms.each { render_wall_clock_check(it) }
        return unless @verbose

        render_legend
        render_terms
      end

      private

      # The final, caveat-less answer up top: what a real cold run costs, what
      # ready's warm dispatch costs, and how many times faster that is.
      def render_headline
        cold = real_cold_full
        hot = @hot.duration_of(:full)
        puts "ready startup benchmark -- #{@protocol.invocation}"
        puts
        puts format("  cold   %<cold>8.1f ms   %<note>s", cold:, note: cold_note)
        puts format("  ready  %<hot>8.1f ms   warm dispatch", hot:)
        puts format("  ready is %<x>.1fx faster, saving %<saved>.1f ms per run", x: cold / hot, saved: cold - hot)
        puts
      end

      # What a real cold invocation costs: the measured cold full plus the
      # rbenv shim it goes through (the table measures cold without it, to keep
      # the per-layer marks clean). No rbenv probe -> the two are the same.
      def real_cold_full
        @cold.duration_of(:full) + (@rbenv_shim_overhead || 0)
      end

      def cold_note
        @rbenv_shim_overhead ? "fresh boot, through the rbenv shim" : "fresh boot"
      end

      def render_preamble
        puts "tool under test:   #{@protocol.executable_name}, invoked as: #{@protocol.invocation}"
        puts "cold arm:          a fresh Ruby boot per run, through an instrumented copy of its rubygems stub"
        puts "ready arm:         #{ready_invocation} dispatching to a warm by-server " \
             "(#{@protocol.preload_gems.join(", ")} preloaded)"
        puts "protocol:          #{@protocol.rounds} rounds, each timing both arms once " \
             "(order alternating), after #{warmup_phrase}"
        puts "choose the target: bin/bench [--readyfile PATH] [COMMAND ...] [-- COMMAND ...]"
        puts "all durations in milliseconds"
        puts
      end

      def ready_invocation
        ["ready_#{@protocol.executable_name}", *@protocol.arguments].join(" ")
      end

      def warmup_phrase
        @protocol.warmups == 1 ? "1 warmup round" : "#{@protocol.warmups} warmup rounds"
      end

      def render_table
        puts format(ROW, span: "span", cold_median: "cold median", cold_minimum: "cold minimum",
                         hot_median: "ready median", hot_minimum: "ready minimum", delta: "delta")
        Span.table.each { render_row(it) }
      end

      def render_row(span)
        puts format(ROW, span: span.label,
                         cold_median: median_cell(@cold, span), cold_minimum: minimum_cell(@cold, span),
                         hot_median: median_cell(@hot, span), hot_minimum: minimum_cell(@hot, span),
                         delta: delta_cell(span))
      end

      def median_cell(arm, span)
        samples = arm.samples_of(span.label)
        return "-" if samples.empty?

        format("%.1f", Stats.median(samples))
      end

      def minimum_cell(arm, span)
        samples = arm.samples_of(span.label)
        return "-" if samples.empty?

        format("%.1f", samples.min)
      end

      # cold - hot for the layer: positive where ready eliminates cold work,
      # negative for the layers ready adds (its dispatch). "-" when neither arm
      # measured the layer.
      def delta_cell(span)
        return "-" if @cold.samples_of(span.label).empty? && @hot.samples_of(span.label).empty?

        format("%+.1f", median_or_zero(@cold, span) - median_or_zero(@hot, span))
      end

      def median_or_zero(arm, span)
        samples = arm.samples_of(span.label)
        samples.empty? ? 0.0 : Stats.median(samples)
      end

      def render_rbenv_note
        return unless @rbenv_shim_overhead

        puts format("\ncold full in the table excludes the rbenv shim; a real cold run pays " \
                    "+%<overhead>.1f ms more (folded into the headline above)",
                    overhead: @rbenv_shim_overhead)
      end

      def render_wall_clock_check(arm)
        in_shell = arm.duration_of(:full)
        observed = arm.median_wall_clock_milliseconds
        puts format("pty cross-check %<arm>-5s in-shell %<in_shell>7.1fms  " \
                    "pty-observed %<observed>7.1fms  (delta %<delta>.1fms driver overhead)",
                    arm: ARM_LABEL.fetch(arm.name, arm.name.to_s), in_shell:, observed:,
                    delta: observed - in_shell)
      end

      def render_legend
        puts "\nlegend"
        puts format(LEGEND_ROW, span: "span", interval: "interval (opening mark -> closing mark)",
                                summary: "summary", description: "what it measures")
        Span.table.each { render_legend_row(it) }
      end

      def render_legend_row(span)
        interval = "#{span.opening_mark} -> #{span.closing_mark}"
        puts format(LEGEND_ROW, span: span.label, interval:, summary: span.summary,
                                description: span.description)
      end

      def render_terms
        puts "\nterms"
        TERMS.each { |term, meaning| puts format(TERM_ROW, term:, meaning:) }
      end
    end
  end
end
