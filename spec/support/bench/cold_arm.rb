module Ready
  module Bench
    ##
    # Prepares the cold arm: faithful, mark-instrumented COPIES of the files a
    # cold invocation runs through, so every layer can be attributed without
    # touching any real file. instrument! writes four artifacts into the
    # workdir:
    #
    #   prelude.rb   - marks ruby_up; armed via RUBYOPT -r, so it is the first
    #                  Ruby user code to run
    #   stub         - the real rubygems stub for the executable, copied and
    #                  instrumented at its standard boundaries (RubygemsStub)
    #   two shims    - RbenvShim (the real `rbenv exec` chain) and DirectShim
    #                  (execs the stub copy under this Ruby); see each class
    class ColdArm
      def initialize(executable_name:, workdir:, marks_log:)
        @executable_name = executable_name
        @workdir = Pathname(workdir)
        @marks_log = marks_log
      end

      def rbenv_shim
        @rbenv_shim ||= RbenvShim.new(executable_name:, workdir:, prelude_path:)
      end

      def direct_shim
        @direct_shim ||= DirectShim.new(executable_name:, workdir:, prelude_path:,
                                        stub_path: instrumented_stub_path)
      end

      def instrument!
        workdir.mkpath
        write_prelude
        write_instrumented_stub
        [rbenv_shim, direct_shim].each(&:write!)
      end

      # Environment a shell exports so marks land in the log and the shim
      # copies shadow the real commands on PATH.
      def environment_for(run_id:)
        {
          "READY_MARKS" => @marks_log.path.to_s,
          "READY_RUN_ID" => run_id,
          "PATH" => "#{workdir}:#{ENV.fetch("PATH", nil)}",
        }.merge(Ready::Sandbox::NON_INTERACTIVE_ENV)
      end

      private

      attr_reader :executable_name, :workdir

      def write_prelude
        prelude_path.write("#{MarkHelper.definition}#{MarkHelper.record(:ruby_up)}\n")
      end

      def write_instrumented_stub
        stub = RubygemsStub.for_executable(executable_name)
        instrumented_stub_path.write(stub.instrumented_source)
      end

      def prelude_path
        workdir / "prelude.rb"
      end

      def instrumented_stub_path
        workdir / "stub"
      end
    end
  end
end
