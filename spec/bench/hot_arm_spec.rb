RSpec.describe Ready::Bench::HotArm do
  describe ".instrument_source" do
    subject(:instrumented) { described_class.instrument_source(rendered_source) }

    let(:rendered_source) do
      <<~RUBY
        Process.setproctitle "irb"
        require 'irb'
        IRB.start(__FILE__)
      RUBY
    end

    it "marks server entry before any of the rendered source runs" do
      expect(instrumented.index("server_entry")).to be < instrumented.index("setproctitle")
    end

    it "marks pre_tool immediately before the tool's entry call" do
      expect(instrumented).to include(%(ready_bench_mark("pre_tool")\nIRB.start))
    end
  end
end
