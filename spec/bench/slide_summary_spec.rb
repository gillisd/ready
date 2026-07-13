RSpec.describe Ready::Bench::SlideSummary do
  subject(:summary) { described_class.new(cold:, rbenv_shim_overhead: 40.0) }

  let(:cold) do
    cold_arm(shell: 5.0, launch: 40.0, rubygems: 5.0, activation: 37.0,
             tool_run: 19.0, reap: 2.0, full: 108.0)
  end

  def cold_arm(**durations)
    Ready::Bench::ArmResult.new(name: :cold, warmups: 0).tap do |result|
      waterfall = Ready::Bench::Waterfall.new(**durations)
      result.record(Ready::Bench::Measurement.new(waterfall:, wall_clock_seconds: 0.15))
    end
  end

  def milliseconds_for(label)
    summary.lines.find { it.label == label }.rounded_milliseconds
  end

  it "reports each cold layer as its own rounded-millisecond line", :aggregate_failures do
    expect(milliseconds_for("shell")).to eq(5)
    expect(milliseconds_for("activate deps")).to eq(37)
    expect(milliseconds_for("the tool")).to eq(19)
  end

  it "folds the interpreter boot into the rubygems layer" do
    expect(milliseconds_for("rubygems")).to eq(45)
  end

  it "slots the rbenv shim after the shell only when its overhead was measured", :aggregate_failures do
    expect(summary.lines.map(&:label)).to eq(["shell", "rbenv shim", "rubygems", "activate deps", "the tool"])
    expect(milliseconds_for("rbenv shim")).to eq(40)

    without_shim = described_class.new(cold:, rbenv_shim_overhead: nil)
    expect(without_shim.lines.map(&:label)).not_to include("rbenv shim")
  end

  it "totals the real end-to-end cold time through the shim, tilde-marked", :aggregate_failures do
    expect(summary.total_line.rounded_milliseconds).to eq(148)
    expect(summary.total_line.prefix).to eq("~")
  end

  it "renders aligned label/millisecond columns for a slide", :aggregate_failures do
    rendered = summary.render
    expect(rendered).to match(/rubygems\s+45 ms/)
    expect(rendered).to match(/total\s+~148 ms/)
  end
end
