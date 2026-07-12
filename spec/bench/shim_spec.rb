require "fileutils"
require "tmpdir"

RSpec.describe Ready::Bench::Shim do
  let(:workdir) { Pathname(Dir.mktmpdir("shim")) }
  let(:prelude_path) { workdir / "prelude.rb" }

  after { FileUtils.rm_rf(workdir) }

  shared_examples "a shim variant" do
    before { shim.write! }

    let(:script) { (workdir / shim.command_word).read }

    it "writes an executable file named by its command word" do
      expect(workdir / shim.command_word).to be_executable
    end

    it "marks shim_start, arms the prelude, and execs its variant's target", :aggregate_failures do
      expect(script).to include("shim_start")
      expect(script).to include("--disable-gems -r#{prelude_path}")
      expect(script).to include(expected_exec_line)
    end
  end

  describe Ready::Bench::RbenvShim do
    subject(:shim) { described_class.new(executable_name: "irb", workdir:, prelude_path:) }

    let(:expected_exec_line) { %(exec rbenv exec "irb" "$@") }

    it "shares the tool's own name so PATH resolution cannot tell it apart" do
      expect(shim.command_word).to eq("irb")
    end

    it_behaves_like "a shim variant"
  end

  describe Ready::Bench::DirectShim do
    subject(:shim) do
      described_class.new(executable_name: "irb", workdir:, prelude_path:, stub_path: workdir / "stub")
    end

    let(:expected_exec_line) { %(exec "#{RbConfig.ruby}" "#{workdir / "stub"}" "$@") }

    it "answers a distinct command word so both variants can share a PATH" do
      expect(shim.command_word).to eq("irb_direct")
    end

    it_behaves_like "a shim variant"
  end
end
