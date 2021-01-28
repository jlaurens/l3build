--[[

File l3build-stdmain.lua Copyright (C) 2018-2020 The LaTeX3 Project

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

--

build_require("help")
build_require("file-functions")
build_require("typesetting")
build_require("aux")
build_require("clean")
build_require("check")
build_require("ctan")
build_require("install")
build_require("unpack")
build_require("manifest")
build_require("manifest-setup")
build_require("tagging")
build_require("upload")

-- local safe guards and shortcuts

local lfs    = lfs
local exit   = os.exit
local insert = table.insert
local match  = string.match

-- List all modules
function listmodules()
  local modules = { }
  local exclmodules = exclmodules or { }
  for entry in lfs.dir(".") do
    if entry ~= "." and entry ~= ".." then
      local attr = lfs.attributes(entry)
      assert(type(attr) == "table")
      if attr.mode == "directory" then
        if not exclmodules[entry] then
          insert(modules, entry)
        end
      end
    end
  end
  return modules
end

target_list =
  {
    -- Some hidden targets
    bundlecheck =
      {
        func = check,
        pre  = function(names)
            if names then
              print("Bundle checks should not list test names")
              help()
              exit(1)
            end
            return 0
          end
      },
    bundlectan =
      {
        func = bundlectan
      },
    bundleunpack =
      {
        func = bundleunpack,
        pre  = function() return(dep_install(unpackdeps)) end
      },
    -- Public targets
    check =
      {
        bundle_target = true,
        desc = "Run all automated tests",
        func = check,
      },
    clean =
      {
        bundle_func = bundleclean,
        desc = "Clean out directory tree",
        func = clean
      },
    ctan =
      {
        bundle_func = ctan,
        desc = "Create CTAN-ready archive",
        func = ctan
      },
    doc =
      {
        desc = "Typesets all documentation files",
        func = doc
      },
    install =
      {
        desc = "Installs files into the local texmf tree",
        func = install
      },
    manifest =
      {
        desc = "Creates a manifest file",
        func = manifest
      },
    save =
      {
        desc = "Saves test validation log",
        func = save
      },
    tag =
      {
        bundle_func = function(names)
            local modules = modules or listmodules()
            local errorlevel = call(modules,"tag")
            -- Deal with any files in the bundle dir itself
            if errorlevel == 0 then
              errorlevel = tag(names)
            end
            return errorlevel
          end,
        desc = "Updates release tags in files",
        func = tag,
        pre  = function(names)
           if names and #names > 1 then
             print("Too many tags specified; exactly one required")
             exit(1)
           end
           return 0
         end
      },
    uninstall =
      {
        desc = "Uninstalls files from the local texmf tree",
        func = uninstall
      },
    unpack=
      {
        bundle_target = true,
        desc = "Unpacks the source files into the build tree",
        func = unpack
      },
    upload =
      {
        desc = "Send archive to CTAN for public release",
        func = upload
      },
  }

local function do_help(_ENV)
  -- This has to come after stdmain(),
  -- and that has to come after the functions are defined
  if options["target"] == "help" or not options["target"] then
    help()
    exit(0)
  elseif options["target"] == "version" then
    version()
    exit(0)
  end
end

local function setup(_ENV, arg_0)
  -- Load configuration file if running as a script
  if match(arg_0, "l3build$") or match(arg_0, "l3build%.lua$") then
    -- Look for some configuration details
    if fileexists("build.lua") then
      dofile("build.lua")
    else
      print("Error: Cannot find configuration build.lua")
      exit(1)
    end
  end
end

local function check_env(_ENV)
  -- Ensure that directories are 'space safe'
  local function escape(key)
    _ENV[key] = escapepath(_ENV[key])
  end
  for _, v in ipairs({
    "maindir",
    "docfiledir",
    "sourcefiledir",
    "supportdir",
    "testfiledir",
    "testsuppdir",
    "builddir",
    "distribdir",
    "localdir",
    "resultdir",
    "testdir",
    "typesetdir",
    "unpackdir",
  }) do
    escape(v)
  end

  --@param epoch string
  --@return number
  --@see l3build.lua
  --@usage private?
  local function normalize_epoch(epoch)
    assert(epoch, 'normalize_epoch argument must not be nil')
    -- If given as an ISO date, turn into an epoch number
    local y, m, d = match(epoch, "^(%d%d%d%d)-(%d%d)-(%d%d)$")
    if y then
      return _ENV.os_time({
          year = y, month = m, day   = d,
          hour = 0, sec = 0, isdst = nil
        }) - _ENV.os_time({
          year = 1970, month = 1, day = 1,
          hour = 0, sec = 0, isdst = nil
        })
    elseif match(epoch, "^%d+$") then
      return tonumber(epoch)
    else
      return 0
    end
  end
  -- Tidy up the epoch setting
  -- Force an epoch if set at the command line
  -- Must be done after loading variables, etc.
  if options["epoch"] then
    epoch           = options["epoch"]
    forcecheckepoch = true
    forcedocepoch   = true
  end
  epoch = normalize_epoch(epoch)

  ---Check whether given engines are compatible with `checkengines`
  ---@param _ENV table environment
  local function check_engines(_ENV)
    if options["engine"] and not options["force"] then
      -- Make a lookup table
      local t = {}
      for _, engine in pairs(checkengines) do
        t[engine] = true
      end
      for _, engine in pairs(options["engine"]) do
        if not t[engine] then
          print("\n! Error: Engine \"" .. engine .. "\" not set up for testing!")
          print("\n  Valid values are:")
          for _, engine in ipairs(checkengines) do
            print("  - " .. engine)
          end
          print("")
          exit(1)
        end
      end
    end
  end
  -- Sanity check
  check_engines(_ENV)

  --
  -- Deal with multiple configs for tests
  --

  -- When we have specific files to deal with, only use explicit configs
  -- (or just the std one)
  if options["names"] then
    checkconfigs = options["config"] or { stdconfig }
  else
    checkconfigs = options["config"] or checkconfigs
  end

  if #checkconfigs == 1 and
    checkconfigs[1] ~= "build" and
    (options["target"] == "check" or options["target"] == "save" or options["target"] == "clean") then
    local config = "./" .. checkconfigs[1]:gsub(".lua$","") .. ".lua"
    if fileexists(config) then
      local savedtestfiledir = testfiledir
      dofile(config)
      testdir = testdir .. "-" .. checkconfigs[1]
      -- Reset testsuppdir if required
      if savedtestfiledir ~= testfiledir and
        testsuppdir == savedtestfiledir .. "/support" then
        testsuppdir = testfiledir .. "/support"
      end
    else
      print("Error: Cannot find configuration " ..  checkconfigs[1])
      exit(1)
    end
  end
end

---Do the checks when different configurations were given.
---@param _ENV table
local function do_multi_check(_ENV)
  if options["target"] == "check" then
    if #checkconfigs > 1 then
      local error_level = 0
      local failed = {}
      for i = 1, #checkconfigs do
        options["config"] = { checkconfigs[i] }
        error_level = call({"."}, "check", options)
        if error_level ~= 0 then
          if options["halt-on-error"] then
            exit(1)
          else
            insert(failed,checkconfigs[i])
          end
        end
      end
      if next(failed) then
        for _,config in ipairs(failed) do
          print("Failed tests for configuration " .. config .. ":")
          print("\n  Check failed with difference files")
          local testdir = testdir
          if config ~= "build" then
            testdir = testdir .. "-" .. config
          end
          for _,i in ipairs(filelist(testdir,"*" .. os_diffext)) do
            print("  - " .. testdir .. "/" .. i)
          end
          print("")
        end
        exit(1)
      else
        -- Avoid running the 'main' set of tests twice
        exit(0)
      end
    end
  end  
end

--
-- The overall main function
--

local function main(_ENV)
  local target = options.target
  local names  = options.name
  -- Deal with unknown targets up-front
  if not target_list[target] then
    help()
    exit(1)
  end
  local error_level = 0
  if module == "" then
    modules = modules or listmodules()
    if target_list[target].bundle_func then
      error_level = target_list[target].bundle_func(names)
    else
      -- Detect all of the modules
      if target_list[target].bundle_target then
        target = "bundle" .. target
      end
      error_level = call(modules,target)
    end
  else
    if target_list[target].pre then
     error_level = target_list[target].pre(names)
     if error_level ~= 0 then
       exit(1)
     end
    end
    error_level = target_list[target].func(names)
  end
  -- All done, finish up
  if error_level ~= 0 then
    exit(1)
  else
    exit(0)
  end
end

---@export
return {
  _TYPE     = "module",
  _NAME     = "file-functions",
  _VERSION  = "2021/01/28",
  do_help   = do_help,
  setup     = setup,
  check_env = check_env,
  do_multi_check = do_multi_check,
  main = main,
}
