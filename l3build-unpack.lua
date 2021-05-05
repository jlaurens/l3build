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
local entries = utlib.entries

---@type pathlib_t
local pathlib             = require("l3b-pathlib")
local dir_base          = pathlib.dir_base

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
local quoted_absolute_path  = fslib.quoted_absolute_path

---@type l3build_t
local l3build = require("l3build")

---@type l3b_globals_t
local l3b_globals = require("l3build-globals")
---@type G_t
local G           = l3b_globals.G
---@type Dir_t
local Dir         = l3b_globals.Dir
---@type Files_t
local Files       = l3b_globals.Files
---@type Deps_t
local Deps        = l3b_globals.Deps
---@type Exe_t
local Exe         = l3b_globals.Exe
---@type Opts_t
local Opts        = l3b_globals.Opts

---Split off from the main unpack so it can be used on a bundle and not
---leave only one modules files.
---Files are unpacked in `Dir.unpack` but this file is cleaned up
---at each run such that there is no memory between runs of uncpack.
---@param source_dirs string[]|nil @defaults to the source directory
---@param sources     string[]|nil @defaults to the source files glob
---@return error_level_n
local function bundleunpack(source_dirs, sources)
  source_dirs = source_dirs or { Dir.sourcefile }
  sources = sources or { Files.source }
  local options = l3build.options
  local error_level = make_directory(Dir[l3b_globals.LOCAL])
  if error_level ~= 0 then
    return error_level
  end
  error_level = make_clean_directory(Dir.unpack)
  if error_level ~= 0 then
    return error_level
  end
  for src_dir in entries(source_dirs) do
    for globs in entries(sources) do
      error_level = copy_tree(globs, src_dir, Dir.unpack)
      if error_level ~= 0 then
        return error_level
      end
    end
  end
  error_level = copy_tree(
    Files.unpacksupp,
    Dir.support,
    Dir[l3b_globals.LOCAL]
  )
  if error_level ~= 0 then
    return error_level
  end
  for glob in entries(Files.unpack) do
    for p in tree(Dir.unpack, glob) do
      local dir_path, base_name = dir_base(p.src)
      local local_dir = quoted_absolute_path(Dir[l3b_globals.LOCAL])
      local cmd = cmd_concat(
        "cd " .. Dir.unpack / dir_path,
        OS.setenv .. " TEXINPUTS=." .. OS.pathsep
          .. local_dir .. (G.unpacksearch and OS.pathsep or ""),
        OS.setenv .. " LUAINPUTS=." .. OS.pathsep
          .. local_dir .. (G.unpacksearch and OS.pathsep or ""),
        Exe.unpack .. " " .. Opts.unpack .. " " .. base_name
          .. (options.quiet and (" > " .. OS.null) or "")
      )
      if options.debug then
        print("DEBUG: ".. cmd)
      end
      local success = popen(cmd, "w")
        :write(("y\n"):rep(300))
        :close()
      if not success then
        return 1
      end
    end
  end
  return 0
end

---@alias unpack_f fun(sources?: string[], source_dirs?: string[]): error_level_n
---Unpack the package files using an 'isolated' system: this requires
---a copy of the 'basic' DocStrip program, which is used then removed
---@param sources?     string[]
---@param source_dirs? string[]
---@return error_level_n
local function unpack(sources, source_dirs)
  local error_level = deps_install(Deps.unpack)
  if error_level ~= 0 then
    return error_level
  end
  error_level = G.bundleunpack(source_dirs, sources)
  if error_level ~= 0 then
    return error_level
  end
  return copy_tree(
    Files.install,
    Dir.unpack,
    Dir[l3b_globals.LOCAL]
  )
end

---Wraps the G.bundleunpack. Naming may change.
---@return error_level_n
local function module_unpack()
  local error_level = deps_install(Deps.unpack)
  if error_level ~= 0 then
    return error_level
  end
  return G.bundleunpack()
end

---@class l3b_unpk_t
---@field public unpack        unpack_f
---@field public unpack_impl   target_impl_t
---@field public module_unpack_impl target_impl_t

return {
  unpack        = unpack,
  bundleunpack  = bundleunpack,
  unpack_impl   = {
    run = unpack,
  },
  module_unpack_impl = {
    run = module_unpack,
  },
}
