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
      cold.1 ruby_up 1000.050
      cold.1 rubygems_ready 1000.100
      cold.1 dep_activated 1000.140
      cold.1 ruby_exit 1000.243
      cold.1 envelope_end 1000.244
    LOG
  end

  it "parses a run into a mark=>time map" do
    expect(described_class.parse(cold)["cold.1"]["dep_activated"]).to eq(1000.140)
  end

  it "computes ready layer spans in ms" do
    spans = described_class.spans(described_class.parse(cold)["cold.1"])
    aggregate_failures do
      expect(spans["rbenv_shim"]).to be_within(1e-6).of(49.0)
      expect(spans["rubygems"]).to be_within(1e-6).of(50.0)
      expect(spans["dep_activate"]).to be_within(1e-6).of(40.0)
      expect(spans["tool_run"]).to be_within(1e-6).of(103.0)
      expect(spans["full"]).to be_within(1e-6).of(244.0)
    end
  end

  it "omits spans whose endpoints are missing (hot arm has no shim)" do
    hot = { "envelope_start" => 1.0, "server_entry" => 1.053, "envelope_end" => 1.072 }
    spans = described_class.spans(hot)
    aggregate_failures do
      expect(spans).not_to have_key("rbenv_shim")
      expect(spans["dispatch_infra"]).to be_within(1e-6).of(53.0)
      expect(spans["full"]).to be_within(1e-6).of(72.0)
    end
  end
end
