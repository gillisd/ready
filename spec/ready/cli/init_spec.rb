require "stringio"

RSpec.describe Ready::CLI::Init do
  it "prints a source line pointing at the bundled zsh plugin" do
    stdout = StringIO.new
    described_class.new(stdout: stdout).run
    expect(stdout.string).to match(%r{\Asource .+/zsh/ready/ready\.plugin\.zsh\n\z})
  end

  it "points at a plugin file that exists" do
    expect(described_class::PLUGIN_PATH).to exist
  end

  it "errors and exits non-zero when the plugin is missing" do
    stub_const("#{described_class}::PLUGIN_PATH", Pathname("/no/such/ready.plugin.zsh"))
    stdout = StringIO.new
    stderr = StringIO.new

    status = described_class.main([], stdout: stdout, stderr: stderr)

    expect(status).to eq(1)
    expect(stdout.string).to be_empty
    expect(stderr.string).to match(/not found/)
  end
end
