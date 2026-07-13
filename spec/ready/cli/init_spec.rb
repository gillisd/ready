require "stringio"

RSpec.describe Ready::CLI::Init do
  def run_init(*argv)
    stdout = StringIO.new
    stderr = StringIO.new
    status = described_class.main(argv, stdout: stdout, stderr: stderr)
    [stdout.string, status, stderr.string]
  end

  it "prints a source line pointing at the bundled zsh plugin" do
    output, = run_init
    expect(output).to eq("source #{described_class::PLUGIN_PATH}\n")
  end

  it "points at a plugin file that exists" do
    expect(described_class::PLUGIN_PATH).to exist
  end

  it "errors and exits non-zero when the plugin is missing", :aggregate_failures do
    stub_const("#{described_class}::PLUGIN_PATH", Pathname("/no/such/ready.plugin.zsh"))

    output, status, stderr = run_init

    expect(status).to eq(1)
    expect(output).to be_empty
    expect(stderr).to include("not found")
  end
end
