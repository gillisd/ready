module Ready
  module Bench
    ##
    # Parses a shared mark log into per-run spans (ms). Log lines are
    # "<run_id> <mark_name> <realtime_seconds>".
    class Marks
      SPANS = [
        ["spawn+interp", "envelope_start", "ruby_up"],
        ["rubygems_req", "ruby_up", "rubygems_loaded"],
        ["preamble", nil, "entry_start"],
        ["lib_load", "entry_start", "lib_loaded"],
        ["cli_run", "lib_loaded", "cli_done"],
        ["teardown", "cli_done", "ruby_exit"],
        ["reap", "ruby_exit", "envelope_end"],
        ["TOTAL", "envelope_start", "envelope_end"],
      ].freeze

      def self.parse(path)
        runs = Hash.new { |h, k| h[k] = {} }
        File.readlines(path).each do |line|
          run, name, t = line.split
          runs[run][name] = t.to_f
        end
        runs
      end

      # The +preamble+ span starts wherever the previous mark left off, absorbing
      # the arm difference in whether rubygems_loaded exists.
      def self.spans(marks)
        SPANS.each_with_object({}) do |(label, from, to), out|
          from ||= marks.key?("rubygems_loaded") ? "rubygems_loaded" : "ruby_up"
          next unless marks[from] && marks[to]

          out[label] = (marks[to] - marks[from]) * 1000.0
        end
      end
    end
  end
end
