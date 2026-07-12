require "tempfile"

RSpec.describe Ready::Bench::MarksLog do
  subject(:marks_log) { described_class.new(file.path) }

  let(:file) do
    Tempfile.new("marks").tap do |tempfile|
      tempfile.write(<<~LOG)
        cold.1 harness_start 1000.000
        cold.1 ruby_up 1000.065
        hot.1 harness_start 2000.000
      LOG
      tempfile.close
    end
  end

  it "reconstructs a run from its own lines only", :aggregate_failures do
    run = marks_log.run("cold.1")
    expect(run.recorded?(:harness_start)).to be true
    expect(run.recorded?(:ruby_up)).to be true
    expect(run.milliseconds_between(:harness_start, :ruby_up)).to be_within(1e-6).of(65.0)
  end

  it "returns a run with no marks for an id that never logged any" do
    expect(marks_log.run("cold.99").recorded?(:harness_start)).to be false
  end
end
