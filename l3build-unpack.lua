--[[

File l3build-unpack.lua Copyright (C) 2018-2020 The LaTeX Project

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

---@type l3b_aux_t
local l3b_aux = require("l3b.aux")
local dep_install = l3b_aux.dep_install

---@type utlib_t
local utlib = require("l3b.utillib")
local entries = utlib.entries
local keys = utlib.keys

---@type wklib_t
local wklib             = require("l3b.walklib")
local dir_base          = wklib.dir_base

---@type oslib_t
local oslib             = require("l3b.oslib")
local cmd_concat        = oslib.cmd_concat

---@type fslib_t
local fslib                 = require("l3b.fslib")
local copy_tree             = fslib.copy_tree
local make_directory        = fslib.make_directory
local make_clean_directory  = fslib.make_clean_directory
local tree                  = fslib.tree
local absolute_path         = fslib.absolute_path

---@alias bundleunpack_t fun(source_dirs: table<integer, string>, sources: table<integer, string>): integer

---Split off from the main unpack so it can be used on a bundle and not
---leave only one modules files
---@param source_dirs table<integer, string>
---@param sources table<integer, string>
---@return integer
local function bundleunpack(source_dirs, sources)
  local error_level = make_directory(localdir)
  if error_level ~=0 then
    return error_level
  end
  error_level = make_clean_directory(unpackdir)
  if error_level ~=0 then
    return error_level
  end
  for i in entries(source_dirs or { sourcefiledir }) do
    for j in entries(sources or { sourcefiles }) do
      for k in entries(j) do
        error_level = copy_tree(k, i, unpackdir)
        if error_level ~=0 then
          return error_level
        end
      end
    end
  end
  for i in entries(unpacksuppfiles) do
    error_level = copy_tree(i, supportdir, localdir)
    if error_level ~=0 then
      return error_level
    end
  end
  for i in entries(unpackfiles) do
    for j in keys(tree(unpackdir, i)) do
      local dir_path, base_name = dir_base(j)
      local localdir = absolute_path(localdir)
      local success = io.popen(cmd_concat(
          "cd " .. unpackdir .. "/" .. dir_path,
          os_setenv .. " TEXINPUTS=." .. os_pathsep
            .. localdir .. (unpacksearch and os_pathsep or ""),
          os_setenv .. " LUAINPUTS=." .. os_pathsep
            .. localdir .. (unpacksearch and os_pathsep or ""),
          unpackexe .. " " .. unpackopts .. " " .. base_name
            .. (options["quiet"] and (" > " .. os_null) or "")
        ), "w"
      ):write(string.rep("y\n", 300)):close()
      if not success then
        return 1
      end
    end
  end
  return 0
end

---Unpack the package files using an 'isolated' system: this requires
---a copy of the 'basic' DocStrip program, which is used then removed
---@param sources table<integer, string>
---@param source_dirs  table<integer, string>
---@return integer
local function unpack(sources, source_dirs)
  local error_level = dep_install(unpackdeps)
  if error_level ~= 0 then
    return error_level
  end
  ---@type bundleunpack_t
  local unpacker = _G.bundleunpack or bundleunpack
  error_level = unpacker(source_dirs, sources)
  if error_level ~= 0 then
    return error_level
  end
  for g in entries(installfiles) do
    error_level = copy_tree(g, unpackdir, localdir)
    if error_level ~= 0 then
      return error_level
    end
  end
  return 0
end

---@class l3b_unpack_t
---@field bundleunpack bundleunpack_t
---@field unpack bundleunpack_t

return {
  global_symbol_map = {},
  unpack = unpack,
  bundleunpack = bundleunpack,
}
