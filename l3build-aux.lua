--[[

File l3build-aux.lua Copyright (C) 2018-2020 The LaTeX Project

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

-- local safety guards and shortcuts

local match = string.match

local pairs = pairs
local print = print

local os_time = os.time

---@type utlib_t
local utlib = require("l3b.utillib")
local entries = utlib.entries
local extend_with = utlib.extend_with

---@type wklib_t
local wklib = require("l3b.walklib")
local dir_base = wklib.dir_base

---@type oslib_t
local oslib = require("l3b.oslib")
local cmd_concat = oslib.cmd_concat
local run = oslib.run

---@type fslib_t
local fslib = require("l3b.fslib")
local absolute_path = fslib.absolute_path

---@type l3build_t
local l3build = require("l3build")

--
-- Auxiliary functions which are used by more than one main function
--

---Convert the given `epoch` to a number.
---@param epoch string
---@return number
---@see l3build.lua
---@usage private?
local function normalise_epoch(epoch)
  assert(epoch, 'normalize_epoch argument must not be nil')
  -- If given as an ISO date, turn into an epoch number
  local y, m, d = match(epoch, "^(%d%d%d%d)-(%d%d)-(%d%d)$")
  if y then
    return os_time({
        year = y, month = m, day   = d,
        hour = 0, sec = 0, isdst = nil
      }) - os_time({
        year = 1970, month = 1, day = 1,
        hour = 0, sec = 0, isdst = nil
      })
  elseif match(epoch, "^%d+$") then
    return tonumber(epoch)
  else
    return 0
  end
end

---Returns the CLI command to set the epoch
---when forcecheckepoch is true, a void string otherwise.
---Will be run while checking or typesetting
---@param epoch string
---@param force boolean
---@return string
---@see check, typesetting
---@usage private?
local function set_epoch_cmd(epoch, force)
  return force and cmd_concat(
    os_setenv .. " SOURCE_DATE_EPOCH=" .. epoch,
    os_setenv .. " SOURCE_DATE_EPOCH_TEX_PRIMITIVES=1",
    os_setenv .. " FORCE_SOURCE_DATE=1"
  ) or ""
end

---Returns the script name depending on the calling sequence.
---`l3build ...` -> full path of `l3build.lua` in the TDS
---When called via `texlua l3build.lua ...`, `l3build.lua` is resolved to either
---`./l3build.lua` or the full path of `l3build.lua` in the TDS.
---`texlua l3build.lua` -> `/Library/TeX/texbin/l3build.lua` or `./l3build.lua`
---@return string
local function get_script_name()
  local dir, base = dir_base(l3build.PATH)
  return absolute_path(dir) .. '/' .. base
end

-- Performs the task named target given modules in a bundle.
---A module is the path of a directory relative to the main one.
---Uses `run` to launch a command.
---@param modules table List of modules.
---@param target string
---@param opts table
---@return number 0 on proper termination, a non 0 error code otherwise.
---@see many places, including latex2e/build.lua
---@usage Public
local function call(modules, target, opts)
  -- Turn the option table into a CLI option string
  opts = opts or options
  local cli_opts = ""
  for k, v in pairs(opts) do
    if k ~= "names" and k ~= "target" then -- Special cases, TODO enhance the design to remove the need for this comment
      local t = option_list[k] or {}
      local value = ""
      if t["type"] == "string" then
        value = value .. "=" .. v
      elseif t["type"] == "table" then
        for a in entries(v) do
          if value == "" then
            value = "=" .. a -- Add the initial "=" here
          else
            value = value .. "," .. a
          end
        end
      end
      cli_opts = cli_opts .. " --" .. k .. value
    end
  end
  if opts.names then
    for name in entries(opts.names) do
      cli_opts = cli_opts .. " " .. name
    end
  end
  local script_name = get_script_name()
  for module in entries(modules) do
    local text
    if module == "." and opts["config"] and #opts["config"]>0 then
      text = " with configuration " .. opts["config"][1]
    else
      text = " for module " .. module
    end
    print("Running l3build with target \"" .. target .. "\"" .. text )
    local cmd = "texlua " .. script_name .. " " .. target .. cli_opts
    if l3build.debug.call then
      print("DEBUG Info: module  ".. module)
      print("DEBUG Info: execute ".. cmd)
    end
    local error_level = run(module, cmd)
    if error_level ~= 0 then
      return error_level
    end
  end
  return 0
end

---Unpack the given dependencies.
---A dependency is the path of a directory relative to the main one.
---@param deps table regular array of dependencies.
---@return number 0 on proper termination, a non 0 error code otherwise.
---@see stdmain, check, unpack, typesetting
---@usage Private?
local function dep_install(deps)
  local error_level
  for dep in entries(deps) do
    print("Installing dependency: " .. dep)
    error_level = run(dep, "texlua " .. get_script_name() .. " unpack -q")
    if error_level ~= 0 then
      return error_level
    end
  end
  return 0
end

-- this is the map to export function symbols to the global space
local global_symbol_map = {
  call = call,
}

--[=[ Export function symbols ]=]
extend_with(_G, global_symbol_map)
-- [=[ ]=]

---@class l3b_aux_t
---@field normalise_epoch function
---@field dep_install function
---@field call function
---@field set_epoch_cmd function

return {
  global_symbol_map = global_symbol_map,
  normalise_epoch = normalise_epoch,
  dep_install = dep_install,
  call = call,
  set_epoch_cmd = set_epoch_cmd,
}
