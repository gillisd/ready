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

  describe "success of the invocation" do
    def run_with(exit_status)
      described_class.new(id: "cold.1", mark_times: {}, exit_status:)
    end

    it "succeeds only on a zero exit status", :aggregate_failures do
      expect(run_with(0).succeeded?).to be true
      expect(run_with(1).succeeded?).to be false
      expect(run_with(nil).succeeded?).to be false
    end

    it "explains why it failed", :aggregate_failures do
      expect(run_with(2).failure_reason).to eq("exited 2")
      expect(run_with(nil).failure_reason).to include("no exit status")
    end
  end
end
