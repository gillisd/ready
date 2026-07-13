require "command_kit/command"

module Ready
  class CLI
    ##
    # Compiles every stub and (re)starts the ready server, by delegating to the
    # `rake ready` task.
    class Up < CommandKit::Command
      include RakeCommand

      description "Compile all stubs and start the ready server"

      #
      # Runs `rake ready`.
      #
      def run
        rake("ready")
      end
    end
  end
end
