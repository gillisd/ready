module Ready
  module Bench
    ##
    # The shared file each `rake bench` run appends its headline numbers to,
    # one line per arm: "<command>,<arm>,<full_milliseconds>". It bridges the
    # separate rake processes and the plotting CLI, which reads the
    # accumulated rows back as one Comparison per command.
    class ResultsLog
      ##
      # One parsed line: which command, which arm, and its full startup time.
      Row = Data.define(:command, :arm, :full_milliseconds)

      attr_reader :path

      def initialize(path)
        @path = Pathname(path)
      end

      def append(command:, arm:, full_milliseconds:)
        path.write("#{command},#{arm},#{full_milliseconds}\n", mode: "a")
      end

      def comparisons
        rows.group_by(&:command).map { |command, command_rows| comparison_for(command, command_rows) }
      end

      private

      def rows
        path.readlines(chomp: true).map { parse_row(it) }
      end

      def parse_row(line)
        command, arm, full_milliseconds = line.split(",")
        Row.new(command:, arm: arm.to_sym, full_milliseconds: Float(full_milliseconds))
      end

      def comparison_for(command, command_rows)
        by_arm = command_rows.to_h { [it.arm, it.full_milliseconds] }
        Comparison.new(command:,
                       cold_milliseconds: by_arm.fetch(:cold),
                       hot_milliseconds: by_arm.fetch(:hot))
      end
    end
  end
end
