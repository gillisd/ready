require "zeitwerk"
require "pathname"
require "shellwords"

##
# Top-level namespace for the ready gem.
module Ready
  LOADER = Zeitwerk::Loader.for_gem
  LOADER.inflector.inflect("cli" => "CLI")
  LOADER.setup

  ##
  # Base error class for ready.
  class Error < StandardError; end

  ##
  # The root directory of the ready gem (the parent of `lib/`). Used to locate
  # bundled assets such as the zsh plugin and the Rakefile.
  #
  # @return [Pathname]
  def self.root
    Pathname(__dir__).parent
  end
end
