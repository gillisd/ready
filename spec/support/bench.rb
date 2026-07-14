module Ready
  ##
  # The cold-vs-hot startup benchmark. Entities live under bench/; this file
  # holds the namespace-level helpers they share.
  module Bench
    # Evaluated by constructors that let rbenv default. The cold arm cannot
    # resolve rubygems stubs without rbenv, so a missing rbenv fails fast at
    # construction rather than deep inside the first round.
    def self.rbenv_available?
      system("command -v rbenv >/dev/null 2>&1", exception: true)
    end
  end
end
