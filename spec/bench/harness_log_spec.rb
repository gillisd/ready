RSpec.describe Ready::Bench::HarnessLog do
  subject(:log) { described_class.new(invocation: "ri TCPServer") }

  it "lives at the project's log/bench.log" do
    expect(log.path).to eq(Ready.root / "log" / "bench.log")
  end

  it "tees a command's stdout and stderr under a run-id header, silent on the pty", :aggregate_failures do
    fragment = log.tee("hot.3", "bench_harness hot.3 -- ready_ri TCPServer")
    expect(fragment).to include("### hot.3 ###")
    expect(fragment).to include("bench_harness hot.3 -- ready_ri TCPServer")
    expect(fragment).to include("2>&1 | tee -a #{log.path}")
    expect(fragment).to end_with(">/dev/null")
  end
end
