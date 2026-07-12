require "tmpdir"

RSpec.describe Ready::Bench::CLI do
  subject(:cli) { described_class.new }

  describe "#executables_under_test" do
    it "benches the positional executables as given" do
      expect(cli.executables_under_test(%w[ri ronin kamal])).to eq(%w[ri ronin kamal])
    end

    it "falls back to one run on the rake task's default" do
      expect(cli.executables_under_test([])).to eq([nil])
    end

    context "with a readyfile and no positional executables" do
      def with_readyfile
        Dir.mktmpdir do |dir|
          readyfile_path = Pathname(dir) / "readyfile"
          readyfile_path.write("gems:\n  - rdoc\nexecutables:\n  - ri\n  - rake\n")
          yield readyfile_path
        end
      end

      it "benches every executable the readyfile declares" do
        with_readyfile do |readyfile_path|
          cli.option_parser.parse(["--readyfile", readyfile_path.to_s])
          expect(cli.executables_under_test([])).to eq(%w[ri rake])
        end
      end
    end
  end

  describe "#environment_for" do
    it "exports nothing by default, deferring every default to the rake task" do
      expect(cli.environment_for(nil)).to eq({})
    end

    it "maps the flags onto the BENCH_* contract the rake task reads" do
      cli.option_parser.parse(["--readyfile", "readyfile", "--args", "help",
                               "--rounds", "5", "--warmups", "1"])
      expect(cli.environment_for("ronin"))
        .to eq("BENCH_EXE" => "ronin", "BENCH_ARGS" => "help", "BENCH_READYFILE" => "readyfile",
               "BENCH_RUNS" => "5", "BENCH_WARMUPS" => "1")
    end

    it "routes results to a file only when plotting" do
      cli.option_parser.parse(["--plot"])
      expect(cli.environment_for(nil).keys).to eq(["BENCH_RESULTS"])
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
