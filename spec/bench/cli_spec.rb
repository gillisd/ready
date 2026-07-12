RSpec.describe Ready::Bench::CLI do
  subject(:cli) { described_class.new }

  describe "#environment_for" do
    it "exports nothing by default, deferring every default to the rake task" do
      expect(cli.environment_for(nil, [])).to eq({})
    end

    it "maps the positional executable and arguments" do
      environment = cli.environment_for("ronin", ["help"])
      expect(environment).to eq("BENCH_EXE" => "ronin", "BENCH_ARGS" => "help")
    end

    it "maps the flags onto the BENCH_* contract the rake task reads" do
      cli.option_parser.parse(["--library", "ronin", "--rounds", "5", "--warmups", "1"])
      expect(cli.environment_for(nil, []))
        .to eq("BENCH_LIB" => "ronin", "BENCH_RUNS" => "5", "BENCH_WARMUPS" => "1")
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
