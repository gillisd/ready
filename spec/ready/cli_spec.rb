require "stringio"

RSpec.describe Ready::CLI do
  ["--version", "-V"].each do |flag|
    it "prints the version and exits 0 for #{flag}" do
      stdout = StringIO.new
      status = described_class.main([flag], stdout: stdout, stderr: StringIO.new)

      expect(stdout.string).to eq("ready #{Ready::VERSION}\n")
      expect(status).to eq(0)
    end
  end
end
