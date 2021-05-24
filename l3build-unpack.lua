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

---@type pathlib_t
local pathlib           = require("l3b-pathlib")
local dir_base          = pathlib.dir_base

---@type utlib_t
local utlib     = require("l3b-utillib")
local entries   = utlib.entries
local is_error  = utlib.is_error

---@type oslib_t
local oslib       = require("l3b-oslib")
local cmd_concat  = oslib.cmd_concat
local OS          = oslib.OS
local run         = oslib.run
local quoted_path = oslib.quoted_path

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

---Unpack the given dependencies.
---A dependency is the path of a directory, possibly relative to the main one.
---The concept of dependency implies some shared domain.
---The dependent object must now where to put the shared information
---needed by the client.
---@param deps string[] @ regular array of dependencies. See `Deps` fields.
---@return error_level_n @ 0 on proper termination, a non 0 error code otherwise.
---@see stdmain, check, unpack, typesetting
---@usage Private?
local function deps_install(deps)
  local error_level
  local cmd = "texlua " .. quoted_path(l3build.script_path) .. " unpack"
  if not l3build.options.debug then
    cmd = cmd .." -q"
  end
  for dep in entries(deps) do
    print("Installing dependency: " .. dep)
    error_level = run(dep, cmd)
    if is_error(error_level) then
      return error_level
    end
  end
  return 0
end

---Copy the support files to the appropriate build area
---@return error_level_n
local function prepare_support()
  local error_level = make_directory(Dir[l3b_globals.LOCAL])
  if is_error(error_level) then
    return error_level
  end
  return copy_tree(
    Files.unpacksupp,
    Dir.support,
    Dir[l3b_globals.LOCAL]
  )
end

---Copy the source files to the appropriate build area
---@param source_dirs string[]|nil @defaults to the source directory
---@param sources     string[]|nil @defaults to the source files glob
---@return error_level_n
local function prepare_source(source_dirs, sources)
  local error_level = make_clean_directory(Dir.unpack)
  if is_error(error_level) then
    return error_level
  end
  -- copy the source files into the unpacked build area
  for src_dir in entries(source_dirs) do
    for globs in entries(sources) do
      error_level = copy_tree(globs, src_dir, Dir.unpack)
      if is_error(error_level) then
        return error_level
      end
    end
  end
  return error_level
end

---bundleunpackcmd
---@param name string @ path relative to the `Dir.unpack` directory
---@return string|nil
---@return nil|error_level_n
local function bundleunpackcmd(name)
  local options = l3build.options
  local local_dir = quoted_absolute_path(Dir[l3b_globals.LOCAL])
  local dir_path, base_name = dir_base(name)
  dir_path = Dir.unpack / dir_path
  local error_level = make_directory(dir_path)
  if is_error(error_level) then
    return nil, error_level
  end
  local cmd_cd = "cd " .. dir_path
  local search_system = G.unpacksearch and OS.pathsep or ""
  -- next means that unpack is pdftex or so
  -- a better design would be to have a
  -- preliminary configure step
  local cmd_prepare_1 = OS.setenv
    .. " TEXINPUTS=."
    .. OS.pathsep
    .. local_dir
    .. search_system
  local cmd_prepare_2 = OS.setenv
    .. " LUAINPUTS=."
    .. OS.pathsep
    .. local_dir
    .. search_system
  local cmd_unpack = Exe.unpack .. " "
    .. Opts.unpack .. " "
    .. base_name
    .. (options.quiet and (" > " .. OS.null) or "")
  return cmd_concat(
    cmd_cd,
    cmd_prepare_1,
    cmd_prepare_2,
    cmd_unpack
  )
end

---Split off from the main unpack so it can be used on a bundle and not
---leave only one modules files.
---Files are unpacked in `Dir.unpack` but this file is cleaned up
---at each run such that there is no memory between runs of uncpack.
---This was an undocumented global overriden by latex2e.
---@param source_dirs string[]|nil @defaults to the source directory
---@param sources     string[]|nil @defaults to the source files glob
---@return error_level_n
local function bundleunpack(source_dirs, sources)
  source_dirs = source_dirs or { Dir.sourcefile }
  sources = sources or { Files.source }
  local options = l3build.options
  local error_level = prepare_source(source_dirs, sources)
  if is_error(error_level) then
    return error_level
  end
  error_level = prepare_support()
  if is_error(error_level) then
    return error_level
  end
  for glob in entries(Files.unpack) do
    for p in tree(Dir.unpack, glob) do
      local cmd = G.bundleunpackcmd(p.src)
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
  if is_error(error_level) then
    return error_level
  end
  error_level = G.bundleunpack(source_dirs, sources)
  if is_error(error_level) then
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
  if is_error(error_level) then
    return error_level
  end
  return G.bundleunpack()
end

---@alias bundleunpack_f fun(source_dirs: string[]|nil, sources: string[]|nil): error_level_n
---@alias bundleunpackcmd_f fun(name: string): string

---@class l3b_unpk_t
---@field public deps_install       fun(deps: table): number
---@field public unpack             unpack_f
---@field public bundleunpack       bundleunpack_f
---@field public bundleunpackcmd    bundleunpackcmd_f
---@field public unpack_impl        target_impl_t
---@field public module_unpack_impl target_impl_t

-- implement bundleunpack and bundleunpackcmd
---@type modlib_t
local modlib = require("l3b-modlib")
modlib.bundleunpack     = bundleunpack
modlib.bundleunpackcmd  = bundleunpackcmd

return {
  deps_install    = deps_install,
  unpack          = unpack,
  bundleunpack    = bundleunpack,
  bundleunpackcmd = bundleunpackcmd,
  unpack_impl     = {
    run = unpack,
  },
  module_unpack_impl = {
    run = module_unpack,
  },
},
---@class __l3b_unpk_t
---@field private prepare_support fun(): error_level_n
---@field private prepare_source  fun(source_dirs: string[]|nil, sources: string[]|nil): error_level_n
_ENV.during_unit_testing and {
  prepare_support = prepare_support,
  prepare_source  = prepare_source,
} or nil
