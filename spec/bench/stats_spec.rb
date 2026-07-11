RSpec.describe Ready::Bench::Stats do
  it "returns the middle value for odd counts" do
    expect(described_class.median([3, 1, 2])).to eq(2)
  end

  it "averages the two middle values for even counts" do
    expect(described_class.median([1, 2, 3, 4])).to eq(2.5)
  end
end
