require "stringio"

RSpec.describe Ready::Bench::Progress do
  subject(:progress) { described_class.new(command: "ri TCPServer", io:) }

  let(:io) { StringIO.new }

  before do
    progress.building
    progress.warming_up(3)
    3.times { progress.tick }
    progress.measuring(4)
    4.times { progress.tick }
    progress.done
  end

  it "narrates the build, then warmup and measured phases separately", :aggregate_failures do
    expect(io.string).to include("ri TCPServer: building sandbox")
    expect(io.string).to include("ri TCPServer: warming up (3 rounds) ...")
    expect(io.string).to include("ri TCPServer: measuring 4 rounds ....")
    expect(io.string).to end_with(" done\n")
  end

  it "keeps the measured count as the user asked, not measured + warmup" do
    expect(io.string).not_to include("7 rounds")
  end
end
