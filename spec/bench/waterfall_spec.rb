RSpec.describe Ready::Bench::Waterfall do
  describe ".of" do
    subject(:waterfall) { described_class.of(run) }

    context "with a cold run's marks" do
      let(:mark_times) do
        { harness_start: 1000.000, shim_start: 1000.001, ruby_up: 1000.065, rubygems_ready: 1000.065,
          bin_path_resolved: 1000.097, ruby_exit: 1000.200, harness_end: 1000.201 }
      end

      let(:run) { Ready::Bench::Run.new(id: "cold.1", mark_times:) }

      it "measures every span whose marks the run recorded", :aggregate_failures do
        expect(waterfall.duration_of(:launch)).to be_within(1e-6).of(64.0)
        expect(waterfall.duration_of(:activation)).to be_within(1e-6).of(32.0)
        expect(waterfall.duration_of(:tool_run)).to be_within(1e-6).of(103.0)
        expect(waterfall.duration_of(:full)).to be_within(1e-6).of(201.0)
      end
    end

    context "with a hot run's marks (no shim, no rubygems)" do
      let(:run) do
        Ready::Bench::Run.new(id: "hot.1", mark_times: {
                                harness_start: 1.000, stub_entry: 1.001, server_entry: 1.053, harness_end: 1.072
                              })
      end

      it "measures only the spans whose marks exist", :aggregate_failures do
        expect(waterfall.measured?(:launch)).to be false
        expect(waterfall.duration_of(:stub_call)).to be_within(1e-6).of(1.0)
        expect(waterfall.duration_of(:dispatch_overhead)).to be_within(1e-6).of(52.0)
        expect(waterfall.duration_of(:full)).to be_within(1e-6).of(72.0)
      end
    end
  end

  describe ".summarizing" do
    subject(:summary) { described_class.summarizing(waterfalls) }

    let(:waterfalls) do
      [
        described_class.new(shell: 3.0, tool_run: 100.0),
        described_class.new(shell: 1.0, tool_run: 110.0),
        described_class.new(shell: 2.0, tool_run: 120.0),
      ]
    end

    it "takes the floor of a process-creation span" do
      expect(summary.duration_of(:shell)).to eq(1.0)
    end

    it "takes the median of an in-process span" do
      expect(summary.duration_of(:tool_run)).to eq(110.0)
    end
  end
end
