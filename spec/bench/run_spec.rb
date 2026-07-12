RSpec.describe Ready::Bench::Run do
  subject(:run) do
    described_class.new(id: "cold.3", mark_times: { harness_start: 1000.0, ruby_exit: 1000.2 })
  end

  it "knows which marks it recorded" do
    aggregate_failures do
      expect(run.recorded?(:harness_start)).to be true
      expect(run.recorded?(:server_entry)).to be false
    end
  end

  it "measures the milliseconds between two recorded marks" do
    expect(run.milliseconds_between(:harness_start, :ruby_exit)).to be_within(1e-6).of(200.0)
  end
end
