RSpec.describe Ready::Bench::RubygemsStub do
  subject(:stub) { described_class.new(source) }

  let(:source) do
    <<~RUBY
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
  end

  let(:instrumented) { stub.instrumented_source }

  it "injects marks at the stub's standard boundaries", :aggregate_failures do
    expect(instrumented).to include(%(at_exit { ready_bench_mark("ruby_exit") }))
    expect(instrumented).to include(%(Gem.use_gemdeps\nready_bench_mark("rubygems_ready")))
    expect(instrumented).to include(%(ready_bench_mark("bin_path_resolved")))
  end

  it "splits activation from executing the tool so each is its own span", :aggregate_failures do
    expect(instrumented).to include("activated_bin_path = Gem.activate_bin_path('irb', 'irb', version)")
    expect(instrumented).not_to include("Gem.activate_and_load_bin_path(")
    expect(instrumented).to include("load activated_bin_path")
  end
end
