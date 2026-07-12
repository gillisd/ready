RSpec.describe Ready::Bench::Report do
  subject(:report) { described_class.new(cold: arm_result(:cold), hot: arm_result(:hot), protocol:) }

  let(:protocol) do
    Ready::Bench::Protocol.new(executable_name: "irb", library: "irb", rounds: 1, warmups: 0)
  end

  def arm_result(name)
    Ready::Bench::ArmResult.new(name:, warmups: 0).tap do |result|
      waterfall = Ready::Bench::Waterfall.new(rubygems: 5.0, full: 20.0)
      result.record(Ready::Bench::Measurement.new(waterfall:, wall_clock_seconds: 0.02))
    end
  end

  it "renders the waterfall including the full row without raising" do
    expect { report.render }.to output(/full/).to_stdout
  end

  it "says exactly what was tested in the preamble" do
    expect { report.render }.to output(/invoked as: irb --version/).to_stdout
  end

  it "gives every statistic its own column" do
    expect { report.render }.to output(/cold minimum/).to_stdout
  end

  it "omits the legend by default" do
    expect { report.render }.not_to output(/what it measures/).to_stdout
  end

  context "when verbose" do
    subject(:report) do
      described_class.new(cold: arm_result(:cold), hot: arm_result(:hot), protocol:, verbose: true)
    end

    it "appends a legend explaining every span row" do
      expect { report.render }.to output(/what it measures/).to_stdout
    end
  end
end
