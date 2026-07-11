RSpec.describe Ready::Bench::Report do
  let(:span) { { "spawn+interp" => 5.0, "TOTAL" => 20.0 } }

  it "renders a waterfall without raising and includes the TOTAL row" do
    report = described_class.new(
      { "cold" => [span, span], "hot" => [span, span] },
      { "cold" => [0.02, 0.02], "hot" => [0.02, 0.02] },
    )
    expect { report.render }.to output(/TOTAL/).to_stdout
  end
end
