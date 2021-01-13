--[[

File l3build-help.lua Copyright (C) 2018,2020 The LaTeX3 Project

It may be distributed and/or modified under the conditions of the
LaTeX Project Public License (LPPL), either version 1.3c of this
license or (at your option) any later version.  The latest version
of this license is in the file

   http://www.latex-project.org/lppl.txt

This file is part of the "l3build bundle" (The Work in LPPL)
and all files in that bundle must be distributed together.

-----------------------------------------------------------------------

The development version of the bundle can be found at

   https://github.com/latex3/l3build

for those people who are interested.

--]]

-- defines global version() and help()

L3 = L3 or {}

L3.version = function (self)
  print([[
l3build: A testing and building system for LaTeX

Release ]] .. self.release_date .. [[
Copyright (C) 2014-2020 The LaTeX3 Project
]])
end

L3.help = function (self)
  local function setup_list(list)
    local longest = 0
    for k,v in pairs(list) do
      if k:len() > longest then
        longest = k:len()
      end
    end
    -- Sort the options
    local t = { }
    for k,_ in pairs(list) do
      t[#t+1] = k
    end
    t:sort()
    return longest,t
  end

  local scriptname = "l3build"
  if not arg[0]:match("l3build%(.lua)?$") then
    scriptname = arg[0]
  end
  print("usage: " .. scriptname .. [[ <target> [<options>] [<names>]

Valid targets are:]])
  local longest,t = setup_list(self.target_list)
  for _,k in ipairs(t) do
    local target = self.target_list[k]
    local filler = string.rep(" ", longest - k:len() + 1)
    if target.desc then
      print("   " .. k .. filler .. target.desc)
    end
  end
  print([[

Valid options are:]])
  local longest,t = setup_list(self.option_list)
  for _,k in ipairs(t) do
    local opt = self.option_list[k]
    local filler = string.rep(" ", longest - k:len() + 1)
    if opt.desc then
      if opt.short then
        print("   --" .. k .. "|-" .. opt.short .. filler .. opt.desc)
      else
        print("   --" .. k .. "   " .. filler .. opt.desc)
      end
    end
  end
  print([[
    
Full manual available via 'texdoc l3build'.

Repository  : https://github.com/latex3/l3build
Bug tracker : https://github.com/latex3/l3build/issues
Copyright (C) 2014-2020 The LaTeX3 Project
]])
end
