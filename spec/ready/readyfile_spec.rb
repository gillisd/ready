require "fileutils"
require "tempfile"
require "tmpdir"

RSpec.describe Ready::Readyfile do
  let(:build_dir) { Dir.mktmpdir }

  after { FileUtils.remove_entry(build_dir) }

  def readyfile(content)
    file = Tempfile.new("readyfile")
    file.write(content) if content
    file.close
    described_class.open(file.path, build_dir: build_dir)
  end

  describe ".open" do
    it "treats a missing readyfile as empty", :aggregate_failures do
      config = described_class.open("/no/such/readyfile", build_dir: build_dir)
      expect(config.gem_names).to eq([])
      expect(config.executable_names).to eq([])
    end

    it "treats an empty readyfile as empty" do
      expect(readyfile("").gem_names).to eq([])
    end

    it "treats a null document as empty" do
      expect(readyfile("---\n").gem_names).to eq([])
    end

    it "parses declared gems and executables", :aggregate_failures do
      config = readyfile("gems:\n  - rails\nexecutables:\n  - irb\n")
      expect(config.gem_names).to eq(["rails"])
      expect(config.executable_names).to eq(["irb"])
    end
  end
end
