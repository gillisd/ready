RSpec.describe Ready::Bench::Report do
  subject(:report) { described_class.new(cold: arm_result(:cold), hot: arm_result(:hot)) }

  def arm_result(name)
    Ready::Bench::ArmResult.new(name:, warmups: 0).tap do |result|
      waterfall = Ready::Bench::Waterfall.new(rubygems: 5.0, full: 20.0)
      result.record(Ready::Bench::Measurement.new(waterfall:, wall_clock_seconds: 0.02))
    end
  end

  it "renders a waterfall including the full row without raising" do
    expect { report.render }.to output(/full/).to_stdout
  end
end
