module Ready
  module Bench
    ##
    # The shim variant that runs the real `rbenv exec` chain, exactly as the
    # user's PATH does -- its :launch span therefore carries the rbenv cost.
    # It shares the tool's own name, so nothing downstream can tell it apart
    # from the real shim.
    class RbenvShim < Shim
      def command_word
        executable_name
      end

      private

      def exec_line
        %(exec rbenv exec "#{executable_name}" "$@")
      end
    end
  end
end
