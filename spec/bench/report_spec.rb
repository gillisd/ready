RSpec.describe Ready::Bench::Report do
  subject(:report) do
    described_class.new(cold: arm_result(:cold, full: 200.0), hot: arm_result(:hot, full: 40.0), protocol:)
  end

  let(:protocol) do
    Ready::Bench::Protocol.new(executable_name: "ri", arguments: ["TCPServer"],
                               preload_gems: ["rdoc"], rounds: 1, warmups: 0)
  end

  def arm_result(name, full:)
    Ready::Bench::ArmResult.new(name:, warmups: 0).tap do |result|
      waterfall = Ready::Bench::Waterfall.new(rubygems: 5.0, full:)
      result.record(Ready::Bench::Measurement.new(waterfall:, wall_clock_seconds: full / 1000.0))
    end
  end

  it "leads with the caveat-less numbers and the speedup, rounded to a tenth" do
    expect { report.render }.to output(a_string_including("ready is 5.0x faster, saving 160.0 ms per run")).to_stdout
  end

  it "labels the fast arm 'ready', not 'hot'", :aggregate_failures do
    expect { report.render }.to output(/ready median/).to_stdout
    expect { report.render }.not_to output(/hot median/).to_stdout
  end

  it "carries the cold-minus-ready delta as its own table column" do
    expect { report.render }.to output(/span.*delta/).to_stdout
  end

  it "says exactly what was tested in the preamble" do
    expect { report.render }.to output(/invoked as: ri TCPServer/).to_stdout
  end

  it "omits the legend by default" do
    expect { report.render }.not_to output(/what it measures/).to_stdout
  end

  context "when verbose" do
    subject(:report) do
      described_class.new(cold: arm_result(:cold, full: 200.0), hot: arm_result(:hot, full: 40.0),
                          protocol:, verbose: true)
    end

    it "appends a legend and the harness vocabulary", :aggregate_failures do
      expect { report.render }.to output(/what it measures/).to_stdout
      expect { report.render }.to output(/^terms$/).to_stdout
    end
  end
end
