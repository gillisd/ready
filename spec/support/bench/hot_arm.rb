require "shellwords"

module Ready
  module Bench
    ##
    # Runs a gem executable through the warm by-server and marks the dispatch
    # infra vs the (preloaded) tool_run. Uses the REAL Ready::Executable render
    # output with marks injected into a copy, so no gem-runtime edit is needed.
    class HotArm
      TOOL_START = /^(\s*)([A-Z][\w:]*\.(?:start|run)\b|main\b)/

      # A mark statement for the eval'd source: the name is interpolated now, the
      # run-id and clock read stay literal so they run inside the by-server worker
      # (which inherits the client's READY_MARKS/READY_RUN_ID env).
      def self.mark(name)
        rid = %(\#{ENV.fetch('READY_RUN_ID')})
        clock = %(\#{Process.clock_gettime(Process::CLOCK_REALTIME)})
        %(File.open(ENV.fetch("READY_MARKS"), "a") { |f| f.puts "#{rid} #{name} #{clock}" })
      end

      def self.instrument_source(rendered)
        out = "#{mark("server_entry")}\n#{rendered}"
        out.sub(TOOL_START) do
          "#{Regexp.last_match(1)}#{mark("pre_tool")}\n#{Regexp.last_match(1)}#{Regexp.last_match(2)}"
        end
      end

      def initialize(exe:, exe_path:, sandbox:, marks_path:)
        @exe = exe
        @exe_path = Pathname(exe_path)
        @sandbox = sandbox
        @marks_path = Pathname(marks_path)
      end

      # A faithful ready_<exe> zsh function (mirrors fn.zsh.erb) whose inlined
      # source carries the marks. The source is the real Ready::Executable render.
      def stub_function
        source = self.class.instrument_source(Ready::Executable.new(@exe_path.to_s).render)
        <<~ZSH
          ready_#{@exe}() {
            emulate -L zsh
            autoload -Uz ready_by
            BY_SOCKET=#{@sandbox.sock_path} ready_by -e #{Shellwords.escape(source)} "$@"
          }
        ZSH
      end

      # Exported in the pty shell so the worker's marks land in our file.
      def shell_setup(run_id:)
        "export READY_MARKS=#{@marks_path} READY_RUN_ID=#{run_id}"
      end
    end
  end
end
