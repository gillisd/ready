RSpec.describe Ready::PtyShell, :e2e do
  subject(:shell) { described_class.new }

  after { shell.close }

  it "runs a command over a pty and captures its output", :aggregate_failures do
    result = shell.run("print hello-from-zsh")
    expect(result.output).to include("hello-from-zsh")
    expect(result.wall_clock_seconds).to be > 0
  end

  context "when constructed with environment variables" do
    subject(:shell) { described_class.new("READY_PROBE" => "xyz123") }

    it "injects them into the interactive shell" do
      result = shell.run("print $READY_PROBE")
      expect(result.output).to include("xyz123")
    end
  end

  context "when the foreground command swallows the exit keystroke" do
    it "force-kills the shell instead of blocking forever" do
      # Bypasses run's marker sync on purpose: cat occupies the pty and eats
      # every subsequent line, exactly like an interactive tool under bench.
      shell.instance_variable_get(:@in).puts("cat")
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      shell.close
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
      expect(elapsed).to be < (described_class::CLOSE_DEADLINE + 3)
    end
  end
end
