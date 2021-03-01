--[[

File l3build-stdmain.lua Copyright (C) 2018-2020 The LaTeX Project

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

local lfs = require("lfs")
local lfs_dir = lfs.dir
local attributes = lfs.attributes

local exit   = os.exit
local append = table.insert

---@type utlib_t
local utlib = require("l3b.utillib")
local extend_with = utlib.extend_with

---@type l3b_aux_t
local l3b_aux     = require("l3b.aux")
local call        = l3b_aux.call
local dep_install = l3b_aux.dep_install

---@type l3b_help_t
local l3b_help = require("l3b.help")
local help = l3b_help.help

-- List all modules
local function listmodules()
  local modules = {}
  local exclmodules = exclmodules or {}
  for entry in lfs_dir(".") do
    if entry ~= "." and entry ~= ".." then
      if attributes(entry, "mode") == "directory" then
        if not exclmodules[entry] then
          append(modules, entry)
        end
      end
    end
  end
  return modules
end

local target_list =
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
        pre  = function()
          return dep_install(unpackdeps)
        end
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
    unpack =
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

local function main(target, names)
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
      error_level = call(modules, target)
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

-- this is the map to export function symbols to the global space
local global_symbol_map = {
  call = call,
  target_list = target_list,
}

--[=[ Export function symbols ]=]
extend_with(_G, global_symbol_map)
-- [=[ ]=]

---@class l3b_main_t
---@field main function
---@field target_list table<string, table>

return {
  global_symbol_map = {},
  main              = main,
  target_list       = target_list,
}
