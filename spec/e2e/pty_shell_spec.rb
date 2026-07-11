RSpec.describe Ready::PtyShell, :e2e do
  it "runs a command over a pty and captures its output" do
    shell = described_class.new
    out, wall = shell.run("echo hello-from-zsh")
    aggregate_failures do
      expect(out).to include("hello-from-zsh")
      expect(wall).to be > 0
    end
  ensure
    shell&.close
  end

  it "injects environment into the interactive shell" do
    shell = described_class.new("READY_PROBE" => "xyz123")
    out, = shell.run("print $READY_PROBE")
    expect(out).to include("xyz123")
  ensure
    shell&.close
  end
end
