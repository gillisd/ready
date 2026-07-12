require "stringio"

RSpec.describe Ready::Bench::Progress do
  subject(:progress) { described_class.new(command: "ri TCPServer", io:) }

  let(:io) { StringIO.new }

  before do
    progress.building
    progress.running(3)
    3.times { progress.tick }
    progress.done
  end

  it "narrates the build and one dot per round", :aggregate_failures do
    expect(io.string).to include("ri TCPServer: building sandbox")
    expect(io.string).to include("ri TCPServer: running 3 rounds ...")
    expect(io.string).to end_with(" done\n")
  end
end
