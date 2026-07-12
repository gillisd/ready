module Ready
  module Bench
    ##
    # Renders the per-arm waterfall and the paired hot-cold deltas.
    class Report
      HEADER = "%<span>-14s %<cold>28s %<hot>28s".freeze

      def initialize(runs_by_arm, pty_walls)
        @runs = runs_by_arm
        @pty = pty_walls
      end

      def render
        puts format(HEADER, span: "", cold: "cold (median/min ms)", hot: "hot (median/min ms)")
        Marks::SPANS.map(&:first).each { |label| render_span(label) }
        render_pairs
        render_pty_check
      end

      private

      def samples(arm, label)
        @runs[arm].filter_map { |spans| spans[label] }
      end

      def render_span(label)
        puts format(HEADER, span: label, cold: cell(samples("cold", label)), hot: cell(samples("hot", label)))
      end

      def cell(vals)
        return "-" if vals.empty?

        format("%<med>9.1f / %<min>8.1f", med: Stats.median(vals), min: vals.min)
      end

      def render_pairs
        deltas = @runs["hot"].zip(@runs["cold"]).map { |h, c| h["full"] - c["full"] }
        puts format("\npaired full-envelope delta (hot - cold): median %<med>+.1fms  min %<min>+.1fms  " \
                    "max %<max>+.1fms  n=%<n>d",
                    med: Stats.median(deltas), min: deltas.min, max: deltas.max, n: deltas.size)
      end

      def render_pty_check
        %w[cold hot].each do |arm|
          inshell = Stats.median(@runs[arm].map { |s| s["full"] })
          outside = Stats.median(@pty[arm]) * 1000.0
          puts format("pty cross-check %<arm>-5s in-shell %<ins>7.1fms  pty-observed %<out>7.1fms  " \
                      "(delta %<d>.1fms driver overhead)",
                      arm: arm, ins: inshell, out: outside, d: outside - inshell)
        end
      end
    end
  end
end
