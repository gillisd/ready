module Ready
  module Bench
    ##
    # A named interval between two marks of a Run -- the unit every waterfall
    # row is built from. Each span declares the statistic that collapses many
    # runs' samples into one representative number (:minimum for
    # process-creation spans, where scheduler jitter only ever adds time, so
    # the floor is the structural cost; :median for in-process spans, where
    # the typical case is the honest number) and a description the report's
    # legend prints.
    class Span < Data.define(:label, :opening_mark, :closing_mark, :summary, :description)
      TABLE = [
        new(label: :shell, opening_mark: :harness_start, closing_mark: :shim_start,
            summary: :minimum,
            description: "(cold only) fork/exec and PATH walk to the shim; stub_call is the " \
                         "hot equivalent"),
        new(label: :launch, opening_mark: :shim_start, closing_mark: :ruby_up,
            summary: :minimum, description: "(cold only) Ruby interpreter boot, rubygems disabled"),
        new(label: :rubygems, opening_mark: :ruby_up, closing_mark: :rubygems_ready,
            summary: :median, description: "(cold only) the stub's require of rubygems plus Gem.use_gemdeps"),
        new(label: :activation, opening_mark: :rubygems_ready, closing_mark: :bin_path_resolved,
            summary: :median, description: "(cold only) resolving and activating the tool's gem dependencies"),
        new(label: :tool_run, opening_mark: :bin_path_resolved, closing_mark: :ruby_exit,
            summary: :median, description: "(cold only) loading and executing the tool itself"),
        new(label: :reap, opening_mark: :ruby_exit, closing_mark: :harness_end,
            summary: :median, description: "(cold only) interpreter exit and process reap, back to the shell"),
        new(label: :stub_call, opening_mark: :harness_start, closing_mark: :stub_entry,
            summary: :minimum,
            description: "(hot only) zsh dispatching to the ready_<tool> function -- no fork, " \
                         "no exec, no PATH walk"),
        new(label: :dispatch_overhead, opening_mark: :stub_entry, closing_mark: :server_entry,
            summary: :minimum,
            description: "(hot only) by client boot (a real Ruby process, the floor), socket " \
                         "round-trip, server fork"),
        new(label: :server_tool_run, opening_mark: :server_entry, closing_mark: :harness_end,
            summary: :median, description: "(hot only) the preloaded tool executing inside the warm server"),
        new(label: :full, opening_mark: :harness_start, closing_mark: :harness_end,
            summary: :minimum, description: "everything between the harness clock reads; what a user feels"),
      ].freeze

      def self.table
        TABLE
      end

      # Milliseconds between this span's marks, or nil when the run did not
      # record them both (a hot run has no shim marks, a cold run no server
      # marks).
      def measure(run)
        return nil unless measured_by?(run)

        run.milliseconds_between(opening_mark, closing_mark)
      end

      def measured_by?(run)
        run.recorded?(opening_mark) && run.recorded?(closing_mark)
      end

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
