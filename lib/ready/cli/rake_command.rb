require "rbconfig"

module Ready
  class CLI
    ##
    # Shared behaviour for sub-commands that delegate to the project's Rakefile
    # (`up`, `clobber`, and `compile all`).
    #
    # Rake is run under the same Ruby that is running `ready`, inheriting
    # whatever Bundler context `exe/ready` established: in a development checkout
    # a Gemfile is present, so `exe/ready` has already required `bundler/setup`
    # (propagated to the rake process and the `ready compile` sub-processes it
    # spawns via `RUBYOPT`); in production there is no Gemfile, so the build runs
    # bundler-free and resolves the installed gem through RubyGems.
    module RakeCommand

      ##
      # Runs the given rake task(s) in {Ready.root} and exits non-zero if rake
      # fails.
      #
      # @param [Array<String>] tasks
      #   The rake task name(s) to run.
      def rake(*tasks)
        return if system(RbConfig.ruby, "-S", "rake", *tasks, chdir: Ready.root.to_s)

        # Propagate rake's own exit status where we can; fall back to 1 if the
        # process could not be spawned at all ($? unset).
        exit($?&.exitstatus || 1)
      end

    end
  end
end
