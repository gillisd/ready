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
end
