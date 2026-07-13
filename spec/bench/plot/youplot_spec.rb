RSpec.describe Ready::Bench::Plot::Youplot do
  subject(:plot) { described_class.new(comparisons) }

  def comparison(command, cold, hot)
    Ready::Bench::Comparison.new(command:, cold_milliseconds: cold, hot_milliseconds: hot)
  end

  describe "#title" do
    it "names the plot after a lone command" do
      one = described_class.new([comparison("ronin encode", 800.0, 40.0)])
      expect(one.send(:title)).to eq("full startup (ms): ronin encode")
    end

    it "falls back to the generic title for several commands" do
      two = described_class.new([comparison("ri", 500.0, 40.0), comparison("rake", 130.0, 60.0)])
      expect(two.send(:title)).to eq("full startup (ms): cold vs ready")
    end
  end

  describe "#label" do
    it "uses bare arm labels for a lone command (the command is the title)" do
      one = described_class.new([comparison("ronin encode", 800.0, 40.0)])
      expect(one.send(:label, comparison("ronin encode", 800.0, 40.0), "ready")).to eq("ready")
    end

    it "prefixes the command when several commands share the plot" do
      two = described_class.new([comparison("ri", 500.0, 40.0), comparison("rake", 130.0, 60.0)])
      expect(two.send(:label, comparison("ri", 500.0, 40.0), "cold")).to eq("ri cold")
    end
  end
end
