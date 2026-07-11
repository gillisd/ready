require "pty"
require "expect"
require "shellwords"
require "timeout"

module Ready
  ##
  # Drives a real interactive zsh under a pty. Commands are sent as keystrokes;
  # completion is detected by a marker printed after the command, using zsh's
  # `''` quote-splitting so the keystroke echo can never match the marker output.
  class PtyShell
    PROMPT = "@@P> "
    # IO#expect's timeout is inter-character, so also cap each run() with a total
    # deadline (Timeout) to turn a silent hang into a loud failure.
    CHAR_TIMEOUT = 30
    RUN_DEADLINE = 45

    def initialize(env = {})
      assignments = env.map { |k, v| "#{k}=#{Shellwords.escape(v.to_s)}" }.join(" ")
      command = ["env", assignments, "zsh", "-f", "-i"].reject(&:empty?).join(" ")
      @out, @in, @pid = PTY.spawn(command)
      @seq = 0
      send_line("PS1='@@''P> '")
      expect!(PROMPT)
    end

    ##
    # Runs +cmd+ to completion. Returns [captured_output, pty-observed seconds].
    def run(cmd)
      @seq += 1
      marker = "DONE#{@seq}"
      t0 = mono
      out = Timeout.timeout(RUN_DEADLINE, nil, "run timed out: #{cmd.inspect}") do
        send_line("#{cmd}; print #{marker[0, 2]}''#{marker[2..]}")
        expect!(marker)
      end
      [out, mono - t0]
    end

    def close
      send_line("exit")
      Process.wait(@pid)
    rescue Errno::ECHILD, Errno::EIO
      nil
    end

    private

    def send_line(line) = @in.puts(line)
    def mono = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    def expect!(pattern)
      result = @out.expect(pattern, CHAR_TIMEOUT)
      raise "timeout waiting #{pattern.inspect}, tail: #{tail.inspect}" unless result

      result.first
    rescue Errno::EIO
      raise "pty closed waiting #{pattern.inspect}, tail: #{tail.inspect}"
    end

    def tail = @out.instance_variable_get(:@unusedBuf).to_s[-400..]
  end
end
