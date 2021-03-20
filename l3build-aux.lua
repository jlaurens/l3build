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

local print   = print
local concat  = table.concat

---@type utlib_t
local utlib             = require("l3b-utillib")
local entries           = utlib.entries
local to_quoted_string  = utlib.to_quoted_string

local pairs   = pairs -- cache after `l3b-utillib` is loaded.

---@type oslib_t
local oslib       = require("l3b-oslib")
local cmd_concat  = oslib.cmd_concat
local run         = oslib.run
local OS          = oslib.OS
local quoted_path = oslib.quoted_path

---@type fslib_t
local fslib = require("l3b-fslib")
local file_exists = fslib.file_exists

---@type l3build_t
local l3build = require("l3build")

--
-- Auxiliary functions which are used by more than one main function
--

---Returns the CLI command to set the epoch
---when force is true, a void string otherwise.
---Will be run while checking or typesetting
---@param epoch string
---@param force boolean
---@return string
---@see check, typesetting
---@usage private?
local function set_epoch_cmd(epoch, force)
  return force and cmd_concat(
    OS.setenv .. " SOURCE_DATE_EPOCH=" .. tostring(epoch),
    OS.setenv .. " SOURCE_DATE_EPOCH_TEX_PRIMITIVES=1",
    OS.setenv .. " FORCE_SOURCE_DATE=1"
  ) or ""
end

-- Performs the task named target given modules in a bundle.
---A module is the path of a directory relative to the main one.
---Uses `run` to launch a command: change to the module directory,
---then executes texlua with proper arguments.
---@param modules string[] List of modules.
---@param target  string
---@param opts    options_t|nil
---@return error_level_n 0 on proper termination, a non 0 error code otherwise.
---@see many places, including latex2e/build.lua
---@usage Public
local function call(modules, target, opts)
  -- Turn the option table into a CLI option string
  opts = opts or l3build.options
  local cli_opts = ""
  for k, v in pairs(opts) do
    if k ~= "names" and k ~= "target" then -- historical limitation
      local type_v = type(v)
      local no = ""
      local value = ""
      if type_v == "boolean" then
        if not v then
          no = "no-"
        end
      elseif type_v == "number" then
        value = "=" .. tostring(v)
      elseif type_v == "string" then
        value = "=" .. v
      elseif type_v == "table" then
        value = "=" .. concat(v, ",")
      end
      cli_opts = cli_opts .." --".. no .. k .. value
    end
  end
  if opts.names then
    cli_opts = cli_opts .." ".. to_quoted_string(opts.names)
  end
  local script_path = quoted_path(l3build.script_path)
  for module in entries(modules) do
    local text
    local opts_config = opts["config"]
    if module == "." and opts_config and #opts_config>0 then
      text = " with configuration " .. opts_config[1]
    else
      text = " for module " .. module
    end
    print("Running l3build with target \"" .. target .. "\"" .. text )
    local cmd = "texlua " .. script_path .. " " .. target .. cli_opts
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
---@param deps table regular array of dependencies. See `Deps`fields.
---@return number 0 on proper termination, a non 0 error code otherwise.
---@see stdmain, check, unpack, typesetting
---@usage Private?
local function deps_install(deps)
  local error_level
  for dep in entries(deps) do
    print("Installing dependency: " .. dep)
    error_level = run(dep, "texlua " .. quoted_path(l3build.script_path) .. " unpack -q")
    if error_level ~= 0 then
      return error_level
    end
  end
  return 0
end

---Load the config file, when unique and not "build".
---The return value is used to setup the global `G.config_suffix`.
---@param options options_t
---@param configs string[]
---@return string? config the config suffix
---@usage `G.config_suffix = load_unique_config(options, configs)`
local function load_unique_config(options, configs)
  if #configs ~= 1 then
    return
  end
  local config_1 = configs[1]
  if config_1 == "build" then
    return
  end
  config_1 = config_1:gsub( ".lua$", "") .. ".lua"
  local config_path = l3build.work_dir .. config_1
  if not file_exists(config_path) then
    config_path = l3build.work_dir .. "config-".. config_1
  end
  if not file_exists(config_path) then
    error("Missing configuration " .. tostring(config_path))
  end
  dofile(config_path)
  if options.debug then
    print("DEBUG config: ", config_1)
  end
  return "-".. config_1
end

---@class l3b_aux_t
---@field deps_install  fun(deps: table): number
---@field call          fun(modules: string[], target: string, opts: table): number
---@field set_epoch_cmd fun(epoch: string, force: boolean): string
---@field load_unique_config  fun(options: options_t): error_level_n

return {
  deps_install        = deps_install,
  call                = call,
  set_epoch_cmd       = set_epoch_cmd,
  load_unique_config  = load_unique_config,
}
