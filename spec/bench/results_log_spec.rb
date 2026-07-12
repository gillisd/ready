require "tempfile"

RSpec.describe Ready::Bench::ResultsLog do
  subject(:results_log) { described_class.new(file.path) }

  let(:file) { Tempfile.new("bench-results") }

  def record(command, cold:, hot:)
    results_log.append(command:, arm: :cold, full_milliseconds: cold)
    results_log.append(command:, arm: :hot, full_milliseconds: hot)
  end

  it "reads appended arm rows back as one comparison per command, in order" do
    record("ri TCPServer", cold: 500.0, hot: 40.0)
    record("rake", cold: 130.0, hot: 65.0)

    ri = Ready::Bench::Comparison.new(command: "ri TCPServer", cold_milliseconds: 500.0, hot_milliseconds: 40.0)
    rake = Ready::Bench::Comparison.new(command: "rake", cold_milliseconds: 130.0, hot_milliseconds: 65.0)
    expect(results_log.comparisons).to eq([ri, rake])
  end

  it "keeps the same executable on different inputs as distinct comparisons" do
    record("ri TCPServer", cold: 500.0, hot: 40.0)
    record("ri Socket", cold: 480.0, hot: 38.0)

    expect(results_log.comparisons.map(&:command)).to eq(["ri TCPServer", "ri Socket"])
  end
end
