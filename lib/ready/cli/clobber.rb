require "command_kit/command"

module Ready
  class CLI
    ##
    # Removes every compiled ready build artifact, by delegating to the
    # `rake clobber` task.
    class Clobber < CommandKit::Command
      include RakeCommand

      description "Remove all compiled ready build artifacts"

      #
      # Runs `rake clobber`.
      #
      def run
        rake("clobber")
      end
    end
  end
end
