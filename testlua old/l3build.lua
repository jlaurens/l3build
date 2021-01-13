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

local L3 = L3 or {}

L3.release_date = release_date
L3.lfs = require("lfs")

-- l3build library loader
local kpse = kpse or {
  set_program_name = function (s) end,
  lookup = function(s)
    return s:match('/.*') or ('./' .. s)
  end
}
kpse.set_program_name("kpsewhich")
L3.set_program_name = kpse.set_program_name
L3.lookup = kpse.lookup
L3.var_value = kpse.var_value
L3.set_program_name("kpsewhich")
L3.dir_path = L3.lookup("l3build.lua"):match(".*/")

L3.require = function (self, s)
  local __s = '__' .. s
  if not self[__s] then
    self.__s = require(self.lookup("l3build-"..s..".lua", { path = self.dir_path } ) ) or true
  end
  return self[__s]
end

-- define global functions and friends in that order.
L3:require("options")
L3:require("help")

local options = L3:parse_arg(arg)

-- This has to come after stdmain(),
-- and that has to come after the functions are defined
if options.target == "help" then
  L3.help()
  os.exit(0)
elseif options.target == "version" then
  L3.version()
  os.exit(0)
end

local FF = L3:require("file-functions")

-- Load configuration file if running as a script
if arg[0]:match("l3build(%.lua)?$") then
  if FF.fileexists("build.lua") then
    dofile("build.lua")
  else
    print("Error: Cannot find configuration build.lua")
    os.exit(1)
  end
end

-- Load standard settings for variables:
-- comes after any user versions
local V = L3:require("variables")

-- Sanity check
V.check_engines(options)
V.sanitize_epoch(options)
V.sanitize_check_config(options)
--
-- Deal with multiple configs for tests
--

L3:require("aux")
L3:require("check")

if options.target == "check" then
  if #V.checkconfigs > 1 then
    local errorlevel = 0
    local failed = { }
    for _,config in ipairs(V.checkconfigs) do
      options.config = {config}
      errorlevel = L3:call({"."}, "check")
      if errorlevel ~= 0 then
        if options["halt-on-error"] then
          os.exit(1)
        else
          failed[#failed+1] = config
        end
      end
    end
    if next(failed) then
      for _,config in ipairs(failed) do
        print("Failed tests for configuration " .. config .. ":")
        print("\n  Check failed with difference files")
        local testdir = V.testdir
        if config ~= "build" then
          testdir = testdir .. "-" .. config
        end
        for _,i in ipairs(FF.filelist(testdir,"*" .. FF.os_diffext)) do
          print("  - " .. testdir .. "/" .. i)
        end
        print("")
      end
      os.exit(1)
    else
      -- Avoid running the 'main' set of tests twice
      os.exit(0)
    end
  end
end
if #V.checkconfigs == 1 and
   V.checkconfigs[1] ~= "build" and
   (options.target == "check" or options.target == "save" or options.target == "clean") then
   local config = "./" .. V.checkconfigs[1]:gsub(".lua$","") .. ".lua"
   if FF.fileexists(config) then
     local savedtestfiledir = V.testfiledir
     dofile(config)
     V.testdir = V.testdir .. "-" .. V.checkconfigs[1]
     -- Reset testsuppdir if required
     if savedtestfiledir ~= V.testfiledir and
       V.testsuppdir == savedtestfiledir .. "/support" then
        V.testsuppdir = V.testfiledir .. "/support"
     end
   else
     print("Error: Cannot find configuration " ..  V.checkconfigs[1])
     os.exit(1)
   end
end

-- Call the main function
L3:require("main")
L3:main()
os.exit(0)

L3:require("typesetting")
L3:require("clean")
L3:require("ctan")
L3:require("install")
L3:require("unpack")
L3:require("manifest")
L3:require("manifest-setup")
L3:require("tagging")
L3:require("upload")
