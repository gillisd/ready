require "tempfile"

RSpec.describe Ready::Bench::Marks do
  def fixture(contents)
    file = Tempfile.new("marks")
    file.write(contents)
    file.close
    file.path
  end

  let(:log) do
    fixture(<<~LOG)
      hot.1 envelope_start 1000.000
      hot.1 ruby_up 1000.010
      hot.1 entry_start 1000.020
      hot.1 lib_loaded 1000.050
      hot.1 cli_done 1000.070
      hot.1 ruby_exit 1000.080
      hot.1 envelope_end 1000.090
    LOG
  end

  it "parses each run into a mark=>time map" do
    expect(described_class.parse(log)["hot.1"]["cli_done"]).to eq(1000.070)
  end

  it "computes span durations in milliseconds" do
    spans = described_class.spans(described_class.parse(log)["hot.1"])
    aggregate_failures do
      expect(spans["TOTAL"]).to be_within(1e-6).of(90.0)
      expect(spans["lib_load"]).to be_within(1e-6).of(30.0)
    end
  end

  it "omits spans whose endpoints are missing" do
    marks = { "envelope_start" => 1.0, "envelope_end" => 1.1 }
    expect(described_class.spans(marks).keys).to eq(["TOTAL"])
  end
end
