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

  describe "#stub_function" do
    it "marks stub_entry as the zsh function's first act after emulate" do
      sandbox = instance_double(Ready::Sandbox, sock_path: Pathname("/tmp/bench/ready.sock"))
      marks_log = Ready::Bench::MarksLog.new("/tmp/bench/marks")
      hot_arm = described_class.new(executable_name: "irb", rendered_source: "IRB.start(__FILE__)\n",
                                    sandbox:, marks_log:)
      expect(hot_arm.stub_function).to include(%(  emulate -L zsh\n  bench_mark stub_entry\n))
    end
  end
end
