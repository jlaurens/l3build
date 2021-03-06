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

print("DEVELOPMENT: REFACTOR BRANCH")

-- Version information
release_date = "2020-06-04"

-- Local access to functions

local assert  = assert
local ipairs  = ipairs
local match   = string.match
local gmatch  = string.gmatch
local print   = print
local exit    = os.exit

local kpse = require("kpse")
kpse.set_program_name("kpsewhich")

-- # Start of the booting process

assert(not _G.l3build, "No self call")

local is_main  -- Whether the script is called first
local work_dir -- the directory containing "build.lua" and friends

---@alias flag_table_t table<string, boolean>

---@class l3build_debug_t
---@field require boolean
---@field call boolean
---@field no_curl_posting boolean

---@class l3build_data_t

---@class l3build_options_t
---@field config    table
---@field date      string
---@field dirty     boolean
---@field dry_run   boolean
---@field email     string
---@field engine    table
---@field epoch     string
---@field file      string
---@field first     boolean
---@field force     boolean
---@field full      boolean
---@field halt_on_error boolean -- real name "halt-on-error"
---@field help      boolean
---@field message   string
---@field names     table
---@field quiet     boolean
---@field rerun     boolean
---@field shuffle   boolean
---@field texmfhome string

---@class l3build_t
---@field debug flag_table_t the special --debug-foo CLI arguments
---@field PACKAGE string "l3build", `package.loaded` key
---@field NAME string "l3build", display name
---@field PATH string synonym of `launch_dir` .. "/l3build.lua"
---@field work_dir string where the "build.lua" lives
---@field root_dir string where the topmost "build.lua" lives
---@field launch_dir string where "l3build.lua" and friends live
---@field start_dir string the current directory at load time
---@field options l3build_options_t
---@field flags flag_table_t
---@field data l3build_data_t


local l3build = { -- global data available as package.
  debug = {}, -- storage for special debug flags (private UI)
  flags = {}, -- various shared flags
  data = {};  -- shared data
}

