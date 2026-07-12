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
  executable = ENV.fetch("BENCH_EXE", "ri")
  # TCPServer is the default workload for the default tool only; any other
  # executable runs bare unless BENCH_ARGS says otherwise.
  default_arguments = executable == "ri" ? "TCPServer" : ""
  Ready::Bench::Protocol.new(
    executable_name: executable,
    arguments: ENV.fetch("BENCH_ARGS", default_arguments).split,
    preload_gems: bench_preload_gems,
    rounds: Integer(ENV.fetch("BENCH_RUNS", "15")),
    warmups: Integer(ENV.fetch("BENCH_WARMUPS", "3")),
  )
end

# The hot server preloads the gems a readyfile declares (BENCH_READYFILE),
# falling back to rdoc, which ships the default tool. The build_dir is
# irrelevant here -- only gem names are read -- but Readyfile requires an
# existing directory, so the readyfile's own parent satisfies it.
def bench_preload_gems
  readyfile_path = ENV.fetch("BENCH_READYFILE", nil)
  return ["rdoc"] if readyfile_path.nil?

  readyfile_path = Pathname(readyfile_path)
  Ready::Readyfile.open(readyfile_path, build_dir: readyfile_path.expand_path.parent).gem_names
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

# Appends this run's headline numbers so a caller sequencing several
# benchmarks (bin/bench --plot) can chart them afterwards.
def export_bench_results(runner)
  results_path = ENV.fetch("BENCH_RESULTS", nil)
  return unless results_path

  results = Ready::Bench::ResultsLog.new(results_path)
  results.append(command: runner.invocation, arm: :cold,
                 full_milliseconds: runner.cold_summary.duration_of(:full))
  results.append(command: runner.invocation, arm: :hot,
                 full_milliseconds: runner.hot_summary.duration_of(:full))
end

def run_bench(verbose:)
  runner = bench_runner.call
  runner.render(verbose:)
  export_bench_results(runner)
end

desc "Print the cold-vs-hot startup waterfall (needs zsh + by-server + rbenv); bin/bench is the front door"
task :bench do
  run_bench(verbose: false)
end

namespace :bench do
  desc "rake bench plus a legend table explaining every span row"
  task :verbose do
    run_bench(verbose: true)
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
