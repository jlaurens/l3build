local l3build = require "l3build"
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
local utlib         = require("l3b-utillib")
local entries       = utlib.entries
local keys          = utlib.keys
local unique_items  = utlib.unique_items

---@type fslib_t
local fslib                 = require("l3b-fslib")
local make_directory        = fslib.make_directory
local tree                  = fslib.tree
local remove_tree           = fslib.remove_tree
local make_clean_directory  = fslib.make_clean_directory
local remove_directory      = fslib.remove_directory

---@type l3b_globals_t
local l3b_globals  = require("l3build-globals")
---@type G_t
local G      = l3b_globals.G
---@type Dir_t
local Dir       = l3b_globals.Dir
---@type Files_t
local Files     = l3b_globals.Files

---@type l3b_aux_t
local l3b_aux = require("l3build-aux")
local call    = l3b_aux.call

---@type l3b_check_t
local l3b_check = require("l3build-check")
local load_unique_config = l3b_check.load_unique_config

---Remove all generated files
---@return error_level_n
local function clean()
  -- To make sure that Dir.distrib never contains any stray subdirs,
  -- it is entirely removed then recreated rather than simply deleting
  -- all of the files
  local error_level = remove_directory(Dir.distrib)
                    + make_directory(Dir.distrib)
                    + make_clean_directory(Dir[l3b_globals.LOCAL])
                    + make_clean_directory(Dir.test)
                    + make_clean_directory(Dir.typeset)
                    + make_clean_directory(Dir.unpack)
  if error_level ~= 0 then
    return error_level
  end
  if l3build.options.debug then
    print("DEBUG clean:")
    print("- remove and make directory at ".. Dir.distrib)
    print("- make clean directory at ".. Dir[l3b_globals.LOCAL])
    print("- make clean directory at ".. Dir.test)
    print("- make clean directory at ".. Dir.typeset)
    print("- make clean directory at ".. Dir.unpack)
  end
  ---@type flag_table_t
  local clean_list = {}
  for dir in unique_items(Dir.main, Dir.sourcefile, Dir.docfile) do
    for glob in entries(Files.clean) do
      for p in tree(dir, glob) do
        clean_list[p.src] = true
      end
    end
    for glob in entries(Files.source) do
      for p in tree(dir, glob) do
        clean_list[p.src] = nil
      end
    end
    for p_src in keys(clean_list) do
      error_level = remove_tree(dir, p_src)
      if error_level ~= 0 then
        return error_level
      end
    end
  end
  return 0
end

---Run before the clean operation
---@param options options_t
---@return error_level_n
local function configure_clean(options)
  return load_unique_config(options)
end


local function bundle_clean()
  local error_level = call(G.modules, "clean")
  for g in entries(Files.clean) do
    error_level = error_level + remove_tree(Dir.work, g)
  end
  return  error_level
        + remove_directory(Dir.ctan)
        + remove_directory(Dir.tds)
end

---@class l3b_clean_t
---@field clean_impl  target_impl_t

return {
  clean_impl  = {
    run         = clean,
    configure   = configure_clean,
    bundle_run  = bundle_clean,
  }
}
