require "fileutils"
require "rbconfig"
require "stringio"
require "tmpdir"

# Exercised through Up, the simplest command that includes the mixin. Instead of
# stubbing the Kernel calls on the command under test, each example points
# Ready.root at a throwaway project with its own Rakefile and drives the real
# `rake` shell-out, then asserts on what the spawned process actually did.
RSpec.describe Ready::CLI::RakeCommand do
  subject(:command) { Ready::CLI::Up.new(stdout: StringIO.new, stderr: StringIO.new) }

  let(:project_root) { Pathname(Dir.mktmpdir).realpath }

  before do
    project_root.join("Rakefile").write(rakefile)
    allow(Ready).to receive(:root).and_return(project_root)
  end

  after { FileUtils.remove_entry(project_root) }

  context "when the rake task succeeds" do
    let(:rakefile) do
      <<~'RUBY'
        require "rbconfig"
        task(:ready) { File.write("ready.log", "#{RbConfig.ruby}\n#{Dir.pwd}") }
      RUBY
    end

    it "runs rake under the current Ruby, in the project root", :aggregate_failures do
      command.run

      interpreter, working_dir = project_root.join("ready.log").read.lines(chomp: true)
      expect(interpreter).to eq(RbConfig.ruby)
      expect(working_dir).to eq(project_root.to_s)
    end
  end

  context "when the rake task fails" do
    let(:rakefile) { "task(:ready) { exit 3 }" }

    it "exits, propagating rake's failure status" do
      expect { command.run }.to raise_error(an_instance_of(SystemExit).and(having_attributes(status: 3)))
    end
  end
end
