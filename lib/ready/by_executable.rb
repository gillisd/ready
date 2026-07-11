require "shellwords"

module Ready
  ##
  # Builds the ruby invocation used to run the "by" executable, toggling
  # rubygems and YJIT, and renders it as a shell alias.
  class ByExecutable
    def initialize(
      current_ruby: RbConfig.ruby,
      by_bin: Gem.activate_bin_path("by", "by")
    )
      @current_ruby = current_ruby
      @by_bin = by_bin
      @args = []
    end

    def without_rubygems
      @args << "--disable-gems" unless @args.include? "--disable-gems"
      self
    end

    def with_rubygems
      @args.delete "--disable-gems"
      self
    end

    def with_yjit
      @args << "--yjit"
      self
    end

    def without_yjit
      @args.delete("--yjit")
      self
    end

    def command_args
      [
        @current_ruby,
        *@args,
        @by_bin,
      ]
    end

    def to_alias
      command_args
        .then { |it| Shellwords.join(it) }
        .then { |it| "#{it} \"${@}\"" }
    end
  end
end
