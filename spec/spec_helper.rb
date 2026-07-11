require "ready"
require "zeitwerk"

# Autoload the e2e/benchmark harness the Zeitwerk way, into the Ready namespace
# (spec/support/pty_shell.rb -> Ready::PtyShell, support/bench/marks.rb ->
# Ready::Bench::Marks, ...). A second loader may share a namespace owned by the
# gem's for_gem loader.
Zeitwerk::Loader.new.tap do |loader|
  loader.push_dir(File.expand_path("support", __dir__), namespace: Ready)
  loader.setup
end

RSpec.configure do |config|
  config.example_status_persistence_file_path = ".rspec_status"
  config.disable_monkey_patching!

  # E2E specs need zsh + a real ~10s+ readyup build; keep them out of the fast
  # loop unless explicitly opted in (the `spec:e2e` rake task sets READY_E2E).
  config.filter_run_excluding :e2e unless ENV["READY_E2E"]

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
