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

local popen = io.popen

---@type l3b_aux_t
local l3b_aux       = require("l3build-aux")
local deps_install  = l3b_aux.deps_install

---@type utlib_t
local utlib   = require("l3b-utillib")
local chooser = utlib.chooser
local entries = utlib.entries
local keys    = utlib.keys

---@type wklib_t
local wklib             = require("l3b-walklib")
local dir_base          = wklib.dir_base

---@type oslib_t
local oslib             = require("l3b-oslib")
local cmd_concat        = oslib.cmd_concat
local OS                = oslib.OS

---@type fslib_t
local fslib                 = require("l3b-fslib")
local copy_tree             = fslib.copy_tree
local make_directory        = fslib.make_directory
local make_clean_directory  = fslib.make_clean_directory
local tree                  = fslib.tree
local absolute_path         = fslib.absolute_path

---@type l3build_t
local l3build = require("l3build")

---@type l3b_vars_t
local l3b_vars  = require("l3build-variables")
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

---@alias bundleunpack_f fun(source_dirs: string_list_t, sources: string_list_t): integer

---@class l3b_unpk_vars_t
---@field unpacksearch boolean  Switch to search the system \texttt{texmf} for during unpacking
---@field bundleunpack bundleunpack_f  bundle unpack overwrite

---@type l3b_unpk_vars_t
local Vars_dft = {
  -- Enable access to trees outside of the repo
  -- As these may be set false, a more elaborate test than normal is needed
  unpacksearch = true
}
---@type l3b_unpk_vars_t
local Vars = chooser({
  global = l3build,
  default = Vars_dft
})

---Split off from the main unpack so it can be used on a bundle and not
---leave only one modules files
---@param source_dirs string_list_t|nil defaults to the source directory
---@param sources     string_list_t|nil defaults to the source files glob
---@return error_level_n
function Vars_dft.bundleunpack(source_dirs, sources)
  source_dirs = source_dirs or { Dir.sourcefile }
  sources = sources or { Files.source }
  local options = l3build.options
  local error_level = make_directory(Dir[l3b_vars.LOCAL])
  if error_level ~= 0 then
    return error_level
  end
  error_level = make_clean_directory(Dir.unpack)
  if error_level ~= 0 then
    return error_level
  end
  for src_dir in entries(source_dirs) do
    for globs in entries(sources) do
      for glob in entries(globs) do
        error_level = copy_tree(glob, src_dir, Dir.unpack)
        if error_level ~= 0 then
          return error_level
        end
      end
    end
  end
  for glob in entries(Files.unpacksupp) do
    error_level = copy_tree(glob, Dir.support, Dir[l3b_vars.LOCAL])
    if error_level ~= 0 then
      return error_level
    end
  end
  for glob in entries(Files.unpack) do
    for p in tree(Dir.unpack, glob) do
      local dir_path, base_name = dir_base(p.src)
      local local_dir = absolute_path(Dir[l3b_vars.LOCAL])
      local cmd = cmd_concat(
        "cd " .. Dir.unpack .. "/" .. dir_path,
        OS.setenv .. " TEXINPUTS=." .. OS.pathsep
          .. local_dir .. (Vars.unpacksearch and OS.pathsep or ""),
        OS.setenv .. " LUAINPUTS=." .. OS.pathsep
          .. local_dir .. (Vars.unpacksearch and OS.pathsep or ""),
        Exe.unpack .. " " .. Opts.unpack .. " " .. base_name
          .. (options.quiet and (" > " .. OS.null) or "")
      )
      if l3build.options.debug then
        print("DEBUG: ".. cmd)
      end
      local success = popen(cmd, "w")
        :write(string.rep("y\n", 300)):close()
      if not success then
        return 1
      end
    end
  end
  return 0
end

---@alias unpack_f fun(sources?: string_list_t, source_dirs?: string_list_t): error_level_n
---Unpack the package files using an 'isolated' system: this requires
---a copy of the 'basic' DocStrip program, which is used then removed
---@param sources?     string_list_t
---@param source_dirs? string_list_t
---@return error_level_n
local function unpack(sources, source_dirs)
  local error_level = deps_install(Deps.unpack)
  if error_level ~= 0 then
    return error_level
  end
  error_level = Vars.bundleunpack(source_dirs, sources)
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

---Wraps the Vars.bundleunpack. Naming may change.
---@return error_level_n
local function module_unpack()
  local error_level = deps_install(Deps.unpack)
  if error_level ~= 0 then
    return error_level
  end
  return Vars.bundleunpack()
end

---@class l3b_unpk_t
---@field Vars          l3b_unpk_vars_t
---@field unpack        unpack_f
---@field unpack_impl   target_impl_t
---@field module_unpack_impl target_impl_t

return {
  Vars          = Vars,
  unpack        = unpack,
  unpack_impl   = {
    run = unpack,
  },
  module_unpack_impl = {
    run = module_unpack,
  },
}
