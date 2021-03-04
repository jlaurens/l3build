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
local deps_install = l3b_aux.deps_install

---@type utlib_t
local utlib   = require("l3b.utillib")
local chooser = utlib.chooser
local entries = utlib.entries
local keys    = utlib.keys

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

---@type l3build_t
local l3build = require("l3build")

---@type l3b_vars_t
local l3b_vars  = require("l3b.variables")
---@type Dir_t
local Dir       = l3b_vars.Dir
---@type Files_t
local Files     = l3b_vars.Files
---@type Deps_t
local Deps      = l3b_vars.Deps
---@type Exe_t
local Exe       = l3b_vars.Exe
---@type Opts_t
local Opts      = l3b_vars.Opts

---@class l3b_unpack_vars_t
---@field unpacksearch boolean

---@type l3b_unpack_vars_t
local Vars = chooser(_G, {
  -- Enable access to trees outside of the repo
  -- As these may be set false, a more elaborate test than normal is needed
  unpacksearch = true
})
---@alias bundleunpack_f fun(source_dirs: string_list_t, sources: string_list_t): integer

---Split off from the main unpack so it can be used on a bundle and not
---leave only one modules files
---@param source_dirs string_list_t
---@param sources string_list_t
---@return integer
local function bundleunpack(source_dirs, sources)
  local options = l3build.options
  local error_level = make_directory(Dir[l3b_vars.LOCAL])
  if error_level ~=0 then
    return error_level
  end
  error_level = make_clean_directory(Dir.unpack)
  if error_level ~=0 then
    return error_level
  end
  for i in entries(source_dirs or { Dir.sourcefile }) do
    for j in entries(sources or { Files.source }) do
      for k in entries(j) do
        error_level = copy_tree(k, i, Dir.unpack)
        if error_level ~=0 then
          return error_level
        end
      end
    end
  end
  for i in entries(Files.unpacksupp) do
    error_level = copy_tree(i, Dir.support, Dir[l3b_vars.LOCAL])
    if error_level ~=0 then
      return error_level
    end
  end
  for i in entries(Files.unpack) do
    for j in keys(tree(Dir.unpack, i)) do
      local dir_path, base_name = dir_base(j)
      local local_dir = absolute_path(Dir[l3b_vars.LOCAL])
      local success = io.popen(cmd_concat(
          "cd " .. Dir.unpack .. "/" .. dir_path,
          os_setenv .. " TEXINPUTS=." .. os_pathsep
            .. local_dir .. (Vars.unpacksearch and os_pathsep or ""),
          os_setenv .. " LUAINPUTS=." .. os_pathsep
            .. local_dir .. (Vars.unpacksearch and os_pathsep or ""),
          Exe.unpack .. " " .. Opts.unpack .. " " .. base_name
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
---@param sources     string_list_t
---@param source_dirs string_list_t
---@return integer
local function unpack(sources, source_dirs)
  local error_level = deps_install(Deps.unpack)
  if error_level ~= 0 then
    return error_level
  end
  ---@type bundleunpack_f
  local unpacker = _G.bundleunpack or bundleunpack
  error_level = unpacker(source_dirs, sources)
  if error_level ~= 0 then
    return error_level
  end
  for g in entries(Files.install) do
    error_level = copy_tree(g, Dir.unpack, Dir[l3b_vars.LOCAL])
    if error_level ~= 0 then
      return error_level
    end
  end
  return 0
end

---@class l3b_unpack_t
---@field bundleunpack  bundleunpack_f
---@field unpack        bundleunpack_f

return {
  unpack            = unpack,
  bundleunpack      = bundleunpack,
}
