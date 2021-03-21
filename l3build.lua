#!/usr/bin/env texlua

--[[

File l3build.lua Copyright (C) 2014-2020 The LaTeX Project

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

--@module l3build

local assert  = assert
local print   = print

assert(not _G.options, "No self call")

print("DEVELOPMENT: REFACTOR BRANCH")

-- Version information
release_date = "2020-06-04"

-- Local access to functions

local ipairs    = ipairs
local gmatch    = string.gmatch
local exit      = os.exit

local kpse = require("kpse")
kpse.set_program_name("kpsewhich")

local lfs = require("lfs")
local currentdir = lfs.currentdir
local attributes = lfs.attributes

-- # Start of the booting process

-- Whether in a tex document or in a package folder:
local in_document = require("status").cs_count > 0 -- tex.print ~= nil is undocumented

--[=[
Bundle and modules are directories containing a `build.lua` file.
A module does not contain any bundle or directory as direct descendant.
A bundle does not contain other bundles as direct descendants.
--]=]

local is_main     -- Whether the script is called first
---@alias dir_path_s string -- path ending with a '/'
---@type dir_path_s
local work_dir    -- the directory containing the closest "build.lua" and friends
---@type dir_path_s
local main_dir    -- the directory containing the topmost "build.lua" and friends

---@alias flag_table_t table<string, boolean>

---@class l3build_debug_t
---@field public run              boolean
---@field public require          boolean
---@field public call             boolean
---@field public no_curl_posting  boolean
---@field public copy_core        boolean

---@class l3build_data_t

---@class l3build_t
---@field public debug       l3build_debug_t the special --debug-foo CLI arguments
---@field public PACKAGE     string        "l3build", `package.loaded` key
---@field public NAME        string        "l3build", display name
---@field public PATH        string        synonym of `launch_dir` .. "/l3build.lua"
---@field public is_main     boolean       True means "l3build" is the main controller.
---@field public in_document boolean       True means no "build.lua"
---@field public work_dir    dir_path_s|nil  where the closest "build.lua" lives, nil means not in_document
---@field public main_dir    dir_path_s|nil  where the topmost "build.lua" lives, nil means not in_document
---@field public launch_dir  dir_path_s      where "l3build.lua" and friends live
---@field public start_dir   dir_path_s      the current directory at load time
---@field public script_path string        the path of the `l3build.lua` in action.
---@field public options     options_t
---@field public flags       flag_table_t
---@field public data        l3build_data_t
---@field public G           table           Global environment for build.lua and configs

local l3build = { -- global data available as package.
  debug = {}, -- storage for special debug flags (private UI)
  flags = {}, -- various shared flags
  data = {},  -- shared data
}

print(in_document and "Document mode" or "Bundle mode")

do
  -- the directory containing "l3build.lua" by kpse, absolute
  local kpse_dir = kpse.lookup("l3build.lua"):match(".*/")

  -- Setup dirs where require will look for modules.

  local start_dir = currentdir() .. "/" -- this is the current dir at launch time, absolute

  -- is_main: whether required by someone else, or not
  local cmd_path = arg[0]
  local cmd_dir, cmd_base = cmd_path:match("(.*/)(.*)")
  if not cmd_dir then
    cmd_dir, cmd_base = "./", cmd_path
  end
  -- TODO: what about the windows stuff?
  if not cmd_dir:match("^%/") and not cmd_dir:match("^%w:") then
    cmd_dir = start_dir .. cmd_dir
  end
  -- start_dir and cmd_dir are absolute
  is_main = cmd_base == "l3build" or cmd_base == "l3build.lua"

  ---Central function to allow launching l3build from a subdirectory
  ---of a local repository.
  ---Find `base` in `dir` or one of its parents, returns the container.
  ---We do not assume that `dir` contains no ".." component
  ---such that we cannot use `to_dir_base`.
  ---Instead we append `/..` and rely on lua to do the job.
  ---The max number of trials is the number of components
  ---of the absolute path of `dir`, which majorated in the for loop
  ---Intermediate directories must exist.
  ---@param dir   string must end with '/'
  ---@param base  string relative file or directory name
  ---@return string? dir ends with '/' when non nil
  local function container(dir, base)
    for _ in gmatch(dir .. currentdir(), "[^/]+") do -- tricky loop
      local p = dir .. base
      if attributes(p, "mode") then -- true iff something at the given path
        return dir
      end
      dir = dir .. "../"
    end
  end

  local launch_dir -- the directory containing "l3build.lua"
  if in_document then -- `luatex foo/bar.tex`
    launch_dir = kpse_dir
  elseif cmd_base == "l3build.lua" then -- `texlua foo/bar/l3build.lua ...`
    launch_dir = cmd_dir
  elseif cmd_base == "l3build" then
    launch_dir = kpse_dir
  else
    launch_dir = container(currentdir(), "l3build.lua") or kpse_dir
  end
  -- launch_dir is absolute as well

  ---Calls f when one CLI option starts with "--debug"
  ---@param f fun()
  local function on_debug(f) end -- do nothing by default

  for _, o in ipairs(arg) do
    if o:match("^%-%-debug") then
      function on_debug(f) -- calls f
        f()
      end
      break
    end
  end

  -- work_dir:
  if in_document then
    work_dir = nil
  elseif cmd_base == "build.lua" then
    work_dir = cmd_dir
  else
    work_dir = container(start_dir,  "build.lua")
            or container(launch_dir, "build.lua")
    if not work_dir then
      on_debug(function ()
        print(arg[0])
        print("  start:  ".. start_dir)
        -- print("  work:   ".. work_dir)
        print("  kpse:   ".. kpse_dir)
        print("  launch: ".. launch_dir)
        local dir, base = start_dir, "build.lua"
        for _ in gmatch(dir .. currentdir(), "[^/]+") do
          local p = dir .. base
          print(p)
          if attributes(p, "mode") then -- true iff file or dir at the given path
            return dir
          end
          dir = dir .. "../"
        end
      end)
    end
  end
  if work_dir then -- package mode: bundle or module?
    main_dir = work_dir .."../"
    if not attributes(main_dir .."build.lua", "mode") then
      main_dir = work_dir -- answer: module
    end
  end
  -- work_dir and main_dir are absolute as well, if any
  
  ---Register the given pakage in `package.loaded`.
  ---Lua's require function return either true or a table.
  ---Here we always return a table.
  ---@param pkg       table|boolean
  ---@param pkg_name  string key in `package.loaded`
  ---@param name      string display name
  ---@param path      string
  local function register(pkg, pkg_name, name, path)
    if type(pkg) ~= "table" then pkg = {} end
    package.loaded[path] = nil  -- change the registration name
    package.loaded[pkg_name] = pkg
    pkg.PACKAGE = pkg_name
    pkg.NAME = name
    pkg.PATH = path
    return pkg
  end

  l3build.is_main     = is_main
  l3build.in_document = in_document
  l3build.start_dir   = start_dir -- all these are expected to end with a "/"
  l3build.launch_dir  = launch_dir
  l3build.script_path = launch_dir .."l3build.lua"
  l3build.work_dir    = work_dir  -- may be nil
  l3build.main_dir    = main_dir  -- may be nil as well

  register(l3build, "l3build", "l3build", launch_dir .. "l3build.lua")

  local require_orig = require

  local debug_require
  for _, o in ipairs(arg) do
    if o:match("^%-%-debug%-require") then
      debug_require = true
      break
    end
  end
  
  ---Overwrites global `require`.
  ---When `pkg_name` is "l3build-<name>",
  ---looks for "<l3b_dir>l3build-<name>.lua".
  ---@param pkg_name string
  ---@return table|boolean
  function require(pkg_name)
    if type(pkg_name) ~= "string" then
      print(debug.traceback())
      error("Bad package name")
    end
    local result = package.loaded[pkg_name]
    if result then
      return result -- recursive calls will end here
    end
    if debug_require then
      print("DEBUG Info: package required ".. pkg_name)
    end
    local name = pkg_name:match("^l3b%-.*")
    if name then -- an l3b library package
      package.loaded[pkg_name] = true
      local path = launch_dir .."l3b/".. name
      if debug_require then
        print("path ".. path)
      end
        result = require_orig(path) -- error here if no such module exists
      result = register(result, pkg_name, name, path .. ".lua")
    else
      name = pkg_name:match("^l3build%-.*")
      -- forthcoming management here
      if name then -- an l3build package
        package.loaded[pkg_name] = true
        local path = launch_dir .. name
        result = require_orig(path) -- error here if no such module exists
        result = register(result, pkg_name, name, path .. ".lua")
      else -- other packages
        result = require_orig(pkg_name)
      end
    end
    if debug_require then
      print("DEBUG Info: package loaded ".. pkg_name, result.PATH)
    end
    return result
  end

end

--[==[ end of booting process ]==]

---@type utlib_t
-- local utlib = require("l3b-utillib")

--[===[ DEBUG flags ]===]
---@type oslib_t
local oslib = require("l3b-oslib")
oslib.Vars.debug.run = true
--[===[ DEBUG flags end ]===]

---@type fslib_t
local fslib = require("l3b-fslib")
local set_tree_excluder = fslib.set_tree_excluder
fslib.set_working_directory(l3build.work_dir)

---@type l3b_globals_t
local l3b_globals = require("l3build-globals")

-- Terminate here if in document mode
if in_document then
  return l3build
end

--[=[ Dealing with options ]=]

---@type l3b_cli_t
local l3b_cli = require("l3build-cli")

l3b_cli.register_builtin_options()
l3b_cli.register_custom_options(work_dir)
l3b_cli.register_targets()

l3build.options = l3b_cli.parse(arg, function (arg_i)
  -- Private special debugging options "--debug-<key>"
  local key = arg_i:match("^debug%-(%w[%w%d_-]*)")
  if key then
    l3build.debug[key:gsub("-", "_")] = true
    return true
  end
end)

l3b_globals.export()

local options   = l3build.options

local debug = options.debug

if debug then -- activate the private special debugging options
  require("l3b-oslib").Vars.debug.run = l3build.debug.run -- options --debug-run
  fslib.Vars.debug.copy_core = l3build.debug.copy_core-- options --debug-copy-core
  fslib.Vars.debug.all  = true
end

local target = options.target

---@type l3b_help_t
local l3b_help  = require("l3build-help")
local help      = l3b_help.help
local version   = l3b_help.version

if target == "help" then
  help()
  exit(0)
elseif target == "version" then
  version()
  exit(0)
end

-- Load configuration file if running as a script
if is_main then
  local f, msg = loadfile(work_dir .. "/build.lua")
  if not f then
    error(msg)
  end
  f() -- ignore any output
end

-- bundle and module names recovery

---@type G_t
local G   = l3b_globals.G
---@type Dir_t
local Dir = l3b_globals.Dir

---@type l3b_targets_t
local l3b_targets_t = require("l3b-targets")
local process       = l3b_targets_t.process

---@type l3b_aux_t
local l3b_aux = require("l3build-aux")
local call    = l3b_aux.call

exit(process(options, {
  preflight     = function ()
    -- utlib.flags.cache_bridge = true not yet implemented
    set_tree_excluder(function (path)
      return path == Dir.build -- problem with path comparison
    end)
  end,
  at_bundle_top = G.at_bundle_top,
  top_callback  = function (module_target)
    return call(G.modules, module_target)
  end,
}))
