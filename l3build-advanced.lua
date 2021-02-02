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

print("l3build advanced mode")

-- Get the shared l3b

local path = package.searchpath(
  "?",
  l3b.launch_dir .. "l3build-boot.lua"
)
if path then -- path found
  l3b = dofile(path)
else
  l3b = l3b.l3build_require("shared")
end


kpse.set_program_name("kpsewhich")
local build_kpse_path = match(lookup("l3build.lua"),"(.*[/])")
local l3b = require(lookup(
  "l3build-shared.lua",
  { path = build_kpse_path }
))

l3b.advanced = true -- this will help to clearly identify what is advanced
l3b.debug_level = 0 -- Complement to options.debug, > 0 when debug info is required


-- We have just switched to advanced mode
-- we have consume arg[1] and must shift left the other arguments
-- to retrieve the normal CLI arguments order

l3b.shift_left(arg, 1)

-- continue the normal way

-- Minimal code to do basic checks
l3b.require("arguments")
local cli = l3b.require("arguments")
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

l3b.require("help")

l3b.require("file-functions")
l3b.require("typesetting")
l3b.require("aux")
l3b.require("clean")
l3b.require("check")
l3b.require("ctan")
l3b.require("install")
l3b.require("unpack")
l3b.require("manifest")
l3b.require("manifest-setup")
l3b.require("tagging")
l3b.require("upload")
l3b.require("stdmain")

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
l3b.require("variables")

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
