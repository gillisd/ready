RSpec.describe Ready::Executable do
  describe "#prologue" do
    subject(:prologue) { described_class.new("ri").prologue }

    it "disables the test/unit auto-runner so a CLI's options aren't parsed as test args" do
      expect(prologue).to include("Test::Unit::AutoRunner.need_auto_run = false if defined?(Test::Unit::AutoRunner)")
    end

    it "still sets the process title" do
      expect(prologue).to include(%(Process.setproctitle "ri"))
    end
  end
end
