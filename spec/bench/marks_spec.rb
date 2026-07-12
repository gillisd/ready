require "tempfile"

RSpec.describe Ready::Bench::Marks do
  def fixture(contents)
    file = Tempfile.new("marks")
    file.write(contents)
    file.close
    file.path
  end

  let(:cold) do
    fixture(<<~LOG)
      cold.1 envelope_start 1000.000
      cold.1 shim_start 1000.001
      cold.1 ruby_up 1000.065
      cold.1 rubygems_ready 1000.065
      cold.1 bin_path_resolved 1000.097
      cold.1 ruby_exit 1000.200
      cold.1 envelope_end 1000.201
    LOG
  end

  it "parses a run into a mark=>time map" do
    expect(described_class.parse(cold)["cold.1"]["bin_path_resolved"]).to eq(1000.097)
  end

  it "computes ready layer spans in ms" do
    spans = described_class.spans(described_class.parse(cold)["cold.1"])
    aggregate_failures do
      expect(spans["launch"]).to be_within(1e-6).of(64.0)       # shim_start->ruby_up
      expect(spans["dep_activate"]).to be_within(1e-6).of(32.0) # rubygems_ready->bin_path_resolved
      expect(spans["tool_run"]).to be_within(1e-6).of(103.0)    # bin_path_resolved->ruby_exit
      expect(spans["full"]).to be_within(1e-6).of(201.0)
    end
  end

  it "omits spans whose endpoints are missing (hot arm has no shim)" do
    hot = { "envelope_start" => 1.0, "server_entry" => 1.053, "envelope_end" => 1.072 }
    spans = described_class.spans(hot)
    aggregate_failures do
      expect(spans).not_to have_key("launch")
      expect(spans["dispatch_infra"]).to be_within(1e-6).of(53.0)
      expect(spans["full"]).to be_within(1e-6).of(72.0)
    end
  end
end
