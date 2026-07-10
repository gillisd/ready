require "stringio"
require "pathname"

module Ready
  ##
  # Resolves an executable name (gem-provided or on-disk) to a concrete path
  # and renders its source with a process title prelude.
  class Executable
    attr_reader :name, :is_gem

    def initialize(name)
      @name = name
      @is_gem = !File.exist?(name)
    end

    def convert_path_to_bin(path)
      pathname = Pathname(path)
      if /bin/.match?(pathname.dirname.to_s)
        "bin/#{pathname.basename}"
      else
        pathname.basename
      end
    end

    def render
      stream = StringIO.new
      stream.puts
      stream.puts(
        <<~RUBY,
          Process.setproctitle #{name.inspect}
        RUBY
      )
      stream.puts(source)
      stream.string
    end

    def path
      unless @is_gem
        if @name.to_s.include? "exe"
          @path ||= @name
          @name = @name.split("/").last
          return @path
        end
        @path ||= convert_path_to_bin(@name)
        return @path
      end

      return Gem.bin_path("bundler", "bundle") if @name == "bundle"
      return Gem.bin_path("rdoc", "ri") if @name == "ri"
      return Gem.bin_path("yard", "yri") if @name == "yri"
      return Gem.bin_path("reversal-store", "rstore") if @name == "rstore"
      return Gem.bin_path("rouge", "rougify") if @name == "rougify"
      return `rbenv which gem`.chomp if @name == "gem"

      @path ||= @is_gem ? gem_path : system_path
      @path
    end

    def source
      raise "No executable found for '#{@name}'" if path.nil?

      clean = File.read(path)
                  &.gsub(/^.*#!.*\n/, "")
                  &.strip
                  &.then { StringIO.new it }

      @source ||= if clean.string.include?("require_relative")
                    string = clean.string
                    matches = string.scan(/(require_relative(?:\(| )\s*[\x27"]([^\s\x27"]+)[\x27"]\)?)/)
                    matches.each do |match, relpath|
                      absolute_path = File.expand_path(relpath, File.dirname(path))
                      replacement = match.dup
                      replacement.gsub!("require_relative", "require")
                      replacement.gsub!(relpath, absolute_path)
                      string.gsub!(match, replacement)
                    end
                    string
                  else
                    clean.string
                  end
    end

    private

    def gem_path
      Gem.bin_path(@name, @name)
    end

    def system_path
      rbenv_path = `rbenv which #{@name} 2>/dev/null`.strip
      rbenv_path.empty? ? nil : rbenv_path
    end
  end
end
