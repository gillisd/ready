RSpec.describe Ready::ByExecutable do
  describe "#to_alias" do
    it "disables rubygems and yjit by default" do
      line = described_class.new.without_rubygems.without_yjit.to_alias
      expect(line).to include("--disable-gems")
      expect(line).not_to include("--yjit")
      expect(line).to end_with('"${@}"')
    end

    it "keeps rubygems when requested" do
      expect(described_class.new.with_rubygems.to_alias).not_to include("--disable-gems")
    end

    it "enables yjit when requested" do
      expect(described_class.new.with_yjit.to_alias).to include("--yjit")
    end
  end

  it "does not require READY_SOCK_PATH to build" do
    expect { described_class.new }.not_to raise_error
  end
end
