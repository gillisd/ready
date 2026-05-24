require "zeitwerk"

##
# Top-level namespace for the ready gem.
module Ready
  LOADER = Zeitwerk::Loader.for_gem
  LOADER.setup

  ##
  # Base error class for ready.
  class Error < StandardError; end
end
