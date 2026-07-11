require "command_kit/commands"

module Ready
  ##
  # The `ready` command-line interface.
  #
  # `ready` speeds up Ruby CLI startup by preloading executables into a
  # persistent server and compiling thin zsh stubs that dispatch to it. This
  # class wires the sub-commands together with command_kit; each sub-command
  # lives in its own file under `cli/`.
  class CLI

    include CommandKit::Commands

    command_name "ready"

    command Init
    command Up
    command Compile
    command Clobber

  end
end
