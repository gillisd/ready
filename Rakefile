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

desc "Print the cold-vs-hot startup waterfall (needs zsh + by-server; rbenv optional). BENCH_EXE/BENCH_LIB override the target."
task :bench do
  require "ready"
  require "zeitwerk"
  Zeitwerk::Loader.new.tap { |l| l.push_dir(File.expand_path("spec/support", __dir__), namespace: Ready); l.setup }
  Ready::Bench::Runner.new(
    exe: ENV.fetch("BENCH_EXE", "irb"),
    lib: ENV.fetch("BENCH_LIB", "irb"),
    runs: Integer(ENV.fetch("BENCH_RUNS", "15")),
    warmups: Integer(ENV.fetch("BENCH_WARMUPS", "3")),
  ).call.render
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