do
  -- the directory containing "l3build.lua" by kpse
  local kpse_dir = match(kpse.lookup("l3build.lua"), ".*/")

  -- Setup dirs where require will look for modules.

  local launch_dir -- the directory containing "l3build.lua"

  -- File operations are aided by the LuaFileSystem module
  local lfs = require("lfs")

  local start_dir = lfs.currentdir() .. "/" -- this is the current dir at launch time

  ---Extract dir and base from path
  ---@param path string
  ---@return string dir includes a trailing '/', defaults to "./"
  ---@return string base
  local function to_dir_base(path)
    local dir, base = match(path, "(.*/)(.*)")
    if not dir then dir, base = "./", path end
    return dir, base
  end

  ---Central function to allow launching l3build from a subdirectory
  ---of a local repository.
  ---Find `base` in `dir` or one of its parents, returns the container.
  ---We do not assume that `dir` contains no ".." component
  ---such that we cannot use `to_dir_base`.
  ---Instead we append `/..` and rely on lua to do the job.
  ---The max number of trials is the number of components
  ---of the absolute path of `dir`, which majorated in the for loop
  ---Intermediate directories must exist.
  ---@param dir string must end with '/'
  ---@param base string relative file or directory name
  ---@return string|nil dir ends with '/' when non nil
  local function container(dir, base)
    for _ in gmatch(dir .. lfs.currentdir(), "[^/]+") do -- tricky loop
      local p = dir .. base
      if os.rename(p, p) then return dir end -- true iff file or dir at the given path
      -- synonym of previous line:
      -- if package.searchpath("?", p, "", "") then return dir end
      -- if lfs.atributes(p, "mode") then return dir end
      dir = dir .. "../"
    end
  end

  local cmd_path = arg[0]
  local cmd_dir, cmd_base = to_dir_base(cmd_path)

  is_main = cmd_base == "l3build" or cmd_base == "l3build.lua"
  assert(is_main == not not (match(arg[0], "l3build$") or match(arg[0], "l3build%.lua$")))
  -- launch_dir:
  if cmd_base == "l3build.lua" then -- `texlua foo/bar/l3build.lua ...`
    launch_dir = cmd_dir
  elseif cmd_base == "l3build" then
    launch_dir = kpse_dir
  else
    launch_dir = container('./', "l3build.lua") or kpse_dir
  end


  ---Calls f when one CLI option starts with "--debug"
  ---@param f fun()
  local function on_debug(f) end

  for _, o in ipairs(arg) do
    if match(o, "^%-%-debug") then
      function on_debug(f)
        f()
      end
      break
    end
  end

  -- work_dir:
  if cmd_base == "build.lua" then
    work_dir = cmd_dir
  else
    work_dir = container(cmd_dir, "build.lua") or container(start_dir, "build.lua")
    if not work_dir then
      on_debug(function ()
        print(arg[0])
        print("  start:  ".. start_dir)
        -- print("  work:   ".. work_dir)
        print("  kpse:   ".. kpse_dir)
        print("  launch: ".. launch_dir)
        local dir, base = start_dir, "build.lua"
        for _ in gmatch(dir .. lfs.currentdir(), "[^/]+") do
          local p = dir .. base
          print(p)
          if os.rename(p, p) then return dir end -- true iff file or dir at the given path
          dir = dir .. "../"
        end
      end)
    end
    assert(work_dir, 'Error: Cannot find configuration file "build.lua"')
  end

  ---Register the given pakage.
  ---Lua's require function return either true or a table.
  ---Here we always return a table.
  ---@param pkg table|boolean
  ---@param pkg_name string key in `package.loaded`
  ---@param name string display name
  ---@param path string
  local function register(pkg, pkg_name, name, path)
    if type(pkg) ~= "table" then pkg = {} end
    package.loaded[path] = nil  -- change the registration name
    package.loaded[pkg_name] = pkg
    pkg.PACKAGE = pkg_name
    pkg.NAME = name
    pkg.PATH = path
    return pkg
  end

  l3build._work_dir = work_dir
  l3build.start_dir = start_dir
  l3build.launch_dir = launch_dir

  register(l3build, "l3build", "l3build", launch_dir .. "l3build.lua")

  local require_orig = require

  local debug_require
  for _, o in ipairs(arg) do
    if match(o, "^%-%-debug%-require") then
      debug_require = true
      break
    end
  end
  
  ---Overwrites global `require`.
  ---When `pkg_name` is "l3b.<name>",
  ---looks for "<l3b_dir>l3build-<name>.lua".
  ---@param pkg_name string
  ---@return table|boolean
  function require(pkg_name)
    local result = package.loaded[pkg_name]
    if result then return result end -- recursive calls will end here
    if debug_require then
      print("DEBUG Info: package required ".. pkg_name)
    end
    local name = match(pkg_name, "^l3b%.(.*)")
    if name then
      package.loaded[pkg_name] = true
      local path = launch_dir .. "l3build-"..name
      result = require_orig(path) -- error here if no such module exists
      result = register(result, pkg_name, name, path .. ".lua")
    else
      -- forthcoming management here
      result = require_orig(pkg_name)
    end
    if debug_require then
      print("DEBUG Info: package loaded ".. pkg_name, result.PATH)
    end
    return result
  end

  on_debug(function ()
    print("l3build: A testing and building system for LaTeX")
    print("  start:  ".. start_dir)
    print("  work:   ".. work_dir)
    print("  kpse:   ".. kpse_dir)
    print("  launch: ".. launch_dir)
    print()
  end)

end
--[=[ end of booting process ]=]

---@type oslib_t
local oslib = require("l3b.oslib")
oslib.Vars.debug.run = true

---@type l3b_arguments_t
local arguments     = require("l3b.arguments")
l3build.options     = arguments.parse(arg)
local options       = l3build.options

---@type l3b_help_t
local l3b_help  = require("l3b.help")
local help      = l3b_help.help
local version   = l3b_help.version

require("l3b.typesetting")

require("l3b.clean")

-- This has to come after stdmain(),
-- and that has to come after the functions are defined
if options["target"] == "help" then
  help()
  exit(0)
elseif options["target"] == "version" then
  version()
  exit(0)
end

---@type l3b_main_t
local l3b_main        = require("l3b.stdmain")
local multi_check     = l3b_main.multi_check
local prepare_config  = l3b_main.prepare_config

-- Allow main function to be disabled 'higher up'
_G.main = _G.main or l3b_main.main

-- Load configuration file if running as a script
if is_main then
  -- Look for some configuration details
  dofile(work_dir .. "build.lua")
end

---@type l3b_check_t
local l3b_check   = require("l3b.check")
local sanitize_engines = l3b_check.sanitize_engines

-- Sanity check
sanitize_engines()

--
-- Deal with multiple configs for tests
--

multi_check() -- check with many configs, may exit here

prepare_config()

---@type utlib_t
local utlib = require("l3b.utillib")

-- From now on, we can cache results in choosers
utlib.flags.cache_chosen = true

-- Call the main function
_G.main(options["target"], options["names"])
