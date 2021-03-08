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

local assert    = assert
local ipairs    = ipairs
local match     = string.match
local gmatch    = string.gmatch
local print     = print
local exit      = os.exit
local os_rename = os.rename

local kpse = require("kpse")
kpse.set_program_name("kpsewhich")

-- # Start of the booting process

assert(not _G.l3build, "No self call")

local in_document -- Whether in a tex document or in a package folder
local is_main     -- Whether the script is called first
local work_dir    -- the directory containing the closest "build.lua" and friends
local main_dir    -- the directory containing the topmost "build.lua" and friends

---@alias flag_table_t table<string, boolean>

---@class l3build_debug_t
---@field require boolean
---@field call boolean
---@field no_curl_posting boolean

---@class l3build_data_t

---@class l3build_t
---@field debug       flag_table_t  the special --debug-foo CLI arguments
---@field PACKAGE     string        "l3build", `package.loaded` key
---@field NAME        string        "l3build", display name
---@field PATH        string        synonym of `launch_dir` .. "/l3build.lua"
---@field is_main     boolean       True means "l3build" is the main controller.
---@field in_document boolean       True means no "build.lua"
---@field work_dir    string|nil    where the closest "build.lua" lives, nil means not in_document
---@field main_dir    string|nil    where the topmost "build.lua" lives, nil means not in_document
---@field launch_dir  string        where "l3build.lua" and friends live
---@field start_dir   string        the current directory at load time
---@field options     l3build_options_t
---@field flags       flag_table_t
---@field data        l3build_data_t


local l3build = { -- global data available as package.
  debug = {}, -- storage for special debug flags (private UI)
  flags = {}, -- various shared flags
  data = {},  -- shared data
}

do
  -- the directory containing "l3build.lua" by kpse
  local kpse_dir = kpse.lookup("l3build.lua"):match(".*/")

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
    local dir, base = path:match("(.*/)(.*)")
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
  ---@param dir   string must end with '/'
  ---@param base  string relative file or directory name
  ---@return string|nil dir ends with '/' when non nil
  local function container(dir, base)
    for _ in gmatch(dir .. lfs.currentdir(), "[^/]+") do -- tricky loop
      local p = dir .. base
      if lfs.attributes(p, "mode") then -- true iff file or dir at the given path
        return dir
      end
      -- synonym of previous line:
      -- if package.searchpath("?", p, "", "") then return dir end
      dir = dir .. "../"
    end
  end

  local cmd_path = arg[0]
  local cmd_dir, cmd_base = to_dir_base(cmd_path)

  is_main = cmd_base == "l3build" or cmd_base == "l3build.lua"
  assert(is_main == not not (arg[0]:match("l3build$") or arg[0]:match("l3build%.lua$")))
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
    if o:match("^%-%-debug") then
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
          if os_rename(p, p) then -- true iff file or dir at the given path
            return dir
          end
          dir = dir .. "../"
        end
      end)
    end
  end
  if work_dir then
    print("Package mode")
    in_document = false
    main_dir = work_dir
    repeat
      local top = container(main_dir .."../", "build.lua")
      if top then
        main_dir = top
      end
    until not top
  else
    print("Document mode")
    in_document = true
  end

  ---Register the given pakage.
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
  ---When `pkg_name` is "l3b.<name>",
  ---looks for "<l3b_dir>l3build-<name>.lua".
  ---@param pkg_name string
  ---@return table|boolean
  function require(pkg_name)
    local result = package.loaded[pkg_name]
    if result then
      return result -- recursive calls will end here
    end
    if debug_require then
      print("DEBUG Info: package required ".. pkg_name)
    end
    local name = pkg_name:match("^l3b%.(.*)")
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
    print("  kpse:   ".. kpse_dir)
    print("  launch: ".. launch_dir)
    if not in_document then
      print("  work:   ".. work_dir)
      print("  main:   ".. main_dir)
    end
    print()
  end)

end
--[=[ end of booting process ]=]

-- Terminate here if in document mode
if in_document then
  require("l3b.globals")
  return l3build
end

--[=[DEBUG flags]]
---@type oslib_t
local oslib = require("l3b.oslib")
oslib.Vars.debug.run = true
--[=[DEBUG flags end]=]

---@type l3b_arguments_t
local arguments = require("l3b.arguments")
l3build.options = arguments.parse(arg)
local options   = l3build.options

if options.debug then
  if options["debug"] then
    require("l3b.oslib").Vars.debug.run = true
  end
end

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

require("l3b.globals")
require("l3blib.options")

-- Load configuration file if running as a script
if is_main then
  -- Look for some configuration details
  dofile(work_dir .. "build.lua")
end

--[=[ CUT FROM HERE ]=]
-- Custom bundleunpack which does not search the localdir
-- That is needed as texsys.cfg is unpacked in an odd way and
-- without this will otherwise not be available
if _G.bundleunpack ~= nil then
  print("DEBUG: locally defined _G.bundleunpack")
  function _G.bundleunpack ()
    print("!!!! DEBUG bundleunpack not is main")
    print("_G.maindir", _G.maindir, require("l3b.variables").Dir.main)
    print("_G.localdir", _G.localdir)
    print("_G.unpackdir", _G.unpackdir)
    local errorlevel = _G.mkdir(_G.localdir)
    if errorlevel ~=0 then
      return errorlevel
    end
    errorlevel = _G.cleandir(_G.unpackdir)
    if errorlevel ~=0 then
      return errorlevel
    end
    for _,i in ipairs (_G.sourcefiles) do
      errorlevel = cp (i, ".", _G.unpackdir)
      if errorlevel ~=0 then
        return errorlevel
      end
    end
    for _,i in ipairs (_G.unpacksuppfiles) do
      errorlevel = cp (i, _G.supportdir, _G.localdir)
      if errorlevel ~=0 then
        return errorlevel
      end
    end
    for _,i in ipairs (_G.unpackfiles) do
      for _,j in ipairs (_G.filelist (_G.unpackdir, i)) do
        local cmd = os_setenv .. " TEXINPUTS=" .. _G.unpackdir .. os_concat ..
        _G.unpackexe .. " " .. _G.unpackopts .. " -output-directory=" .. _G.unpackdir
          .. " " .. _G.unpackdir .. "/" .. j
        local success = io.popen (
            -- Notice that os.execute is used from 'here' as this ensures that
            -- localdir points to the correct place: running 'inside'
            -- unpackdir would avoid the need for setting -output-directory
            -- but at the cost of needing to correct the relative position
            -- of localdir w.r.t. unpackdir
            cmd ,"w"
          ):write(string.rep("y\n", 300)):close()
        if not success then
          return 1
        end
      end
    end
    return 0
  end
end
--[=[ CUT TO HERE ]=]

---@type l3b_check_t
local l3b_check   = require("l3b.check")
local sanitize_engines = l3b_check.sanitize_engines

-- Sanity check
sanitize_engines()

--
-- Deal with multiple configs for tests
--

multi_check()   -- check with many configs, may exit here

prepare_config()

---@type utlib_t
local utlib = require("l3b.utillib")

-- From now on, we can cache results in choosers
utlib.flags.cache_chosen = true

-- Call the main function
_G.main(options["target"], options["names"])
