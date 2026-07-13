RSpec.describe Ready::Bench::Round do
  it "flags warmup rounds" do
    aggregate_failures do
      expect(described_class.new(number: 1, warmup: true).warmup?).to be true
      expect(described_class.new(number: 4, warmup: false).warmup?).to be false
    end
  end

  it "alternates arm order by round parity to cancel drift", :aggregate_failures do
    expect(described_class.new(number: 3, warmup: false).arm_order).to eq(%i[hot cold])
    expect(described_class.new(number: 4, warmup: false).arm_order).to eq(%i[cold hot])
  end

  it "names each arm's run after the round" do
    round = described_class.new(number: 3, warmup: false)
    aggregate_failures do
      expect(round.run_id(:cold)).to eq("cold.3")
      expect(round.run_id(:hot)).to eq("hot.3")
    end
  end
end
