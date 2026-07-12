module Ready
  module Bench
    ##
    # The rubygems stub a cold invocation runs after the shim -- resolved the
    # way rbenv itself resolves it -- plus the mark surgery that makes a COPY
    # of it measurable. The instrumented copy marks:
    #
    #   rubygems_ready    - after `Gem.use_gemdeps`, closing the :rubygems span
    #   bin_path_resolved - after `Gem.activate_bin_path`, separating
    #                       dependency activation (:activation) from the tool
    #                       itself (:tool_run)
    #   ruby_exit         - at_exit, closing :tool_run
    class RubygemsStub
      # The two forms a standard stub uses to activate-and-run the tool; both
      # capture (indent, arguments) so the rewrite can split the combined call.
      ACTIVATION_CALLS = [
        /^(\s*)Gem\.activate_and_load_bin_path\((.*)\)/,
        /^(\s*)load Gem\.activate_bin_path\((.*)\)/,
      ].freeze

      def self.for_executable(executable_name)
        stub_path = `rbenv which #{executable_name}`.strip
        raise "rbenv could not resolve #{executable_name.inspect} to a rubygems stub" if stub_path.empty?

        stub_source = Pathname(stub_path).read
        new(stub_source)
      end

      def initialize(source)
        @source = source
      end

      def instrumented_source
        @source
          .sub(/\A(#!.*\n)?/) { "#{Regexp.last_match(1)}#{prologue}" }
          .sub(/(Gem\.use_gemdeps.*\n)/) { "#{Regexp.last_match(1)}#{MarkHelper.record(:rubygems_ready)}\n" }
          .then { split_activation_calls(it) }
      end

      private

      # The mark helper plus the exit mark, inserted after any shebang line.
      def prologue
        "#{MarkHelper.definition}at_exit { #{MarkHelper.record(:ruby_exit)} }\n"
      end

      def split_activation_calls(source)
        ACTIVATION_CALLS.reduce(source) do |rewritten, call|
          rewritten.gsub(call) { split_activation(Regexp.last_match(1), Regexp.last_match(2)) }
        end
      end

      # One combined activate-and-load call becomes activate, mark, load --
      # the mark between them is what separates :activation from :tool_run.
      def split_activation(indent, arguments)
        "#{indent}activated_bin_path = Gem.activate_bin_path(#{arguments}); " \
          "#{MarkHelper.record(:bin_path_resolved)}; " \
          "load activated_bin_path"
      end
    end
  end
end
