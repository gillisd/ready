RSpec.describe Ready::Bench::ColdArm do
  it "injects marks into a rubygems-stub copy at the standard boundaries" do
    src = <<~RUBY
      #!/usr/bin/ruby
      require 'rubygems'
      Gem.use_gemdeps
      version = ">= 0.a"
      if Gem.respond_to?(:activate_and_load_bin_path)
        Gem.activate_and_load_bin_path('irb', 'irb', version)
      else
        load Gem.activate_bin_path('irb', 'irb', version)
      end
    RUBY
    out = described_class.instrument_stub(src)
    aggregate_failures do
      expect(out).to match(/at_exit \{ __bmark\("ruby_exit"\) \}/)
      expect(out).to match(/Gem\.use_gemdeps\n__bmark\('rubygems_ready'\)/)
      expect(out).to include("__bmark('dep_activated')")
      expect(out).to include("__bmark('bin_path_resolved')")
      expect(out).to include("Gem.activate_bin_path('irb', 'irb', version)")
      expect(out).not_to match(/^\s*Gem\.activate_and_load_bin_path\(/) # the call is rewritten
      expect(out).to match(/load __bp/)
    end
  end
end
