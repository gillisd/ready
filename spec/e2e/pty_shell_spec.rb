RSpec.describe Ready::PtyShell, :e2e do
  subject(:shell) { described_class.new }

  after { shell.close }

  it "runs a command over a pty and captures its output" do
    output, wall_seconds = shell.run("print hello-from-zsh")
    aggregate_failures do
      expect(output).to include("hello-from-zsh")
      expect(wall_seconds).to be > 0
    end
  end

  context "when constructed with environment variables" do
    subject(:shell) { described_class.new("READY_PROBE" => "xyz123") }

    it "injects them into the interactive shell" do
      output, = shell.run("print $READY_PROBE")
      expect(output).to include("xyz123")
    end
  end
end
