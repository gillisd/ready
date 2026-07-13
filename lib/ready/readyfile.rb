require "yaml"

module Ready
  ##
  # Reads the YAML readyfile and exposes the gems and executables it declares.
  class Readyfile
    attr_reader :config, :build_dir, :path

    def self.open(path, build_dir:)
      path = Pathname(path)
      # A missing, empty, or null readyfile is not an error: it simply declares
      # no gems or executables. YAML.parse_file returns false for an empty file,
      # and a document such as "---" parses to nil.
      # YAML.parse_file returns `false` for an empty file (not nil), so guard on
      # truthiness, not with `&.` -- false&.to_ruby would blow up. A "---"
      # document is truthy but to_ruby's to nil, which the `|| {}` folds to empty.
      document = (YAML.parse_file(path.to_s) if path.exist?)
      config = (document ? document.to_ruby : {}) || {}

      unless config.is_a?(Hash)
        raise Error, "#{path}: readyfile must be a YAML mapping of gems:/executables:, got #{config.class}"
      end

      new config, build_dir:, path:
    end

    def initialize(config, build_dir:, path:)
      @path = path
      @config = config
      @build_dir = build_dir
    end

    def to_path
      path
    end

    def to_s
      path.to_s
    end

    def gem_names
      config.fetch("gems", [])
    end

    def executables
      config
        .fetch("executables", [])
        .map { Executable.new it, build_dir: }
    end

    def executable_names
      executables.map(&:name)
    end

    def executable_paths
      executables.map(&:realpath)
    end

    def each_executable_mapping(&)
      return enum_for __method__ unless block_given?

      executables.flat_map(&:mapping).each do |mapping|
        yield(*mapping.to_a)
      end
    end

    def each_executable
      return enum_for __method__ unless block_given?

      executables.each { yield it }
    end
  end
end
