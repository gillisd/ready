RSpec.describe "ready startup benchmark", :e2e do
  it "shows the hot arm eliminating the boot layers and beating cold by a wide margin" do
    runner = Ready::Bench::Runner.new(exe: "irb", lib: "irb", runs: 4, warmups: 2, rbenv: false).call
    aggregate_failures do
      expect(runner.cold["dep_activate"]).to be > 5.0        # cold pays gem activation
      expect(runner.cold["tool_run"]).to be > 5.0            # ...and the library require
      expect(runner.hot["full"]).to be < runner.cold["full"] # hot is faster (wide margin)
      expect(runner.hot).not_to have_key("launch")           # hot skips the rbenv/boot layer
      expect(runner.hot["dispatch_infra"]).to be > 0         # hot dispatch was measured
    end
  end
end
