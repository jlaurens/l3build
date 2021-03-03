--[[

File l3build-clean.lua Copyright (C) 2028-2020 The LaTeX Project

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

---@type utlib_t
local utlib         = require("l3b.utillib")
local entries       = utlib.entries
local keys          = utlib.keys
local unique_items  = utlib.unique_items
local extend_with   = utlib.extend_with

---@type fslib_t
local fslib                 = require("l3b.fslib")
local make_directory        = fslib.make_directory
local tree                  = fslib.tree
local remove_tree           = fslib.remove_tree
local make_clean_directory  = fslib.make_clean_directory
local remove_directory      = fslib.remove_directory

---@type l3b_vars_t
local l3b_vars  = require("l3b.variables")
local Dir       = l3b_vars.Dir

---@type l3b_aux_t
local l3b_aux = require("l3b.aux")
local call    = l3b_aux.call

-- Remove all generated files
local function clean()
  -- To make sure that Dir.distrib never contains any stray subdirs,
  -- it is entirely removed then recreated rather than simply deleting
  -- all of the files
  local error_level = remove_directory(Dir.distrib)
                    + make_directory(Dir.distrib)
                    + make_clean_directory(Dir[l3b_vars.LOCAL])
                    + make_clean_directory(Dir.test)
                    + make_clean_directory(Dir.typeset)
                    + make_clean_directory(Dir.unpack)

  if error_level ~= 0 then return error_level end

  local clean_list = {}
  for dir in unique_items(Dir.main, Dir.sourcefile, Dir.docfile) do
    for glob in entries(cleanfiles) do
      for file in keys(tree(dir, glob)) do
        clean_list[file] = true
      end
    end
    for glob in entries(sourcefiles) do
      for file in keys(tree(dir, glob)) do
        clean_list[file] = nil
      end
    end
    for file in keys(clean_list) do
      error_level = remove_tree(dir, file)
      if error_level ~= 0 then return error_level end
    end
  end
  return 0
end

local function bundle_clean()
  local error_level = call(modules, "clean")
  for g in entries(cleanfiles) do
    error_level = error_level + remove_tree(Dir.current, g)
  end
  return  error_level
        + remove_directory(Dir.ctan)
        + remove_directory(Dir.tds)
end

-- this is the map to export function symbols to the global space
local global_symbol_map = {
  clean       = clean,
  bundleclean = bundle_clean,
}

--[=[ Export function symbols ]=]
extend_with(_G, global_symbol_map)
-- [=[ ]=]

---@class l3b_clean_t
---@field clean         fun(): integer
---@field bundle_clean  fun(): integer

return {
  global_symbol_map = global_symbol_map,
  clean             = clean,
  bundle_clean      = bundle_clean,
}
