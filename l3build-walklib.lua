--[[

File l3build-walklib.lua Copyright (C) 2018-2020 The LaTeX Project

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

--[=[ Usage:
---@type wklib_t
local wklib     = require("l3b.walklib")
local dir_base  = wklib.dir_base
local base_name = wklib.base_name
local dir_name  = wklib.dir_name
local job_name  = wklib.job_name
--]=]

local match            = string.match

---@type utlib_t
local utlib       = require("l3b.utillib")
local first_of    = utlib.first_of
local second_of   = utlib.second_of
local extend_with = utlib.extend_with


---Split a path into its base and directory components.
---The base part includes the file extension if any.
---The dir part does not contain the trailing '/'.
---@param path string
---@return string dir is the part before the last '/' if any, "." otherwise.
---@return string
local function dir_base(path)
  local dir, base = match(path, "^(.*)/([^/]*)$")
  if dir then
    return dir, base
  else
    return ".", path
  end
end

-- Arguably clearer names
local function base_name(file)
  return second_of(dir_base(file))
end

local function dir_name(file)
  return first_of(dir_base(file))
end

-- Strip the extension from a file name (if present)
local function job_name(file)
  local name = match(base_name(file), "^(.*)%.")
  return name or file
end

-- this is the map to export function symbols to the global space
local global_symbol_map = {
  splitpath = dir_base,
  basename = base_name,
  dirname = dir_name,
  jobname = job_name,
}

--[=[ Export function symbols ]=]
extend_with(_G, global_symbol_map)
-- [=[ ]=]

---@class wklib_t
---@field dir_base function
---@field dir_name function
---@field base_name function
---@field job_name function

return {
  global_symbol_map = global_symbol_map,
  dir_base = dir_base,
  dir_name = dir_name,
  base_name = base_name,
  job_name = job_name,
}