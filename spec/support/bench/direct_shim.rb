require "rbconfig"

module Ready
  module Bench
    ##
    # The shim variant that skips rbenv and execs the instrumented rubygems
    # stub copy directly under this Ruby -- its :launch span is pure
    # interpreter boot, and the stub copy's own marks split every layer after
    # it.
    class DirectShim < Shim
      def command_word = "#{executable_name}_direct"

      private

      attr_reader :stub_path

      def post_initialize(stub_path:)
        @stub_path = stub_path
      end

      def exec_line = %(exec "#{RbConfig.ruby}" "#{stub_path}" "$@")
    end
  end
end
