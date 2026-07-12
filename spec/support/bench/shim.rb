module Ready
  module Bench
    ##
    # A faithful, instrumented stand-in for the rbenv shim a cold invocation
    # hits first. Every shim marks shim_start, arms the Ruby-side prelude via
    # RUBYOPT, boots with --disable-gems, then execs its variant's target.
    # Subclasses answer what the shim is called on PATH (#command_word) and
    # what it execs (#exec_line).
    #
    # Why --disable-gems:
    #
    #   default boot:   MRI eagerly requires rubygems at interpreter startup,
    #                   BEFORE any RUBYOPT -r runs -- so ~45ms hides inside
    #                   :launch and the stub's own `require "rubygems"` becomes
    #                   a no-op
    #   --disable-gems: that implicit require is skipped, so the SAME require
    #                   runs at the stub's explicit call site instead -- same
    #                   code, same cost, now inside the markable :rubygems span
    #
    # (This is the interpreter's default `gems` feature, not Kernel#autoload.)
    class Shim
      def initialize(executable_name:, workdir:, prelude_path:, **options)
        @executable_name = executable_name
        @workdir = Pathname(workdir)
        @prelude_path = prelude_path
        post_initialize(**options)
      end

      # The word a shell types to invoke this shim (its filename on PATH).
      def command_word
        raise NotImplementedError, "#{self.class} must name its command word"
      end

      def write!
        path = @workdir / command_word
        path.write(script)
        path.chmod(0o755)
      end

      private

      attr_reader :executable_name, :prelude_path

      # Hook for a variant's extra construction state; overriding it never
      # requires calling super.
      def post_initialize(**)
        nil
      end

      def exec_line
        raise NotImplementedError, "#{self.class} must supply its exec line"
      end

      def script
        <<~SH
          #!/usr/bin/env bash
          set -e
          printf '%s shim_start %s\\n' "$READY_RUN_ID" "$EPOCHREALTIME" >> "$READY_MARKS"
          export RUBYOPT="--disable-gems -r#{prelude_path}${RUBYOPT:+ $RUBYOPT}"
          export RBENV_ROOT="$HOME/.rbenv"
          #{exec_line}
        SH
      end
    end
  end
end
