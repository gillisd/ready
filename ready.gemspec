require_relative "lib/ready/version"

Gem::Specification.new do |spec|
  spec.name = "ready"
  spec.version = Ready::VERSION
  spec.authors = ["David Gillis"]
  spec.email = ["david@flipmine.com"]
  spec.summary = "A new Ruby gem"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.4.7"

  gemspec_file = File.basename(__FILE__)
  files = IO.popen(["git", "ls-files", "-z"], chdir: __dir__, err: IO::NULL) { |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec_file) ||
        f.start_with?("bin/", "test/", "spec/", "features/", ".git", "Gemfile")
    end
  }
  files = Dir.glob("{lib,exe}/**/*").push("README.md", "LICENSE.txt", "Rakefile") if files.empty?
  spec.files = files
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "by", "~> 1.1"
  spec.add_dependency "command_kit", "~> 0.6"
  spec.add_dependency "zeitwerk"
  spec.metadata["rubygems_mfa_required"] = "true"
end
