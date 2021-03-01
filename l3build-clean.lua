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

---@type fslib_t
local fslib                 = require("l3b.fslib")
local make_directory        = fslib.make_directory
local tree                  = fslib.tree
local remove_tree           = fslib.remove_tree
local make_clean_directory  = fslib.make_clean_directory
local remove_directory      = fslib.remove_directory

-- Remove all generated files
local function clean()
  -- To make sure that distribdir never contains any stray subdirs,
  -- it is entirely removed then recreated rather than simply deleting
  -- all of the files
  local errorlevel =
    remove_directory(distribdir)    +
    make_directory(distribdir)    +
    make_clean_directory(localdir)   +
    make_clean_directory(testdir)    +
    make_clean_directory(typesetdir) +
    make_clean_directory(unpackdir)

  if errorlevel ~= 0 then return errorlevel end

  local clean_list = {}
  for dir in unique_items(maindir, sourcefiledir, docfiledir) do
    for glob in entries(cleanfiles) do
      for file in keys(tree(dir,glob)) do
        clean_list[file] = true
      end
    end
    for glob in entries(sourcefiles) do
      for file in keys(tree(dir,glob)) do
        clean_list[file] = nil
      end
    end
    for file in keys(clean_list) do
      errorlevel = remove_tree(dir,file)
      if errorlevel ~= 0 then return errorlevel end
    end
  end

  return 0
end

local function bundle_clean()
  local errorlevel = call(modules, "clean")
  for i in entries(cleanfiles) do
    errorlevel = remove_tree(currentdir, i) + errorlevel
  end
  return (
    errorlevel     +
    remove_directory(ctandir) +
    remove_directory(tdsdir)
  )
end

-- this is the map to export function symbols to the global space
local global_symbol_map = {
  clean       = clean,
  bundleclean = bundle_clean,
}

--[=[ Export function symbols ]=]
extend_with(_G, global_symbol_map)
-- [=[ ]=]

---@class clean_t
---@field clean function
---@field bundle_clean function

return {
  global_symbol_map = global_symbol_map
  clean = clean,
  bundle_clean = bundle_clean,
}
