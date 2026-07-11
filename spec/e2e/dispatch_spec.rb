RSpec.describe "ready end-to-end dispatch", :e2e do
  before(:all) { @sandbox = Ready::Sandbox.build(executables: ["rake"]) }
  after(:all) { @sandbox&.teardown }

  def in_shell
    shell = Ready::PtyShell.new(@sandbox.shell_env)
    shell.run("source #{@sandbox.plugin_path}")
    yield shell
  ensure
    shell&.close
  end

  it "aliases the bare command to the ready_ stub via readyinit" do
    in_shell do |shell|
      out, = shell.run("whence -v rake")
      expect(out).to include("rake is an alias for ready_rake")
    end
  end

  it "dispatches through the by-server and returns the executable's real output" do
    in_shell do |shell|
      out, = shell.run("rake --version")
      expect(out).to match(/rake, version \d+\.\d+/)
    end
  end
end
