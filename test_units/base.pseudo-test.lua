#!/usr/bin/env texlua

-- the purpose is to launch the test either from the main directory
-- or the testunits directory (or any directory below)

l3b = {}

l3b.search_path = function(name)
  print(name)
end



print("DONE")