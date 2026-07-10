require "optparse"

module Ready
  ##
  # Parses the "gem" subcommand options and gem names into a ZshScript.
  class GemParser
    attr_reader :parser

    private_class_method :new

    def self.parse(*inputs)
      new.parse(*inputs)
    end

    def initialize
      @parser = OptionParser.new
      @zsh_script = ZshScript.new

      initialize_opt_parser!
    end

    def display_usage(to: $stdout)
      to.puts @parser
    end

    def parse(*inputs)
      if inputs.empty?
        display_usage to: $stderr
        warn
        warn "You must specify at least one gem name."
        exit 1
      end

      @parser.parse!(inputs)
      @zsh_script.names = inputs
      @zsh_script
    end

    private

    def initialize_opt_parser!
      @parser.tap do |r|
        r.banner = "Usage: #{$0} gem [gem-names...]"

        r.on(
          "-e",
          "--env",
          "--environment ENV",
          "Prepare an environment variable to be set when running the executable",
          "Example:",
          "--environment RAILS_ENV=production",
        ) do |env|
          @zsh_script.set_env(*env.split("="))
        end

        r.on "--help", "-h", "Display this message" do
          display_usage
          exit
        end
      end
    end
  end
end
