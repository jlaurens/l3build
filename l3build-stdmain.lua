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

local exit = os.exit
local rep  = string.rep
local sort = table.sort

local lfs  = require('lfs')

local L3B = L3B
local Opts = Opts

-- Global tables

local OS   = L3B.require('OS')
local FS   = L3B.require('FS')
local Aux  = L3B.require('Aux')
local Args = L3B.require('Args')
local V    = L3B.require('Vars')
local CTAN = L3B.require('CTAN')
local Chk  = L3B.require('Chk')
local Cln  = L3B.require('Cln')
local Pack = L3B.require('Pack')

-- Declare module

local Main = L3B.provide('Main')

-- List all modules
local function get_test_modules()
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

Main.target_defs = { -- global target_list
  -- Some hidden targets
  bundlecheck = {
    func = Chk.check,
    pre  = function ()
      if Opts.names then
        L3B.warning("Bundle checks should not list test names")
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
    func = V.bundleunpack,
    pre  = function () return Aux.depinstall(V.unpackdeps) end
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
    bundle_func = function (names)
      local modules = V.modules or get_test_modules()
      local error_n = Aux.call(modules, "tag", Opts)
      -- Deal with any files in the bundle dir itself
      if error_n == 0 then
        error_n = tag(names)
      end
      return error_n
    end,
    desc = "Updates release tags in files",
    func = tag,
    pre  = function (names)
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

function Main.other(target, opts)
  local names = opts.names
  -- Deal with unknown targets up-front
  local def_t = Main.target_defs[target]
  if not def_t then
    return
  end
  local error_level = 0
  if module == "" then
    V.modules = V.modules or get_test_modules()
    if def_t.bundle_func then
      error_level = def_t.bundle_func(names)
    else
      -- Detect all of the modules
      if def_t.bundle_target then
        target = "bundle" .. target
      end
      error_level = Aux.call(V.modules, target, Opts)
    end
  else
    if def_t.pre then
     error_level = def_t.pre(names)
     if error_level ~= 0 then
       exit(1)
     end
    end
    error_level = def_t.func(names)
  end
  -- All done, finish up
  if error_level ~= 0 then
    exit(1)
  else
    return true
  end
end

function Main.version()
  print([[
l3build: A testing and building system for LaTeX

Release ]] .. release_date .. [[
Copyright (C) 2014-2020 The LaTeX3 Project
]])
end

function Main.help(topic)
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

  local arg_0 = Args.arg[0]
  local scriptname =
    not (arg_0:match("l3build%.lua$") or arg_0:match("l3build$"))
      and "l3build"
      or  arg_0
  print("usage: " .. scriptname .. [[ <target> [<options>] [<names>]
]])
  print("Valid targets are:")
  local longest, t = setup_list(Main.target_defs)
  for _, k in ipairs(t) do
    local target = Main.target_defs[k]
    local filler = rep(" ", longest - #k + 1)
    if target.desc then
      print("   " .. k .. filler .. target.desc)
    end
  end
  print("")
  print("Valid options are:")
  longest, t = setup_list(Args.list)
  for _, k in ipairs(t) do
    local opt = Args.list[k]
    local filler = rep(" ", longest - #k + 1)
    if opt.desc then
      if opt.short then
        print("   --" .. k .. "|-" .. opt.short .. filler .. opt.desc)
      else
        print("   --" .. k .. "   " .. filler .. opt.desc)
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

function Main.expose_globals(target, opts)
  L3B.expose(OS)
  L3B.expose(FS)
  L3B.expose(V)
  L3B.unexpose() -- global internals are no longer available
  _ENV.target = target
  _ENV.options = opts
  -- compatibility code: deprecated `options.target`
  if not opts.getmetatable() and not opts.target then
    setmetatable(opts, {
      __index = function (self, key)
        if key == 'target' then
          if not self.already_deprecated__ then
            self.already_deprecated__ = true
            L3B.info('`options.target` is deprecated, use `target` instead.')
          end
          return target
        end
      end
    })
  end
end

function Main.dofile_build()
  local arg_0 = Args.arg[0]
  if arg_0:match("l3build$") or arg_0:match("l3build%.lua$") then
    -- Look for some configuration details
    if FS.fileexists("build.lua") then
      dofile("build.lua")
    else
      L3B.error(1, "Error: Cannot find configuration build.lua")
    end
  end
end

function Main.finalize_one_config()
  local checkconfigs_1 = V.checkconfigs[1]
  if checkconfigs_1 and checkconfigs_1 ~= "build" and
    (target == "check" or target == "save" or target == "clean") then
    local build_lua = "./" .. checkconfigs_1:gsub(".lua$","") .. ".lua"
    if FS.fileexists(build_lua) then
      dofile(build_lua)
      V:finalize_one_config(checkconfigs_1, _ENV)
    else
      L3B.error(1, "Cannot find configuration " ..  checkconfigs_1)
    end
  end
end

function Main.finalize(opts)
  V:finalize(opts)
  Chk.check_many()
  Main.finalize_one_config()
  Pack:finalize()
end

function Main.main(opts)
  opts = opts or Opts
  local target = Args:parse(arg, opts)
  if target == "help" then
    Main.help(opts.help)
  elseif target == "version" then
    Main.version()
  elseif target then
    Main.expose_globals(target, opts)
    Main.dofile_build()
    Main.finalize(opts)
    if not Main.other(target, opts) and not Main.custom(target, opts) then
      Main.help()
    end
  else -- no target
    Main.help()
  end
end

return Main
