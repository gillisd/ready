require "stringio"

RSpec.describe Ready::CLI::Compile do
  def run_compile(*argv)
    stdout = StringIO.new
    stderr = StringIO.new
    status = described_class.main(argv, stdout: stdout, stderr: stderr)
    [stdout.string, status, stderr.string]
  end

  describe "the `by` client alias" do
    it "prints the by alias for `by`", :aggregate_failures do
      output, status = run_compile("by")
      expect(status).to eq(0)
      expect(output).to include("--disable-gems")
    end

    it "keeps rubygems for `by --rubygems`" do
      output, = run_compile("by", "--rubygems")
      expect(output).not_to include("--disable-gems")
    end

    it "enables yjit for `by --yjit`" do
      output, = run_compile("by", "--yjit")
      expect(output).to include("--yjit")
    end
  end

  describe "named CLIs" do
    let(:script) { instance_double(Ready::ZshScript, to_s: "STUB") }

    before { allow(Ready::ZshScript).to receive(:new).and_return(script) }

    it "routes names and accumulated -e env through ZshScript", :aggregate_failures do
      output, status = run_compile("-e", "BY_SOCKET=/x", "-e", "RAILS_ENV=production", "irb", "rspec")

      expect(Ready::ZshScript).to have_received(:new)
        .with(names: ["irb", "rspec"], environment: { "BY_SOCKET" => "/x", "RAILS_ENV" => "production" })
      expect(status).to eq(0)
      expect(output).to eq("STUB")
    end

    it "preserves `=` inside an -e value" do
      run_compile("-e", "DB=postgres://x=y", "rails")

      expect(Ready::ZshScript).to have_received(:new)
        .with(names: ["rails"], environment: { "DB" => "postgres://x=y" })
    end
  end

  describe "`all`" do
    it "delegates to the ready:compile rake task" do
      command = described_class.new(stdout: StringIO.new, stderr: StringIO.new)
      allow(command).to receive(:rake)

      command.run("all")

      expect(command).to have_received(:rake).with("ready:compile")
    end
  end

  describe "input validation" do
    it "rejects an -e argument without `=`", :aggregate_failures do
      _output, status, stderr = run_compile("-e", "NOEQUALS", "irb")
      expect(status).to eq(1)
      expect(stderr).to include("invalid --environment")
    end

    it "rejects `all`/`by` combined with other names", :aggregate_failures do
      _output, status, stderr = run_compile("all", "irb")
      expect(status).to eq(1)
      expect(stderr).to include("cannot be combined")
    end

    it "exits with an insufficient-arguments error when given no arguments", :aggregate_failures do
      _output, status, stderr = run_compile
      expect(status).to eq(1)
      expect(stderr).to include("insufficient number of arguments")
    end
  end
end
