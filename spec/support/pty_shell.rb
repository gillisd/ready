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
    ##
    # What one #run produced: the output captured up to the completion marker,
    # and the seconds (a Float, read from CLOCK_MONOTONIC) the driver observed
    # from outside the shell between sending the command and seeing the marker.
    Result = Data.define(:output, :wall_clock_seconds)

    PROMPT = "@@P> ".freeze
    CHAR_TIMEOUT = 30
    # Hard ceiling on any single wait. Ruby's Timeout cannot reliably interrupt
    # a blocking pty read (notably on macOS), so a watchdog thread enforces the
    # deadline by SIGKILLing the shell's whole process group -- which closes the
    # pty and unblocks the read at the OS level. Nothing here can hang unbounded.
    RUN_DEADLINE = 45
    CLOSE_DEADLINE = 5

    def initialize(env = {})
      assignments = env.map { |k, v| "#{k}=#{Shellwords.escape(v.to_s)}" }.join(" ")
      command = ["env", assignments, "zsh", "-f", "-i"].reject(&:empty?).join(" ")
      @out, @in, @pid = PTY.spawn(command)
      @seq = 0
      send_line("PS1='@@''P> '")
      await(PROMPT, "shell startup")
    rescue StandardError
      kill_group
      reap
      raise
    end

    ##
    # Runs +cmd+ to completion and returns a Result.
    def run(cmd)
      @seq += 1
      marker = "DONE#{@seq}"
      started_at = monotonic_clock
      send_line("#{cmd}; print #{marker[0, 2]}''#{marker[2..]}")
      output = await(marker, "run #{cmd.inspect}")
      Result.new(output:, wall_clock_seconds: monotonic_clock - started_at)
    end

    def close
      send_line("exit")
      Timeout.timeout(CLOSE_DEADLINE) { Process.wait(@pid) }
    rescue Timeout::Error
      kill_group
    rescue Errno::ECHILD, Errno::EIO
      nil
    ensure
      reap
    end

    private

    # Waits for +pattern+ under a watchdog that SIGKILLs the shell's process
    # group after RUN_DEADLINE. Killing the shell closes the pty, so a blocked
    # read fails and we raise with the pty tail -- what the shell was stuck on.
    def await(pattern, context)
      timed_out = false
      watchdog = watchdog_thread { timed_out = true }
      expect!(pattern)
    rescue StandardError => e
      raise(timed_out ? "timed out during #{context}; pty tail: #{tail.inspect}" : e)
    ensure
      watchdog&.kill
    end

    def watchdog_thread
      Thread.new do
        sleep(RUN_DEADLINE)
        yield
        kill_group
      end
    end

    # SIGKILL the shell's whole process group so its children (a stuck tool, a
    # pager, the by client) die with it -- a lone kill of the shell pid would
    # orphan them.
    def kill_group
      Process.kill("KILL", -Process.getpgid(@pid))
    rescue Errno::ESRCH, Errno::EPERM, Errno::ECHILD
      nil
    end

    def reap
      Process.wait(@pid)
    rescue Errno::ECHILD, Errno::ESRCH
      nil
    end

    def send_line(line)
      @in.puts(line)
    end

    def monotonic_clock
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    def expect!(pattern)
      result = @out.expect(pattern, CHAR_TIMEOUT)
      raise "timeout waiting #{pattern.inspect}, tail: #{tail.inspect}" unless result

      result.first
    rescue Errno::EIO
      raise "pty closed waiting #{pattern.inspect}, tail: #{tail.inspect}"
    end

    def tail
      @out.instance_variable_get(:@unusedBuf).to_s[-400..]
    end
  end
end
