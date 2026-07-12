module Ready
  module Bench
    ##
    # What the benchmark actually tested and how: the executable under test,
    # the library the hot server preloads for it, and the round counts
    # (measured rounds per arm, plus warmups that are recorded but excluded
    # from every reported number).
    Protocol = Data.define(:executable_name, :library, :rounds, :warmups)
  end
end
