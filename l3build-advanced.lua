#!/usr/bin/env texlua

--[[

File l3build-advanced.lua Copyright (C) 2014-2020 The LaTeX3 Project

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

-- wrapping code chunks in a if l3b.advanced ... end block must have 0 impact on normal code.

-- -- Version information
-- release_date = "2020-06-04"

-- File operations are aided by the LuaFileSystem module
local lfs = require("lfs")

-- Local access to functions

local assert           = assert
local ipairs           = ipairs
local insert           = table.insert
local lookup           = kpse.lookup
local match            = string.match
local gsub             = string.gsub
local next             = next
local print            = print
local select           = select
local tonumber         = tonumber
local exit             = os.exit

-- l3build setup and functions
kpse.set_program_name("kpsewhich")
build_kpse_path = match(lookup("l3build.lua"),"(.*[/])")
local function build_require(s)
  return require(lookup("l3build-"..s..".lua", { path = build_kpse_path } ) )
end

print("l3build advanced mode")
local l3b = l3b
l3b.advanced = true -- this will help to clearly identify what is advanced
l3b.debug_level = 0 -- Complement to options.debug, > 0 when debug info is required

-- We have just switched to advanced mode
-- we have consume arg[1] and must shift left the other arguments
-- to retrieve the normal CLI arguments order
-- consume will be also used when defining othe advanced options

local function consume(k)
  assert(k>0)
  -- arg is assumed to be a sequence
  -- consume elements 1, ... k of arg
  for i = 1, #arg do
    arg[i] = arg[k + i]
  end
  -- this for loop is equivalent to
  -- local max = #arg
  -- for i = 1, max - k do
  --   arg[i] = arg[k + i]
  -- end
  -- for i = max - k + 1, max do
  --   arg[i] = nil
  -- end
  -- -- because #arg is a border and arg[0] ~= nil such that
  -- -- arg[#arg] ~= nil and arg[#arg+1] == nil
  -- -- As arg is a sequence we have arg[#arg+i] == nil for all positive i
end

consume(1)

-- continue the normal way

-- Minimal code to do basic checks
build_require("arguments")
local cli = build_require("arguments")
option_list = cli.defs

-- parsing the CLI arguments must be done at will.
-- there are 2 possibilities
-- 1) a global `declare_option` function used once in `build.lua`
--    At the end this function automatically parses the CLI arguments
--    and sets everything up
-- 2) a global `declare_option` function used as many times as required
--    plus a global `parse_arguments` fired once afterwards.
-- Option 2 is used

function parse_arguments()
  -- One shot function
  parse_arguments = function () end
  -- disable declare_option
  declare_option = function ()
    error("declare_option cannot be used after parse_arguments")
  end

-- in next lines, only the indentation should change
-- this is not indented yet to let diff focus on real changes

options = cli.parse(arg)

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
build_require("stdmain")

-- This has to come after stdmain(),
-- and that has to come after the functions are defined
if options["target"] == "help" then
  help()
  exit(0)
elseif options["target"] == "version" then
  version()
  exit(0)
end

-- Allow main function to be disabled 'higher up', can be moved below
main = main or stdmain

end -- end of parse_arguments

-- Load configuration file if running as a script
if match(arg[0], "l3build$") or match(arg[0], "l3build%.lua$") then
  -- Look for some configuration details
  if package.searchpath("build", "?.lua") then -- fileexists is not available
    dofile("build.lua")
  else
    print("Error: Cannot find configuration build.lua")
    exit(1)
  end
end

parse_arguments() -- just in case

-- Load standard settings for variables:
-- comes after any user versions
build_require("variables")

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
