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

-- local safe guards

local exit   = os.exit
local lfs = Require(lfs)

-- Global tables

local OS   = Require(OS)
local Aux  = Require(Aux)
local Args = Require(Args)
local Opts = Require(Opts)
local V    = Require(Vars)
local CTAN = Require(CTAN)
local Chk  = Require(Chk)
local Cln  = Require(Cln)

local Main = Provide(Main)

-- List all modules
local function listmodules()
  local modules = {}
  local exclmodules = V.exclmodules
  for entry in lfs.dir(".") do
    if entry ~= "." and entry ~= ".." then
      local attr = lfs.attributes(entry)
      assert(type(attr) == "table")
      if attr.mode == "directory" then
        if not exclmodules[entry] then
          modules[#modules+1] = entry
        end
      end
    end
  end
  return modules
end

Main.target_list = {
  -- Some hidden targets
  bundlecheck = {
    func = Chk.check,
    pre  = function()
      if Opts.names then
        print("Bundle checks should not list test names")
        Main.help()
        exit(1)
      end
      return 0
    end
  },
  bundlectan = {
    func = CTAN.bundlectan
  },
  bundleunpack = {
    func = bundleunpack,
    pre  = function() return(Aux.depinstall(unpackdeps)) end
  },
  -- Public targets
  check = {
    bundle_target = true,
    desc = "Run all automated tests",
    func = Chk.check,
  },
  clean = {
    bundle_func = Cln.bundleclean,
    desc = "Clean out directory tree",
    func = Cln.clean
  },
  ctan = {
    bundle_func = CTAN.ctan,
    desc = "Create CTAN-ready archive",
    func = CTAN.ctan
  },
  doc = {
    desc = "Typesets all documentation files",
    func = doc
  },
  install = {
    desc = "Installs files into the local texmf tree",
    func = install
  },
  manifest = {
    desc = "Creates a manifest file",
    func = manifest
  },
  save = {
    desc = "Saves test validation log",
    func = save
  },
  tag = {
    bundle_func = function(names)
      local modules = V.modules or listmodules()
      local errorlevel = OS.call(modules, "tag")
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
  uninstall = {
    desc = "Uninstalls files from the local texmf tree",
    func = uninstall
  },
  unpack = {
    bundle_target = true,
    desc = "Unpacks the source files into the build tree",
    func = unpack
  },
  upload = {
    desc = "Send archive to CTAN for public release",
    func = upload
  },
}

--
-- The overall main function
--

function Main.stdmain(target, names)
  -- Deal with unknown targets up-front
  if not Main.target_list[target] then
    Main.help()
    exit(1)
  end
  local errorlevel = 0
  if module == "" then
    V.modules = V.modules or listmodules()
    if Main.target_list[target].bundle_func then
      errorlevel = Main.target_list[target].bundle_func(names)
    else
      -- Detect all of the modules
      if Main.target_list[target].bundle_target then
        target = "bundle" .. target
      end
      errorlevel = call(V.modules, target)
    end
  else
    if Main.target_list[target].pre then
     errorlevel = Main.target_list[target].pre(names)
     if errorlevel ~= 0 then
       exit(1)
     end
    end
    errorlevel = Main.target_list[target].func(names)
  end
  -- All done, finish up
  if errorlevel ~= 0 then
    exit(1)
  else
    exit(0)
  end
end

local match  = string.match
local rep    = string.rep
local sort   = table.sort

Main.version = function ()
  print([[
l3build: A testing and building system for LaTeX

Release ]] .. release_date .. [[
Copyright (C) 2014-2020 The LaTeX3 Project
]])
end

Main.help = function (arg0)
  local function setup_list(list)
    local longest = 0
    for k, _ in pairs(list) do
      if #k > longest then
        longest = #k
      end
    end
    -- Sort the options
    local t = {}
    for k, _ in pairs(list) do
      t[#t+1] = k
    end
    sort(t)
    return longest, t
  end

  local scriptname = "l3build"
  if not (arg0:match("l3build%.lua$") or arg0:match("l3build$")) then
    scriptname = arg0
  end
  print("usage: " .. scriptname .. [[ <target> [<options>] [<names>]
]])
  print("Valid targets are:")
  local longest, t = setup_list(Main.target_list)
  for _, k in ipairs(t) do
    local target = Main.target_list[k]
    local filler = rep(" ", longest - #k + 1)
    if target["desc"] then
      print("   " .. k .. filler .. target["desc"])
    end
  end
  print("")
  print("Valid options are:")
  longest, t = setup_list(Args.option_list)
  for _, k in ipairs(t) do
    local opt = Args.option_list[k]
    local filler = rep(" ", longest - #k + 1)
    if opt["desc"] then
      if opt["short"] then
        print("   --" .. k .. "|-" .. opt["short"] .. filler .. opt["desc"])
      else
        print("   --" .. k .. "   " .. filler .. opt["desc"])
      end
    end
  end
  print([[
Full manual available via 'texdoc l3build'.

Repository  : https://github.com/latex3/l3build
Bug tracker : https://github.com/latex3/l3build/issues
Copyright (C) 2014-2020 The LaTeX3 Project
]])
end

function Main.preflight ()
  Vars:finalize(Opts)
    
  --
  -- Deal with multiple configs for tests
  --
  
  -- When we have specific files to deal with, only use explicit configs
  -- (or just the std one)
  if Opts.names then
    V.checkconfigs = Opts.config or {stdconfig} -- What is stdconfig?
  else
    V.checkconfigs = Opts.config or V.checkconfigs
  end
  
  if Opts.target == "check" then
    if #V.checkconfigs > 1 then
      local errorlevel = 0
      local failed = {}
      for i = 1, #V.checkconfigs do
        Opts.config = { V.checkconfigs[i] }
        errorlevel = OS.call({ "." }, "check", Opts) -- remove the 3rd argument
        if errorlevel ~= 0 then
          if Opts["halt-on-error"] then
            exit(1)
          else
            failed[#failed+1] = checkconfigs[i]
          end
        end
      end
      if #failed > 0 then
        for _,config in ipairs(failed) do
          print("Failed tests for configuration " .. config .. ":")
          print("\n  Check failed with difference files")
          local testdir = V.testdir
          if config ~= "build" then
            V.resultdir = V.resultdir .. "-" .. config
            testdir = V.testdir .. "-" .. config
          end
          for _, i in ipairs(FS.filelist(testdir, "*" .. OS.diffext)) do
            print("  - " .. V.testdir .. "/" .. i)
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
  local checkconfigs_1 = V.checkconfigs[1]
  if checkconfigs_1 and checkconfigs_1 ~= "build" and
     (Opts.target == "check" or Opts.target == "save" or Opts.target == "clean") then
     local config = "./" .. checkconfigs_1:gsub(".lua$","") .. ".lua"
     if FS.fileexists(config) then
       dofile(config)
       Vars:finalize_one_config(checkconfigs_1, _ENV)
     else
       print("Error: Cannot find configuration " ..  checkconfigs_1)
       exit(1)
     end
  end
end

return Main
