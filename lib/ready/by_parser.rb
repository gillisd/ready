require "optparse"

module Ready
  ##
  # Parses the "by" subcommand options into a configured ByExecutable.
  class ByParser
    attr_reader :parser

    private_class_method :new

    def self.parse(*inputs)
      new.parse(*inputs)
    end

    def initialize
      @parser = OptionParser.new
      @by_executable = ByExecutable
                       .new
                       .without_rubygems
                       .without_yjit

      initialize_opt_parser!
    end

    def display_usage(to: $stdout)
      to.puts @parser
    end

    def parse(*inputs)
      @parser.parse!(inputs)
      @by_executable
    end

    private

    def initialize_opt_parser!
      @parser.tap do |r|
        r.banner = "Usage: #{$0} by [options]"
        r.on "--[no-]rubygems", "Skip loading of rubygems. BIG speed boost (default --no-rubygems)" do |rubygems|
          @by_executable = rubygems ? @by_executable.with_rubygems : @by_executable.without_rubygems
        end

        r.on "--[no-]yjit", "Enable YJIT (default --no-yjit)" do |yjit|
          @by_executable = yjit ? @by_executable.with_yjit : @by_executable.without_yjit
        end

        r.on "--help", "-h", "Display this message" do
          display_usage
          exit
        end
      end
    end
  end
end
