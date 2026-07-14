require "command_kit/command"

module Ready
  class CLI
    ##
    # Prints the shell snippet that sources ready's zsh plugin. The plugin path
    # is resolved by introspection relative to this gem, so the output is
    # correct wherever the gem is installed:
    #
    #     eval "$(ready init)"      # or paste the line into ~/.zshrc
    class Init < CommandKit::Command
      # The bundled zsh plugin entry point, resolved relative to the gem.
      PLUGIN_PATH = Ready.root / "zsh" / "ready" / "ready.plugin.zsh"

      description "Print the zsh snippet that sources the ready plugin"

      #
      # Prints `source <plugin path>` to stdout.
      #
      def run
        unless PLUGIN_PATH.file?
          print_error "ready zsh plugin not found at #{PLUGIN_PATH}"
          exit(1)
        end

        puts "source #{PLUGIN_PATH}"
      end
    end
  end
end
