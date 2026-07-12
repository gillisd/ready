require "tmpdir"
require "fileutils"
require "rbconfig"

# Regression: run as an installed gem, `ready up|compile|clobber` load the
# shipped Rakefile from a directory with no gemspec. The dev-only tooling it
# requires (bundler/gem_tasks, rspec, rubocop, gempilot) must NOT load there, or
# bundler/gem_tasks aborts with "Unable to determine name from existing gemspec".
RSpec.describe "Rakefile runtime safety" do
  # Load only the Rakefile (no gemspec, no dev gems), as an installed gem would.
  def rake_output(dir)
    IO.popen(
      { "BUNDLE_GEMFILE" => nil, "RUBYOPT" => nil },
      [RbConfig.ruby, Gem.bin_path("rake", "rake"), "-f", (Pathname(dir) / "Rakefile").to_s, "--tasks"],
      chdir: dir, err: %i[child out], &:read
    )
  end

  it "loads without dev tooling when no gemspec is present (installed-gem layout)" do
    Dir.mktmpdir do |dir|
      FileUtils.cp(Ready.root / "Rakefile", dir)

      expect(rake_output(dir)).not_to include("Unable to determine name from existing gemspec")
    end
  end
end
