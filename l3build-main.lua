#!/usr/bin/env texlua

--[[

File l3build-main.lua Copyright (C) 2014-2020 The LaTeX Project

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

---@module l3build-main

local exit = os.exit

require("l3b-pathlib") -- string div

---@type utlib_t
-- local utlib = require("l3b-utillib")

--[===[ DEBUG flags ]===]
---@type oslib_t
local oslib = require("l3b-oslib")
oslib.Vars.debug.run = true
--[===[ DEBUG flags end ]===]

---@type fslib_t
local fslib = require("l3b-fslib")
local set_tree_excluder = fslib.set_tree_excluder

local l3build = require("l3build")
local in_document = l3build.in_document
local work_dir    = l3build.work_dir
local is_main     = l3build.is_main

---@type l3b_cli_t
local l3b_cli = require("l3build-cli")

---@type l3b_targets_t
local l3b_targets = require("l3b-targets")
local process     = l3b_targets.process

---@type l3b_aux_t
local l3b_aux = require("l3build-aux")
local call    = l3b_aux.call
  
local function run()
  fslib.set_working_directory(l3build.work_dir)

  -- Terminate here if in document mode
  if in_document then
    return l3build
  end

  --[=[ Dealing with options ]=]
  l3b_cli.register_builtin_options()
  l3b_cli.register_custom_options(work_dir)
  l3b_cli.register_targets()

  l3build.options = l3b_cli.parse(arg, function (arg_i)
    -- Private special debugging options "--debug-<key>"
    local key = arg_i:match("^debug%-(%w[%w%d_-]*)")
    if key then
      l3build.debug[key:gsub("-", "_")] = true
      return true
    end
  end)

  ---@type l3b_globals_t
  local l3b_globals = require("l3build-globals")

  l3b_globals.export()

  local options   = l3build.options

  local debug     = options.debug

  if debug then -- activate the private special debugging options
    require("l3b-oslib").Vars.debug.run = l3build.debug.run -- options --debug-run
    fslib.Vars.debug.copy_core = l3build.debug.copy_core-- options --debug-copy-core
    fslib.Vars.debug.all  = true
  end

  local target = options.target

  ---@type l3b_help_t
  local l3b_help  = require("l3build-help")

  if target == "help" then
    return l3b_help.help()
  elseif target == "version" then
    return l3b_help.version()
  end

  -- Load configuration file if running as a script
  if is_main then
    local f, msg = loadfile(work_dir / "build.lua")
    if not f then
      error(msg)
    end
    f() -- ignore any output
  end

  -- bundle and module names recovery

  ---@type G_t
  local G   = l3b_globals.G
  ---@type Dir_t
  local Dir = l3b_globals.Dir

  exit(process(options, {
    preflight     = function ()
      -- utlib.flags.cache_bridge = true not yet implemented
      set_tree_excluder(function (path)
        return path / "." == Dir.build / "."
      end)
    end,
    at_bundle_top = G.at_bundle_top,
    module_callback  = function (module_target)
      return call(G.modules, module_target)
    end,
  }))
end

---@class main_t
---@field public run fun()

return {
  run = run,
}