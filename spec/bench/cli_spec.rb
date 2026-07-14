require "tmpdir"

RSpec.describe Ready::Bench::CLI do
  subject(:cli) { described_class.new }

  describe ".command_segments" do
    it "splits argv into one command per -- separator" do
      segments = described_class.command_segments(%w[ri TCPServer -- ronin help -- kamal version])
      expect(segments).to eq([%w[ri TCPServer], %w[ronin help], %w[kamal version]])
    end

    it "keeps a separator-free argv as a single segment" do
      expect(described_class.command_segments(%w[ri TCPServer])).to eq([%w[ri TCPServer]])
    end
  end

  describe "#invocations_under_test" do
    it "parses each typed segment into an invocation, verbatim" do
      ri = Ready::Bench::Invocation.new(executable_name: "ri", arguments: ["TCPServer"])
      ronin = Ready::Bench::Invocation.new(executable_name: "ronin", arguments: ["help"])
      expect(cli.invocations_under_test([%w[ri TCPServer], %w[ronin help]])).to eq([ri, ronin])
    end

    it "falls back to one run on the rake task's default" do
      expect(cli.invocations_under_test([])).to eq([nil])
    end

    context "with a readyfile and no typed commands" do
      def with_readyfile
        Dir.mktmpdir do |dir|
          readyfile_path = Pathname(dir) / "readyfile"
          readyfile_path.write("gems:\n  - rdoc\nexecutables:\n  - ri\n  - rake\n")
          yield readyfile_path
        end
      end

      it "benches every executable the readyfile declares, bare" do
        bare = %w[ri rake].map { Ready::Bench::Invocation.bare(it) }
        with_readyfile do |readyfile_path|
          cli.option_parser.parse(["--readyfile", readyfile_path.to_s])
          expect(cli.invocations_under_test([])).to eq(bare)
        end
      end
    end
  end

  describe "#environment_for" do
    it "exports nothing by default, deferring every default to the rake task" do
      expect(cli.environment_for(nil)).to eq({})
    end

    it "exports a typed command verbatim -- what you typed is what runs" do
      invocation = Ready::Bench::Invocation.parse(%w[ronin help])
      expect(cli.environment_for(invocation))
        .to eq("BENCH_EXE" => "ronin", "BENCH_ARGS" => "help")
    end

    it "maps the flags onto the BENCH_* contract the rake task reads" do
      cli.option_parser.parse(["--readyfile", "readyfile", "--rounds", "5", "--warmups", "1"])
      expect(cli.environment_for(nil))
        .to eq("BENCH_READYFILE" => "readyfile", "BENCH_RUNS" => "5", "BENCH_WARMUPS" => "1")
    end

    it "routes results to a file only when plotting" do
      cli.option_parser.parse(["--plot", "stacked"])
      expect(cli.environment_for(nil).keys).to eq(["BENCH_RESULTS"])
    end
  end

  describe "#plotter_for" do
    let(:comparisons) { [] }

    it "draws stacked bars with our renderer" do
      expect(cli.plotter_for(:stacked, comparisons)).to be_a(Ready::Bench::Plot::Stacked)
    end

    it "draws side-by-side pairs with stock youplot" do
      expect(cli.plotter_for(:youplot, comparisons)).to be_a(Ready::Bench::Plot::Youplot)
    end
  end

  describe "#task_name" do
    it "runs the plain bench task by default" do
      expect(cli.task_name).to eq("bench")
    end

    it "runs bench:verbose when asked for the legend" do
      cli.option_parser.parse(["--verbose"])
      expect(cli.task_name).to eq("bench:verbose")
    end
  end
end
