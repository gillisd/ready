require "pty"
require "expect"
require "shellwords"

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
    # IO#expect's timeout is the total seconds to wait for the pattern, so it
    # bounds a hung shell on its own -- no outside watchdog needed. Generous:
    # benchmarked commands finish in well under a second, so this only trips on
    # a genuinely stuck shell (and is roomy enough not to false-alarm on a
    # loaded CI box).
    EXPECT_TIMEOUT = 30

    def initialize(env = {})
      assignments = env.map { |k, v| "#{k}=#{Shellwords.escape(v.to_s)}" }.join(" ")
      command = ["env", assignments, "zsh", "-f", "-i"].reject(&:empty?).join(" ")
      @out, @in, @pid = PTY.spawn(command)
      @seq = 0
      send_line("PS1='@@''P> '")
      expect!(PROMPT)
    rescue StandardError
      close
      raise
    end

    ##
    # Runs +cmd+ to completion and returns a Result.
    def run(cmd)
      @seq += 1
      marker = "DONE#{@seq}"
      started_at = monotonic_clock
      send_line("#{cmd}; print #{marker[0, 2]}''#{marker[2..]}")
      output = expect!(marker)
      Result.new(output:, wall_clock_seconds: monotonic_clock - started_at)
    end

    # TERM the shell's whole process group (the '-' prefix signals the group,
    # reaching forked children so none are orphaned), then hand the shell to
    # Process.detach, which reaps it in a background thread -- never blocking on
    # a wait, never leaving a zombie.
    def close
      return unless @pid

      terminate_group
      Process.detach(@pid)
    end

    private

    def terminate_group
      Process.kill("-TERM", Process.getpgid(@pid))
    rescue Errno::ESRCH, Errno::EPERM, Errno::ECHILD
      nil
    end

    def send_line(line)
      @in.puts(line)
    end

    def monotonic_clock
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    def expect!(pattern)
      result = @out.expect(pattern, EXPECT_TIMEOUT)
      raise "no #{pattern.inspect} within #{EXPECT_TIMEOUT}s; pty tail: #{tail.inspect}" unless result

      result.first
    rescue Errno::EIO
      raise "pty closed waiting for #{pattern.inspect}; pty tail: #{tail.inspect}"
    end

    def tail
      @out.instance_variable_get(:@unusedBuf).to_s[-400..]
    end
  end
end
