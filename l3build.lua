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

-- Version information
release_date = "2020-06-04"

-- File operations are aided by the LuaFileSystem module
local lfs = require("lfs")

-- Local access to functions

local assert           = assert
local ipairs           = ipairs
local insert           = table.insert
local kpse             = kpse
local lookup           = kpse.lookup
local match            = string.match
local gsub             = string.gsub
local next             = next
local print            = print
local select           = select
local tonumber         = tonumber
local exit             = os.exit

-- Possibly switch to advanced or unit mode.
-- This is never executed in normal mode.
if arg[1] == "--advanced"
or arg[1] == "--unit"
then
  -- This script can be executed as
  -- x1) `l3build blablabla`
  -- x2) `texlua l3build.lua blablabla`
  -- x3) `texlua path to l3build.lua blablabla`
  -- x4) imported from some other script,
  --     typically the main package dir or a subfolder
  -- We would like to identify the subfolder case.
  -- x1 is the normal way, x4 is|was used by latex2e for example
  -- x2 and x3 can be used by l3build developers
  -- who want a full control of the launched tool.
  --[[ For average users: copy paste this one below
  kpse.set_program_name("kpsewhich")
  dofile(kpse.lookup("l3build.lua"):match(".*/") .. "l3build-boot.lua")
  require("l3build-" .. name)
  --]]
  kpse.set_program_name("kpsewhich")
  local kpse_dir = kpse.lookup("l3build.lua"):match(".*/")
  local launch_dir = arg[0]:match("^(.*/).*%.lua$") or "./"
  local path = package.searchpath(
    "?", launch_dir .. "l3build-boot.lua"
  )  or kpse_dir   .. "l3build-boot.lua"
  local boot = dofile(path)
  local mode = arg[1]:sub(3) -- "advanced" or "unit"
  boot.shift_left(arg, 1)
  os.exit(require("l3build-" .. mode):run(arg))
end

boot = {
  debug_level = 0
}
-- l3build setup and functions
kpse.set_program_name("kpsewhich")
build_kpse_path = match(lookup("l3build.lua"),"(.*[/])")
local function builtin_require(s)
  return require(lookup("l3build-"..s..".lua", { path = build_kpse_path } ) )
end

-- Minimal code to do basic checks
builtin_require("arguments")
local cli = builtin_require("arguments")
option_list = cli.defs -- exposed
options = cli.parse(arg)

builtin_require("help")

builtin_require("file-functions")
builtin_require("typesetting")
builtin_require("aux")
builtin_require("clean")
builtin_require("check")
builtin_require("ctan")
builtin_require("install")
builtin_require("unpack")
builtin_require("manifest")
builtin_require("manifest-setup")
builtin_require("tagging")
builtin_require("upload")
builtin_require("stdmain")

-- This has to come after stdmain(),
-- and that has to come after the functions are defined
if options["target"] == "help" then
  help()
  exit(0)
elseif options["target"] == "version" then
  version()
  exit(0)
end

-- Allow main function to be disabled 'higher up'
main = main or stdmain

-- Load configuration file if running as a script
if match(arg[0], "l3build$") or match(arg[0], "l3build%.lua$") then
  -- Look for some configuration details
  if fileexists("build.lua") then
    dofile("build.lua")
  else
    print("Error: Cannot find configuration build.lua")
    exit(1)
  end
end

-- Load standard settings for variables:
-- comes after any user versions
builtin_require("variables")

-- Ensure that directories are 'space safe'
maindir       = escapepath(maindir)
docfiledir    = escapepath(docfiledir)
sourcefiledir = escapepath(sourcefiledir)
supportdir    = escapepath(supportdir)
testfiledir   = escapepath(testfiledir)
testsuppdir   = escapepath(testsuppdir)
builddir      = escapepath(builddir)
distribdir    = escapepath(distribdir)
localdir      = escapepath(localdir)
resultdir     = escapepath(resultdir)
testdir       = escapepath(testdir)
typesetdir    = escapepath(typesetdir)
unpackdir     = escapepath(unpackdir)

-- Tidy up the epoch setting
-- Force an epoch if set at the command line
-- Must be done after loading variables, etc.
if options["epoch"] then
  epoch           = options["epoch"]
  forcecheckepoch = true
  forcedocepoch   = true
end
epoch = normalise_epoch(epoch)

-- Sanity check
check_engines()

--
-- Deal with multiple configs for tests
--

-- When we have specific files to deal with, only use explicit configs
-- (or just the std one)
if options["names"] then
  checkconfigs = options["config"] or {stdconfig}
else
  checkconfigs = options["config"] or checkconfigs
end

if options["target"] == "check" then
  if #checkconfigs > 1 then
    local errorlevel = 0
    local opts = options
    local failed = { }
    for i = 1, #checkconfigs do
      opts["config"] = {checkconfigs[i]}
      errorlevel = call({"."}, "check", opts)
      if errorlevel ~= 0 then
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
          resultdir = resultdir .. "-" .. config
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
if #checkconfigs == 1 and
   checkconfigs[1] ~= "build" and
   (options["target"] == "check" or options["target"] == "save" or options["target"] == "clean") then
   local config = "./" .. gsub(checkconfigs[1],".lua$","") .. ".lua"
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

-- Call the main function
main(options["target"], options["names"])
