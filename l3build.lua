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
local gmatch    = string.gmatch
local print     = print
local exit      = os.exit
local os_rename = os.rename

local kpse = require("kpse")
kpse.set_program_name("kpsewhich")

-- # Start of the booting process

assert(not _G.l3build, "No self call")

-- Whether in a tex document or in a package folder:
local in_document = require("status").cs_count > 0 -- tex.print ~= nil is undocumented

local is_main     -- Whether the script is called first
local work_dir    -- the directory containing the closest "build.lua" and friends
local main_dir    -- the directory containing the topmost "build.lua" and friends

---@alias flag_table_t table<string, boolean>

---@class l3build_debug_t
---@field run     boolean
---@field require boolean
---@field call    boolean
---@field no_curl_posting boolean

---@class l3build_data_t

---@class l3build_t
---@field debug       l3build_debug_t the special --debug-foo CLI arguments
---@field PACKAGE     string        "l3build", `package.loaded` key
---@field NAME        string        "l3build", display name
---@field PATH        string        synonym of `launch_dir` .. "/l3build.lua"
---@field is_main     boolean       True means "l3build" is the main controller.
---@field in_document boolean       True means no "build.lua"
---@field work_dir    string|nil    where the closest "build.lua" lives, nil means not in_document
---@field main_dir    string|nil    where the topmost "build.lua" lives, nil means not in_document
---@field launch_dir  string        where "l3build.lua" and friends live
---@field start_dir   string        the current directory at load time
---@field options     options_t
---@field flags       flag_table_t
---@field data        l3build_data_t

local l3build = { -- global data available as package.
  debug = {}, -- storage for special debug flags (private UI)
  flags = {}, -- various shared flags
  data = {},  -- shared data
}

print(in_document and "Document mode" or "Bundle mode")

do
  -- the directory containing "l3build.lua" by kpse
  local kpse_dir = kpse.lookup("l3build.lua"):match(".*/")

  -- Setup dirs where require will look for modules.

  -- File operations are aided by the LuaFileSystem module
  local lfs = require("lfs")

  local start_dir = lfs.currentdir() .. "/" -- this is the current dir at launch time

  -- is_main: whether required by someone else, or not
  local cmd_path = arg[0]
  local cmd_dir, cmd_base = cmd_path:match("(.*/)(.*)")
  if not cmd_dir then
    cmd_dir, cmd_base = "./", cmd_path
  end
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

  local launch_dir -- the directory containing "l3build.lua"
  if in_document then -- `luatex foo/bar.tex`
    launch_dir = kpse_dir
  elseif cmd_base == "l3build.lua" then -- `texlua foo/bar/l3build.lua ...`
    launch_dir = cmd_dir
  elseif cmd_base == "l3build" then
    launch_dir = kpse_dir
  else
    launch_dir = container('./', "l3build.lua") or kpse_dir
  end

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
  if work_dir then -- package mode
    main_dir = work_dir
    repeat
      local top = container(main_dir .."../", "build.lua")
      if top then
        main_dir = top
      end
    until not top
  end

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
    if name then
      package.loaded[pkg_name] = true
      local path = launch_dir .."l3b/".. name
      result = require_orig(path) -- error here if no such module exists
      result = register(result, pkg_name, name, path .. ".lua")
    else
      name = pkg_name:match("^l3build%-.*")
      -- forthcoming management here
      if name then
        package.loaded[pkg_name] = true
        local path = launch_dir .. name
        result = require_orig(path) -- error here if no such module exists
        result = register(result, pkg_name, name, path .. ".lua")
      else
        result = require_orig(pkg_name)
      end
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
--[==[ end of booting process ]==]

-- Terminate here if in document mode
if in_document then
  require("l3build-globals") -- certainly too large
  return l3build
end

--[===[DEBUG flags]===]
---@type oslib_t
local oslib = require("l3b-oslib")
oslib.Vars.debug.run = true
--[===[DEBUG flags end]===]

---@type l3b_options_t
local l3b_options = require("l3b-options")
l3build.options = l3b_options.parse(arg, function (arg_i)
  -- Private special debugging options "--debug-<key>"
  local key = arg_i:match("^%-%-debug%-(%w[%w%d_-]*)")
  if key then
    l3build.debug[key:gsub("-", "_")] = true
    return true
  end
end)
local options   = l3build.options

local debug = options.debug

if debug then
  print("DEBUG: ".. arg[0] .." ".. table.concat(arg, " "))
  require("l3b-oslib").Vars.debug.run = true
  require("l3b-fslib").Vars.debug.copy_core = true
end

local target = options.target

---@type l3b_help_t
local l3b_help  = require("l3build-help")
local help      = l3b_help.help
local version   = l3b_help.version

-- and that has to come after the functions are defined
if target == "help" then
  help()
  exit(0)
elseif target == "version" then
  version()
  exit(0)
end

require("l3build-globals")

-- Load configuration file if running as a script
if is_main then
  -- Look for some configuration details
  dofile(work_dir .. "build.lua")
end

---@type utlib_t
local utlib = require("l3b-utillib")

---@type l3b_vars_t
local l3b_vars  = require("l3build-variables")
---@type Main_t
local Main      = l3b_vars.Main

---@type l3b_targets_t
local l3b_targets_t   = require("l3b-targets")
local get_target_info = l3b_targets_t.get_info

---@type l3b_aux_t
local l3b_aux             = require("l3build-aux")
local call                = l3b_aux.call

-- Deal with unknown targets up-front
local info = get_target_info(target)
if not info then
  error("Unknown target name: ".. target)
end
local error_level = 0
if info.will_run then
  if debug then
    print("DEBUG: will_run ".. target)
  end
  error_level = info.will_run(options)
  if error_level ~= 0 then
    exit(error_level)
  end
end
if info.alt_run then
  if debug then
    print("DEBUG: alt_run ".. target)
  end
  error_level = info.alt_run(options)
  if error_level ~= nil then
    exit(error_level)
  end
end
if info.configure_run then
  if debug then
    print("DEBUG: configure_run ".. target)
  end
  error_level = info.configure_run(options)
  if error_level ~= 0 then
    exit(error_level)
  end
end
-- From now on, we can cache results in choosers
utlib.flags.cache_chosen = true
local names = options.names
if _G.main then
  if debug then
    print("DEBUG: global main ".. target)
  end
  exit(_G.main(target, names, options))
end
if Main._at_bundle_top then
  if info.bundle_run then
    if debug then
      print("DEBUG: bundle_run ".. target)
    end
    error_level = info.bundle_run(names)
  else
    -- Detect all of the modules
    if debug then
      print("DEBUG: modules run ".. target)
    end
    local modules = Main.modules
    error_level = call(modules, info.bundle_target)
  end
else
  if debug then
    print("DEBUG: run ".. target)
  end
  error_level = info.run(names)
end
exit(error_level)
