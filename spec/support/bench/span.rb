module Ready
  module Bench
    ##
    # A named interval between two marks of a Run -- the unit every waterfall
    # row is built from. Each span also declares the statistic that collapses
    # many runs' samples into one representative number: :minimum for
    # process-creation spans (scheduler jitter only ever adds time, so the
    # floor is the structural cost) and :median for in-process spans (the
    # typical case is the honest number).
    class Span < Data.define(:label, :opening_mark, :closing_mark, :summary)
      TABLE = [
        new(label: :shell, opening_mark: :harness_start, closing_mark: :shim_start, summary: :minimum),
        new(label: :launch, opening_mark: :shim_start, closing_mark: :ruby_up, summary: :minimum),
        new(label: :rubygems, opening_mark: :ruby_up, closing_mark: :rubygems_ready, summary: :median),
        new(label: :activation, opening_mark: :rubygems_ready, closing_mark: :bin_path_resolved, summary: :median),
        new(label: :tool_run, opening_mark: :bin_path_resolved, closing_mark: :ruby_exit, summary: :median),
        new(label: :reap, opening_mark: :ruby_exit, closing_mark: :harness_end, summary: :median),
        new(label: :dispatch_overhead, opening_mark: :harness_start, closing_mark: :server_entry, summary: :minimum),
        new(label: :server_tool_run, opening_mark: :server_entry, closing_mark: :harness_end, summary: :median),
        new(label: :full, opening_mark: :harness_start, closing_mark: :harness_end, summary: :minimum),
      ].freeze

      def self.table = TABLE

      # Milliseconds between this span's marks, or nil when the run did not
      # record them both (a hot run has no shim marks, a cold run no server
      # marks).
      def measure(run)
        return nil unless measured_by?(run)

        run.milliseconds_between(opening_mark, closing_mark)
      end

      def measured_by?(run) = run.recorded?(opening_mark) && run.recorded?(closing_mark)

      # Collapses many runs' samples of this span into one representative
      # number, using the statistic the span declared for itself. An unknown
      # statistic raises rather than silently falling back.
      def summarize(samples)
        case summary
        in :minimum then samples.min
        in :median then Stats.median(samples)
        end
      end
    end
  end
end
