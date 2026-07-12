module Ready
  module Bench
    ##
    # Renders the cold-vs-hot waterfall: one row per span (median/min across
    # each arm's measured runs), the full-span delta, and a cross-check of the
    # in-shell numbers against the pty driver's independently observed wall
    # clock.
    class Report
      ROW = "%<span>-18s %<cold>28s %<hot>28s".freeze

      def initialize(cold:, hot:, rbenv_shim_overhead: nil)
        @cold = cold
        @hot = hot
        @arms = [cold, hot]
        @rbenv_shim_overhead = rbenv_shim_overhead
      end

      def render
        puts format(ROW, span: "", cold: "cold (median/min ms)", hot: "hot (median/min ms)")
        Span.table.each { render_row(it) }
        render_full_delta
        @arms.each { render_wall_clock_check(it) }
        render_rbenv_shim_overhead
      end

      private

      def render_row(span)
        cold_cell, hot_cell = @arms.map { cell(it.samples_of(span.label)) }
        puts format(ROW, span: span.label, cold: cold_cell, hot: hot_cell)
      end

      def cell(samples)
        return "-" if samples.empty?

        format("%<median>9.1f / %<minimum>8.1f", median: Stats.median(samples), minimum: samples.min)
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
    end
  end
end
