RSpec.describe Ready::Bench::HotArm do
  it "prepends a server_entry mark and injects pre_tool before the tool start" do
    rendered = <<~RUBY
      Process.setproctitle "irb"
      require 'irb'
      IRB.start(__FILE__)
    RUBY
    out = described_class.instrument_source(rendered)
    aggregate_failures do
      expect(out.index("server_entry")).to be < out.index("setproctitle")
      expect(out).to match(/pre_tool.*\n\s*IRB\.start/m)
    end
  end
end
