require "stringio"

# Exercised through Up, the simplest command that includes the mixin.
RSpec.describe Ready::CLI::RakeCommand do
  subject(:command) { Ready::CLI::Up.new(stdout: StringIO.new, stderr: StringIO.new) }

  it "runs rake under the current Ruby, in the project root" do
    expect(command).to receive(:system)
      .with(RbConfig.ruby, "-S", "rake", "ready", chdir: Ready.root.to_s)
      .and_return(true)

    command.run
  end

  it "exits when rake fails" do
    allow(command).to receive(:system).and_return(false)
    expect(command).to receive(:exit)

    command.run
  end
end
