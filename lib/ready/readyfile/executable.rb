##
# A single executable declared in a readyfile, mapping its name to the
# compiled path under the build directory.
class Ready::Readyfile::Executable
  attr_reader :name, :prefix, :build_dir

  def initialize(name, build_dir:, prefix: "ready_")
    @name = name
    @prefix = prefix
    @build_dir = Pathname(build_dir)

    validate!
  end

  def mapping
    { name => realpath }
  end

  def ready_name
    prefix + name
  end

  def realpath
    build_dir / ready_name
  end

  private

  def validate!
    validate_name!
    validate_build_dir!
  end

  def validate_name!
    raise ArgumentError, "Name cannot be nil" if name.nil?
    raise ArgumentError, "Name cannot be empty" if name.empty?
  end

  def validate_build_dir!
    raise ArgumentError, "build_dir cannot be nil for executable #{name.inspect}" if build_dir.nil?
    return if build_dir.directory?

    raise ArgumentError,
          "build_dir #{build_dir.inspect} must exist for executable #{name.inspect}"
  end
end
