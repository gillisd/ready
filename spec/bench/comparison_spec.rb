RSpec.describe Ready::Bench::Comparison do
  subject(:comparison) do
    described_class.new(command: "ri TCPServer", cold_milliseconds: 500.0, hot_milliseconds: 40.0)
  end

  it "reports how many times faster hot is" do
    expect(comparison.speedup).to be_within(1e-6).of(12.5)
  end

  it "reports what ready eliminates from every invocation" do
    expect(comparison.eliminated_milliseconds).to be_within(1e-6).of(460.0)
  end
end
