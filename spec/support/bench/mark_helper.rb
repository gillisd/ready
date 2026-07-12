module Ready
  module Bench
    ##
    # The Ruby an instrumented process runs to append one mark line to the
    # marks log. Kept as literal source (never interpolated at generation
    # time) because it executes inside the measured process, which knows its
    # run id and log path only through the environment. One definition serves
    # every injection site: the cold arm's prelude, the instrumented rubygems
    # stub, and the hot arm's server-eval'd source.
    module MarkHelper
      DEFINITION = <<~'RUBY'.freeze
        def ready_bench_mark(mark_name)
          marks_log_path = ENV.fetch("READY_MARKS")
          run_id = ENV.fetch("READY_RUN_ID")
          instant = Process.clock_gettime(Process::CLOCK_REALTIME)
          File.write(marks_log_path, "#{run_id} #{mark_name} #{instant}\n", mode: "a")
        end
      RUBY

      def self.definition = DEFINITION

      # A statement recording +mark_name+, for splicing in after .definition.
      def self.record(mark_name) = %(ready_bench_mark("#{mark_name}"))
    end
  end
end
