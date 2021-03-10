--[[

File l3build-help.lua Copyright (C) 2028-2020 The LaTeX Project

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

local append = table.insert
local match  = string.match
local rep    = string.rep
local sort   = table.sort

---@type utlib_t
local utlib       = require("l3b-utillib")
local entries     = utlib.entries
local keys        = utlib.keys
local extend_with = utlib.extend_with

local function version()
  print(
    "\n" ..
    "l3build: A testing and building system for LaTeX\n\n" ..
    "Release " .. release_date .. "\n" ..
    "Copyright (C) 2014-2020 The LaTeX Project"
  )
end

local function help()
  local scriptname = "l3build"
  if not (arg[0]:match("l3build%.lua$") or match(arg[0],"l3build$")) then
    scriptname = arg[0]
  end
  print("usage: " .. scriptname .. " <target> [<options>] [<names>]")
  print("")
  print("Valid targets are:")
  local width = 0
  local get_all_info = require("l3b-targets").get_all_info
  for info in get_all_info() do
    if #info.name > width then
      width = #info.name
    end
  end
  for info in get_all_info() do
    local filler = rep(" ", width - #info.name + 1)
    print("   " .. info.name .. filler .. info.description)
  end
  print("")
  print("Valid options are:")
  width = 0
  get_all_info = require("l3b-options").get_all_info
  for info in get_all_info() do
    if #info.long > width then
      width = #info.long
    end
  end
  for info in get_all_info() do
    local filler = rep(" ", width - #info.long + 1)
    if info.short then
      print("   --" .. info.long .. "|-" .. info.short .. filler .. info.description)
    else
      print("   --" .. info.long .. "   " .. filler .. info.description)
    end
  end
  print("")
  print("Full manual available via 'texdoc l3build'.")
  print("")
  print("Repository  : https://github.com/latex3/l3build")
  print("Bug tracker : https://github.com/latex3/l3build/issues")
  print("Copyright (C) 2014-2020 The LaTeX Project")
end

---@class l3b_help_t
---@field version fun()
---@field help    fun()

return {
  version = version,
  help = help,
}
