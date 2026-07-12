require "shellwords"

module Ready
  module Bench
    ##
    # Runs the executable through the warm by-server, instrumenting the REAL
    # Ready::Executable render output (a copy -- no gem runtime is edited).
    # The zsh stub and the instrumented source mark:
    #
    #   command_start - first statement of the zsh stub function, closing the
    #                   :shell span (hot pays a function call there, no fork,
    #                   no exec -- the same boundary the cold shim marks)
    #   server_entry  - first statement of the eval'd source; command_start
    #                   to here is :dispatch_overhead (client boot, socket,
    #   pre_tool      - immediately before the tool's entry call, where the
    #                   preloaded requires end and :server_tool_run begins
    class HotArm
      TOOL_ENTRY_CALL = /^(\s*)([A-Z][\w:]*\.(?:start|run)\b|main\b)/

      def self.instrument_source(rendered_source)
        prologue = "#{MarkHelper.definition}#{MarkHelper.record(:server_entry)}\n"
        "#{prologue}#{rendered_source}".sub(TOOL_ENTRY_CALL) do
          indent = Regexp.last_match(1)
          entry_call = Regexp.last_match(2)
          "#{indent}#{MarkHelper.record(:pre_tool)}\n#{indent}#{entry_call}"
        end
      end

      def initialize(executable_name:, rendered_source:, sandbox:, marks_log:)
        @executable_name = executable_name
        @rendered_source = rendered_source
        @sandbox = sandbox
        @marks_log = marks_log
      end

      # A faithful ready_<name> zsh function (mirrors fn.zsh.erb) whose
      # inlined source carries the marks. +rendered_source+ is the production
      # render, resolved by NAME exactly as `ready gem <name>` does. The
      # command_start mark (bench_mark comes from prof.zsh, sourced first)
      # closes :shell and opens :dispatch_overhead.
      def stub_function
        instrumented = self.class.instrument_source(@rendered_source)
        <<~ZSH
          ready_#{@executable_name}() {
            emulate -L zsh
            bench_mark command_start
            autoload -Uz ready_by
            BY_SOCKET=#{@sandbox.sock_path} ready_by -e #{Shellwords.escape(instrumented)} "$@"
          }
        ZSH
      end

      # Exported in the pty shell so the server worker's marks land in our log
      # (the worker inherits the client's environment).
      def shell_setup(run_id:)
        "export READY_MARKS=#{@marks_log.path} READY_RUN_ID=#{run_id}"
      end
    end
  end
end
