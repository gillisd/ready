RSpec.describe Ready::Bench::Aggregator do
  subject(:agg) { described_class.new(span_kind: { "shell" => :min, "tool_run" => :median }) }

  it "takes the min for process spans and median for in-process spans" do
    runs = [
      { "shell" => 3.0, "tool_run" => 100.0 },
      { "shell" => 1.0, "tool_run" => 110.0 },
      { "shell" => 2.0, "tool_run" => 120.0 },
    ]
    result = agg.combine(runs)
    aggregate_failures do
      expect(result["shell"]).to eq(1.0)
      expect(result["tool_run"]).to eq(110.0)
    end
  end

  it "defaults an unlisted span to median" do
    expect(described_class.new(span_kind: {}).combine([{ "x" => 4.0 }, { "x" => 2.0 }])["x"]).to eq(3.0)
  end
end
