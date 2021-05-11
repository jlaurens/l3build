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

assert(not _G.options, "No self call")

print("DEVELOPMENT: REFACTOR BRANCH")

-- Version information
release_date = "2020-06-04"

-- Local access to functions

local ipairs    = ipairs

local kpse = require("kpse")
kpse.set_program_name("kpsewhich")

local lfs = require("lfs")
local currentdir  = lfs.currentdir
local chdir       = lfs.chdir
local attributes  = lfs.attributes

-- # Start of the booting process

-- Whether in a tex document or in a package folder:
local in_document = require("status").cs_count > 0 -- tex.print ~= nil is undocumented

--[=[
Bundle and modules are directories containing a `build.lua` file.
A module does not contain any bundle or directory as direct descendant.
A bundle does not contain other bundles as direct descendants.
--]=]

local is_l3build     -- Whether the script is called first
---@alias dir_path_s string -- path ending with a '/'
---@type dir_path_s
local work_dir    -- the directory containing the closest "build.lua" and friends
---@type dir_path_s
local main_dir    -- the directory containing the topmost "build.lua" and friends

---@class l3build_debug_t
---@field public run              boolean
---@field public require          boolean
---@field public call             boolean
---@field public no_curl_posting  boolean
---@field public copy_core        boolean

---@type l3build_debug_t
local the_debug = {}

---@class l3build_t
---@field public debug        l3build_debug_t  @the special --debug-foo CLI arguments
---@field public TEST_DIR     string           @"l3build", `package.loaded` key
---@field public TEST_ALT_DIR string           @"l3build", `package.loaded` key
---@field public PACKAGE      string           @"l3build", `package.loaded` key
---@field public NAME         string           @"l3build", display name
---@field public PATH         string           @synonym of `launch_dir` .. "/l3build.lua"
---@field public is_l3build   boolean          @True means "l3build" is the main controller.
---@field public in_document  boolean          @True means no "build.lua"
---@field public work_dir     dir_path_s|nil   @where the closest "build.lua" lives, nil means not in_document
---@field public main_dir     dir_path_s|nil   @where the topmost "build.lua" lives, nil means not in_document
---@field public launch_dir   dir_path_s       @where "l3build.lua" and friends live
---@field public start_dir    dir_path_s       @the current directory at load time
---@field public script_path  string           @the path of the `l3build.lua` in action.
---@field public options      options_t
---@field public flags        flags_t
---@field public main         Main

local l3build = { -- global data available as package.
  debug         = the_debug, -- storage for special debug flags (private UI)
  flags         = {}, -- various shared flags
  -- these are reserved directory names
  TEST_DIR      = "l3b-test",
  TEST_ALT_DIR  = "l3b-test-alt",
}

print(in_document and "Document mode" or "Bundle mode")

do
  -- the directory containing "l3build.lua" by kpse, absolute
  local kpse_dir = kpse.lookup("l3build.lua"):match(".*/")

  -- Setup dirs where require will look for modules.

  local start_dir = currentdir() .. "/" -- this is the current dir at launch time, absolute
  -- is_l3build: whether required by someone else, or not
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
  is_l3build = cmd_base == "l3build" or cmd_base == "l3build.lua"

  ---Central function to allow launching l3build from a subdirectory
  ---of a local repository.
  ---Find `base` in `dir` or one of its parents, returns the container.
  ---We do not assume that `dir` contains no ".." component
  ---such that we cannot use `to_dir_base`.
  ---Instead we append `/..` and rely on lua to do the job.
  ---The max number of trials is the number of components
  ---of the absolute path of `dir`, which majorated in the for loop
  ---Intermediate directories must exist.
  ---For testing reasons, we do not cross the `l3b-test-alt` component and alike.
  ---@param dir   string @must end with '/'
  ---@param base  string @relative file or directory name
  ---@return string? @dir ends with '/' when non nil
  local function container(dir, base)
    local old = currentdir()
    local result
    while chdir(dir) do
      local cwd = currentdir()
      if cwd:match("/l3b-test-alt$") then
        break
      end
      if attributes(base, "mode") then -- true iff something at the given path
        result = cwd .. "/"
        break
      end
      dir = dir .. "/../"
    end
    -- loop over path components
    chdir(old)
    print(result)
    return result
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
        print("  start: ".. start_dir)
        -- print("  work:  ".. work_dir)
        print("  kpse:  ".. kpse_dir)
        print("  launch: ".. launch_dir)
        local dir, base = start_dir, "build.lua"
        for _ in dir .. currentdir():gmatch("[^/]+") do
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
  
  ---@function register
  ---Register the given pakage in `package.loaded`.
  ---Lua's require function return either true or a table.
  ---Here we always return a table.
  ---@param pkg       table|boolean
  ---@param pkg_name  string @key in `package.loaded`
  ---@param name      string @display name
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

  l3build.is_l3build       = is_l3build
  l3build.in_document   = in_document
  l3build.start_dir     = start_dir -- all these are expected to end with a "/"
  l3build.launch_dir    = launch_dir
  l3build.script_path   = launch_dir .."l3build.lua"
  l3build.work_dir      = work_dir  -- may be nil
  l3build.main_dir      = main_dir  -- may be nil as well

  register(l3build, "l3build", "l3build", launch_dir .. "l3build.lua")

  local require_orig = require

  local debug_require
  for _, o in ipairs(arg) do
    if o:match("^%-%-debug%-require") then
      debug_require = true
      break
    end
  end
  
  ---@function require
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
      local path
      if pkg_name:match("/") then
        path = launch_dir .. name
      else
        path = launch_dir .."l3b/".. name
      end
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

if arg[1] == "test" then
  return require("l3build-test").run()
end

require("l3b-fslib").set_working_directory(work_dir)

-- Terminate here if in document mode
if in_document then
  return l3build
end

---@type l3b_main_t
local l3b_main = require("l3build-main")

local main = l3b_main.Main()

l3build.main = main

return main:run(work_dir, is_l3build)
