require "stringio"

module Ready
  ##
  # Resolves an executable name (gem-provided or on-disk) to a concrete path
  # and renders its source with a process title prelude.
  class Executable
    attr_reader :name, :is_gem

    # Executables whose gem name differs from the command, so `path` isn't a
    # wall of one-off special cases.
    GEM_BIN_OVERRIDES = {
      "bundle" => %w[bundler bundle],
      "ri" => %w[rdoc ri],
      "yri" => %w[yard yri],
      "rstore" => %w[reversal-store rstore],
      "rougify" => %w[rouge rougify],
    }.freeze

    SHEBANG_LINE = /^.*#!.*\n/
    REQUIRE_RELATIVE = /(require_relative(?:\(| )\s*[\x27"]([^\s\x27"]+)[\x27"]\)?)/

    def initialize(name)
      @name = name
      @is_gem = !File.exist?(name)
    end

    # "bin/<name>" when the executable sits directly in a bin directory, else
    # the bare basename. Anchored on the parent directory's name so a path like
    # /home/robin/foo doesn't match "bin" as a substring.
    def convert_path_to_bin(path)
      pathname = Pathname(path)
      pathname.dirname.basename.to_s == "bin" ? "bin/#{pathname.basename}" : pathname.basename
    end

    def render
      stream = StringIO.new
      stream.puts
      stream.puts(prologue)
      stream.puts(source)
      stream.string
    end

    # Runs before the dispatched CLI. Besides the process title, it disables
    # the test/unit auto-runner: when the persistent server has test/unit
    # loaded, its at_exit runner parses the process ARGV, so any option the CLI
    # leaves there is rejected ("invalid option: --foo"). A dispatched CLI is
    # never a test run, so switch the runner off.
    def prologue
      <<~RUBY
        Test::Unit::AutoRunner.need_auto_run = false if defined?(Test::Unit::AutoRunner)
        Process.setproctitle #{name.inspect}
      RUBY
    end

    def path
      @path ||= @is_gem ? gem_executable_path : on_disk_path
    end

    def source
      raise "No executable found for '#{@name}'" if path.nil?

      @source ||= rewrite_require_relative(File.read(path).gsub(SHEBANG_LINE, "").strip)
    end

    private

    def on_disk_path
      if @name.to_s.include?("exe")
        resolved = @name
        @name = @name.split("/").last
        return resolved
      end
      convert_path_to_bin(@name)
    end

    def gem_executable_path
      override = GEM_BIN_OVERRIDES[@name]
      return Gem.bin_path(*override) if override
      return `rbenv which gem`.chomp if @name == "gem"

      gem_path
    end

    # Rewrites `require_relative "x"` to an absolute `require`, so the source
    # can be eval'd by the persistent server outside its original directory.
    def rewrite_require_relative(code)
      return code unless code.include?("require_relative")

      code.scan(REQUIRE_RELATIVE).each do |statement, relpath|
        absolute = (Pathname(path).dirname / relpath).expand_path.to_s
        rewritten = statement.gsub("require_relative", "require").gsub(relpath, absolute)
        code = code.gsub(statement, rewritten)
      end
      code
    end

    def gem_path
      Gem.bin_path(@name, @name)
    end
  end
end
