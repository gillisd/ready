RSpec.describe Ready::Bench::Plot::Stacked do
  subject(:plot) { described_class.new(comparisons) }

  def comparison(command, cold, hot)
    Ready::Bench::Comparison.new(command:, cold_milliseconds: cold, hot_milliseconds: hot)
  end

  describe "the common case" do
    let(:comparisons) { [comparison("ri", 500.0, 50.0), comparison("rake", 250.0, 125.0)] }

    # Global max is 500ms -> 40 cells, so 0.08 cells/ms: ri stacks 4 hot + 36
    # eliminated, rake 10 hot + 10 eliminated.
    let(:ri_bar) { ("#" * 4) + ("." * 36) }
    let(:rake_bar) { ("#" * 10) + ("." * 10) }

    it "stacks ready and eliminated into one bar per command, on a shared scale", :aggregate_failures do
      expect { plot.render }.to output(
        a_string_including(ri_bar).and(including("50.0 ready")).and(including("500.0 cold"))
          .and(including("(10.0x)")).and(including(rake_bar)).and(including("125.0 ready"))
          .and(including("(2.0x)")),
      ).to_stdout
    end
  end

  describe "a regression (hot slower than cold)" do
    let(:comparisons) { [comparison("slow", 100.0, 150.0)] }

    it "never overflows the bar width, and reports the sub-1x speedup", :aggregate_failures do
      line = capture(plot).lines.last
      bar = line[/[#.]+/]
      expect(bar.length).to eq(described_class::WIDTH)
      expect(line).to include("(0.7x)")
    end
  end

  describe "a command longer than the others" do
    let(:comparisons) { [comparison("bundler-audit check", 300.0, 40.0), comparison("ri", 500.0, 50.0)] }

    it "aligns every bar to the widest command" do
      bar_columns = capture(plot).lines.drop(1).map { it.index(/[#.]/) }
      expect(bar_columns.uniq.length).to eq(1)
    end
  end

  def capture(plot)
    original = $stdout
    $stdout = StringIO.new
    plot.render
    $stdout.string
  ensure
    $stdout = original
  end
end
