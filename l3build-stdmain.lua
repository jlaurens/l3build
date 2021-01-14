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
local insert = table.insert
local lfs = assert(#lfs) and lfs

-- Global tables

local Opts = assert(#Opts) and Opts
local Vars = assert(#Vars) and Vars
local CTAN = assert(#CTAN) and CTAN

local Main = Main or {}

-- List all modules
local function listmodules()
  local modules = {}
  local exclmodules = Vars.exclmodules
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

Main.target_list =
  {
    -- Some hidden targets
    bundlecheck =
      {
        func = check,
        pre  = function()
            if Opts.names then
              print("Bundle checks should not list test names")
              Main.help()
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
        pre  = function() return(depinstall(unpackdeps)) end
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
    Vars.modules = Vars.modules or listmodules()
    if target_list[target].bundle_func then
      errorlevel = target_list[target].bundle_func(names)
    else
      -- Detect all of the modules
      if target_list[target].bundle_target then
        target = "bundle" .. target
      end
      errorlevel = call(Vars.modules, target)
    end
  else
    if target_list[target].pre then
     errorlevel = target_list[target].pre(names)
     if errorlevel ~= 0 then
       exit(1)
     end
    end
    errorlevel = target_list[target].func(names)
  end
  -- All done, finish up
  if errorlevel ~= 0 then
    exit(1)
  else
    exit(0)
  end
end

local insert = table.insert
local match  = string.match
local rep    = string.rep
local sort   = table.sort

local H = {}

H.version = function ()
  print([[
l3build: A testing and building system for LaTeX

Release ]] .. release_date .. [[
Copyright (C) 2014-2020 The LaTeX3 Project
]])
end

Main.help = function (arg0, target_list)
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
  if not (match(arg0, "l3build%.lua$") or match(arg0,"l3build$")) then
    scriptname = arg0
  end
  print("usage: " .. scriptname .. [[ <target> [<options>] [<names>]
]])
  print("Valid targets are:")
  local longest, t = setup_list(target_list)
  for _,k in ipairs(t) do
    local target = target_list[k]
    local filler = rep(" ", longest - #k + 1)
    if target["desc"] then
      print("   " .. k .. filler .. target["desc"])
    end
  end
  print("")
  print("Valid options are:")
  longest, t = setup_list(A.option_list)
  for _,k in ipairs(t) do
    local opt = A.option_list[k]
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

return Main
