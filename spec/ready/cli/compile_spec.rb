require "stringio"

RSpec.describe Ready::CLI::Compile do
  def run_compile(*argv)
    stdout = StringIO.new
    stderr = StringIO.new
    status = described_class.main(argv, stdout: stdout, stderr: stderr)
    [stdout.string, status]
  end

  it "prints the by alias for `by`" do
    output, status = run_compile("by")
    expect(status).to eq(0)
    expect(output).to include("--disable-gems")
  end

  it "keeps rubygems for `by --rubygems`" do
    output, = run_compile("by", "--rubygems")
    expect(output).not_to include("--disable-gems")
  end

  it "enables yjit for `by --yjit`" do
    output, = run_compile("by", "--yjit")
    expect(output).to include("--yjit")
  end

  it "exits non-zero when given no arguments" do
    _output, status = run_compile
    expect(status).to eq(1)
  end
end
