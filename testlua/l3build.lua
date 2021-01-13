#!/usr/bin/env texlua

--[[

File l3build.lua Copyright (C) 2014-2020 The LaTeX3 Project

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

-- Table for the top building material
local B = {}

-- Table for the methods
local M = {}

-- Local access to functions

local ipairs           = ipairs
local insert           = table.insert
local lookup           = kpse.lookup
local match            = string.match
local gsub             = string.gsub
local next             = next
local print            = print
local exit             = os.exit

-- l3build library loader
kpse.set_program_name("kpsewhich")
local l_path = match(lookup("l3build.lua"),"(.*[/])")
local function l_require(s)
  require(lookup("l3build-"..s..".lua", { path = l_path } ) )
end

-- Table for the tools
local T = l_require("file-functions")

-- define global functions and friends in that order.
-- Table for the command line options
local O = l_require("arguments")

l_require("help")

-- This has to come after stdmain(),
-- and that has to come after the functions are defined
if options.target == "help" then
  help()
  exit(0)
elseif options.target == "version" then
  version()
  exit(0)
end

l_require("typesetting")
l_require("aux")
l_require("clean")
l_require("check")
l_require("ctan")
l_require("install")
l_require("unpack")
l_require("manifest")
l_require("manifest-setup")
l_require("tagging")
l_require("upload")
l_require("stdmain")

-- Load configuration file if running as a script
if match(arg[0], "l3build$") or match(arg[0], "l3build%.lua$") then
  if fileexists("build.lua") then
    dofile("build.lua")
  else
    print("Error: Cannot find configuration build.lua")
    exit(1)
  end
end

-- Load standard settings for variables:
-- comes after any user versions
-- Table for the variables
local V = l_require("variables")

-- Tidy up the epoch setting
-- Force an epoch if set at the command line
-- Must be done after loading variables, etc.
if options.epoch then
  epoch           = options.epoch
  forcecheckepoch = true
  forcedocepoch   = true
end
normalise_epoch()

-- Sanity check
check_engines()

--
-- Deal with multiple configs for tests
--

-- When we have specific files to deal with, only use explicit configs
-- (or just the std one)
if options.names then
  checkconfigs = options.config or {stdconfig}
else
  checkconfigs = options.config or checkconfigs
end

if options.target == "check" then
  if #checkconfigs > 1 then
    local errorlevel = 0
    local opts = options
    local failed = { }
    for i = 1, #checkconfigs do
      opts.config = {checkconfigs[i]}
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
   (options.target == "check" or options.target == "save" or options.target == "clean") then
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
-- Allow main function to be disabled 'higher up'
main = main or stdmain

main(options.target, options.names)
