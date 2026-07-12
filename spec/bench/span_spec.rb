RSpec.describe Ready::Bench::Span do
  subject(:span) do
    described_class.new(label: :launch, opening_mark: :shim_start, closing_mark: :ruby_up,
                        summary: :minimum, description: "interpreter boot")
  end

  describe "#measure" do
    it "returns the milliseconds between its two marks" do
      run = Ready::Bench::Run.new(id: "cold.1", mark_times: { shim_start: 10.0, ruby_up: 10.064 })
      expect(span.measure(run)).to be_within(1e-6).of(64.0)
    end

    it "returns nil when the run did not record both marks" do
      run = Ready::Bench::Run.new(id: "hot.1", mark_times: { ruby_up: 10.0 })
      expect(span.measure(run)).to be_nil
    end
  end

  describe "#summarize" do
    it "takes the floor of a :minimum span (jitter only ever adds time)" do
      expect(span.summarize([3.0, 1.0, 2.0])).to eq(1.0)
    end

    it "takes the median of a :median span" do
      median_span = described_class.new(label: :tool_run, opening_mark: :bin_path_resolved,
                                        closing_mark: :ruby_exit, summary: :median,
                                        description: "the tool itself")
      expect(median_span.summarize([100.0, 120.0, 110.0])).to eq(110.0)
    end
  end
end
