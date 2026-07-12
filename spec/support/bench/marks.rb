module Ready
  module Bench
    ##
    # Parses a shared mark log into per-run spans (ms). Log lines are
    # "<run_id> <mark_name> <realtime_seconds>".
    class Marks
      SPANS = [
        ["shell", "envelope_start", "shim_start"],
        ["rbenv_shim", "shim_start", "ruby_up"],
        ["rubygems", "ruby_up", "rubygems_ready"],
        ["dep_activate", "rubygems_ready", "dep_activated"],
        ["tool_run", "dep_activated", "ruby_exit"],
        ["reap", "ruby_exit", "envelope_end"],
        ["dispatch_infra", "envelope_start", "server_entry"],
        ["server_tool_run", "server_entry", "envelope_end"],
        ["full", "envelope_start", "envelope_end"],
      ].freeze

      def self.parse(path)
        runs = Hash.new { |h, k| h[k] = {} }
        File.readlines(path).each do |line|
          run, name, t = line.split
          runs[run][name] = t.to_f
        end
        runs
      end

      # Only spans whose both endpoints are present are emitted, so cold-only
      # marks (shim) and hot-only marks (server_entry) each yield their own rows.
      def self.spans(marks)
        SPANS.each_with_object({}) do |(label, from, to), out|
          next unless marks[from] && marks[to]

          out[label] = (marks[to] - marks[from]) * 1000.0
        end
      end
    end
  end
end
