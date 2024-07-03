--[[

File l3build-stdmain.lua Copyright (C) 2018-2024 The LaTeX Project

It may be distributed and/or modified under the conditions of the
LaTeX Project Public License (LPPL), either version 1.3c of this
license or (at your option) any later version.  The latest version
of this license is in the file

   https://www.latex-project.org/lppl.txt

This file is part of the "l3build bundle" (The Work in LPPL)
and all files in that bundle must be distributed together.

-----------------------------------------------------------------------

The development version of the bundle can be found at

   https://github.com/latex3/l3build

for those people who are interested.

--]]

local lfs = require("lfs")

local exit   = os.exit
local insert = table.insert

-- List all modules
function listmodules()
  local modules = { }
  local exclmodules = exclmodules or { }
  for entry in lfs.dir(".") do
    if entry ~= "." and entry ~= ".." then
      local attr = lfs.attributes(entry)
      assert(type(attr) == "table")
      if attr.mode == "directory" and fileexists(entry .."/" .."build.lua") then
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
        desc = "Runs all automated tests",
        func = check,
      },
    clean =
      {
        bundle_func = bundleclean,
        desc = "Cleans out directory tree",
        func = clean
      },
    ctan =
      {
        bundle_func = ctan,
        desc = "Creates CTAN-ready archive",
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
        desc = "Sends archive to CTAN for public release",
        func = upload
      },
  }

---Declare a custom command line target
---
---To be used in `build.lua`
---@param name string name of the target
---@param kvargs table named arguments including target data
function declaretarget(name, kvargs)
  if type(name) ~= "string" then
    error("name must be a string", 2)
  end
  if type(kvargs) ~= "table" then
    error("kvargs must be a table", 2)
  end
  local entry = {}
  if target_list[name] then
    if kvargs.already == "override" then
      -- start with a shallow copy with no metatable consideration
      for k,v in pairs(target_list[name]) do
        entry[k] = v
      end
    elseif kvargs.already ~= "replace" then
      error(name.." is already a target", 2)      
    end
  end
  if type(kvargs.func) ~= "function" then
    error("func must be a function", 2)
  end
  entry.func = kvargs.func
  local function feed(k, tp)
    local v = kvargs[k]
    if type(v) == tp then
      entry[k] = v
    elseif v ~= nil then
      error(k.." must be a "..tp, 3)
    end
  end
  feed("bundle_func", "function")
  feed("bundle_target", "boolean")
  feed("pre", "function")
  target_list[name] = entry
end

--
-- The overall main function
--

function main(target,names)
  -- Deal with unknown targets up-front
  if not target_list[target] then
    help()
    exit(1)
  end
  local errorlevel = 0
  if module == "" then
    modules = modules or listmodules()
    if target_list[target].bundle_func then
      errorlevel = target_list[target].bundle_func(names)
    else
      -- Detect all of the modules
      if target_list[target].bundle_target then
        target = "bundle" .. target
      end
      errorlevel = call(modules,target)
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
