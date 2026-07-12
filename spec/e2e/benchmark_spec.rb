RSpec.describe "ready startup benchmark", :e2e do
  it "shows the hot arm eliminating the boot layers and beating cold by a wide margin" do
    runner = Ready::Bench::Runner.new(executable: "irb", library: "irb",
                                      rounds: 4, warmups: 2, rbenv: false).call
    cold = runner.cold_summary
    hot = runner.hot_summary
    aggregate_failures do
      expect(cold.duration_of(:activation)).to be > 5.0 # cold pays gem activation
      expect(cold.duration_of(:tool_run)).to be > 5.0   # ...and the library require
      expect(hot.duration_of(:full)).to be < cold.duration_of(:full)
      expect(hot.measured?(:launch)).to be false        # hot skips the rbenv/boot layer
      expect(hot.duration_of(:dispatch_overhead)).to be > 0
    end
  end
end
