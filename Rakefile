# Everything below develops the ready gem itself (gem build/release, specs,
# rubocop, benchmarks) and depends on dev-only gems. None of it is needed to RUN
# ready: the runtime `ready`/`compile`/`clobber`/`ready:*` tasks live in
# rakelib/ready.rake, which rake auto-loads independently of this file. When
# ready runs as an installed gem the gemspec and dev gems are absent, so loading
# this file would crash `ready up|compile|clobber` (e.g. bundler/gem_tasks
# raising "Unable to determine name from existing gemspec"). Load the dev tasks
# only in a source checkout, detected by the gemspec's presence.
return unless (Pathname(__dir__) / "ready.gemspec").exist?

require "bundler/gem_tasks"

require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

namespace :spec do
  desc "Run the end-to-end (:e2e) specs (needs zsh + by/by-server)"
  task :e2e do
    ok = system({ "READY_E2E" => "1" }, RbConfig.ruby, "-S", "rspec", "--tag", "e2e")
    abort("e2e specs failed") unless ok
  end
end

def bench_protocol
  Ready::Bench::Protocol.new(
    executable_name: ENV.fetch("BENCH_EXE", "ri"),
    library: ENV.fetch("BENCH_LIB", "rdoc"),
    arguments: ENV.fetch("BENCH_ARGS", "TCPServer").split,
    rounds: Integer(ENV.fetch("BENCH_RUNS", "15")),
    warmups: Integer(ENV.fetch("BENCH_WARMUPS", "3")),
  )
end

def bench_runner
  require "ready"
  require "zeitwerk"
  Zeitwerk::Loader.new.tap do |loader|
    loader.inflector.inflect("cli" => "CLI")
    loader.push_dir(Pathname(__dir__) / "spec/support", namespace: Ready)
    loader.setup
  end
  Ready::Bench::Runner.new(protocol: bench_protocol)
end

desc "Print the cold-vs-hot startup waterfall (needs zsh + by-server + rbenv). " \
     "Choose the target with BENCH_EXE=<executable> BENCH_LIB=<library> BENCH_ARGS=<arguments>."
task :bench do
  bench_runner.call.render
end

namespace :bench do
  desc "rake bench plus a legend table explaining every span row"
  task :verbose do
    bench_runner.call.render(verbose: true)
  end
end

require "rubocop/rake_task"
RuboCop::RakeTask.new

require "gempilot/version_task"
Gempilot::VersionTask.new

namespace :zeitwerk do
  desc "Verify all files follow Zeitwerk naming conventions"
  task :validate do
    ruby "-e", <<~RUBY
      require 'ready'
      Ready::LOADER.eager_load(force: true)
      puts 'Zeitwerk: All files loaded successfully.'
    RUBY
  end
end

task default: [:spec, :rubocop]
