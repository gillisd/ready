module Ready
  module Bench
    ##
    # Renders the benchmark: a preamble saying exactly what ran, a waterfall
    # table with one statistic per column (never two values in a cell), the
    # full-span delta, a cross-check of the in-shell numbers against the pty
    # driver's independently observed wall clock, and -- when verbose -- a
    # legend table explaining every span row plus the harness vocabulary.
    class Report
      ROW = "%<span>-18s %<cold_median>13s %<cold_minimum>13s %<hot_median>13s %<hot_minimum>13s".freeze
      LEGEND_ROW = "%<span>-18s %<interval>-41s %<summary>-8s %<description>s".freeze
      TERM_ROW = "%<term>-13s %<meaning>s".freeze

      TERMS = {
        arm: "one side of the comparison -- cold boots a fresh process per run, " \
             "hot dispatches to the warm by-server",
        round: "one interleaved pass running both arms back to back, order " \
               "alternating per round to cancel drift",
        run: "a single timed invocation inside an arm, identified <arm>.<round> " \
             "(cold.3 is round 3's cold run)",
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
        render_preamble
        render_table
        render_full_delta
        @arms.each { render_wall_clock_check(it) }
        render_rbenv_shim_overhead
        return unless @verbose

        render_legend
        render_terms
      end

      private

      def render_preamble
        tool = @protocol.executable_name
        hot_invocation = ["ready_#{tool}", *@protocol.arguments].join(" ")
        puts "ready startup benchmark"
        puts "tool under test:   #{tool}, invoked as: #{@protocol.invocation}"
        puts "cold arm:          a fresh Ruby boot per run, through an instrumented copy of its rubygems stub"
        puts "hot arm:           #{hot_invocation} dispatching to a warm by-server (#{@protocol.library} preloaded)"
        puts "protocol:          #{@protocol.rounds} measured rounds per arm (+#{@protocol.warmups} warmup, " \
             "excluded), cold/hot order alternating"
        puts "choose the target: BENCH_EXE=<executable> BENCH_LIB=<library> BENCH_ARGS=<arguments> rake bench"
        puts "all durations in milliseconds"
        puts
      end

      def render_table
        puts format(ROW, span: "span", cold_median: "cold median", cold_minimum: "cold minimum",
                         hot_median: "hot median", hot_minimum: "hot minimum")
        Span.table.each { render_row(it) }
      end

      def render_row(span)
        puts format(ROW, span: span.label,
                         cold_median: median_cell(@cold, span), cold_minimum: minimum_cell(@cold, span),
                         hot_median: median_cell(@hot, span), hot_minimum: minimum_cell(@hot, span))
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

      def render_full_delta
        delta = @hot.duration_of(:full) - @cold.duration_of(:full)
        puts format("\nfull delta (hot - cold): %<delta>+.1fms", delta:)
      end

      def render_wall_clock_check(arm)
        in_shell = arm.duration_of(:full)
        observed = arm.median_wall_clock_milliseconds
        puts format("pty cross-check %<arm>-5s in-shell %<in_shell>7.1fms  " \
                    "pty-observed %<observed>7.1fms  (delta %<delta>.1fms driver overhead)",
                    arm: arm.name, in_shell:, observed:, delta: observed - in_shell)
      end

      def render_rbenv_shim_overhead
        return unless @rbenv_shim_overhead

        real_cold_full = @cold.duration_of(:full) + @rbenv_shim_overhead
        puts format("\nrbenv shim overhead (cold pays it, hot eliminates it): +%<overhead>.1fms  " \
                    "(real cold full ~= %<total>.1fms)",
                    overhead: @rbenv_shim_overhead, total: real_cold_full)
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
