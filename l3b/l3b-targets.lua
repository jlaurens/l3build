--[[

File l3b-targets.lua Copyright (C) 2018-2020 The LaTeX Project

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

-- code dependencies:

local tostring  = tostring
local exit      = os.exit

---@type utlib_t
local utlib         = require("l3b-utillib")
local items         = utlib.items
local sorted_values = utlib.sorted_values

-- Module implementation

--[=[
In the sequel, a target denotes at the same time
an action performed by `l3build` and the name of the target.
The action is triggered by providing a target name to the CLI.
What is performed is determined by info tables defined below.

The actions can be different when performed from the top level
or from an embedded module (see `Main._at_bundle_top`).
For a module, the action is always determined
by the `run` field of the target info.
When at the top of a bundle, the action is determined by
1) the `bundle_run` field if any,
2) if `is_bundle_aware` is true, the `bundle_foo` target is triggered
for all the modules.
3) the required `run` field when all else failed
`is_bundle_aware` is ignored when `bundle_run` is defined.
Due to code separation, the `run` is not always provided.

--]=]

---@alias target_run_f fun(names: string_list_t): error_level_t
---@alias target_preflight_f fun(names: string_list_t): error_level_t

---@class target_info_t
---@field name          string name
---@field alias         string alias, to support old naming
---@field description   string description
---@field preflight     target_preflight_f|nil function to run preflight code
---@field run           target_run_f function to run the target, possible computed attributed
---@field bundle_run    target_run_f|nil function to run the target, used at top level, possible computed attributed
---@field is_bundle_aware boolean When true, "bundle" is prepended to `target`
---@field bundle_target string `name`, prepended with "bundle_" on `is_bundle_aware`
---@field builtin       boolean whether the target is builtin

---@type table<string, target_info_t>
local DB = {}

---Enumerator of all the target infos.
---Sorted by name
---@param hidden boolean true to list all hidden targets too.
---@return function
---@usage `for info in get_all_info() do ... end`
local function get_all_info(hidden)
  return sorted_values(DB, function (info)
    return not info.description
  end)
end

---Return the target info for the given name, if any.
---@param name string
---@return target_info_t|nil
local function get_info(name)
  return DB[name]
end

---Register the target with the given name and info
---@param info target_info_t
---@param builtin boolean|nil
local function register(info, builtin)
  if DB[info.name] then
    error("Target name is already used: ".. info.name)
  end
  local result = {}
  for k in items(
    "name",
    "alias",
    "package",
    "run",
    "bundle_run",
    "prepare",
    "is_bundle_aware",
    "description"
  ) do
    result[k] = info[k]
  end
  result.builtin = builtin or false
  DB[info.name] = setmetatable({}, {
    __index = function (t, k)
      local result_k = result[k]
      if k == "run" then -- must always return something
        local package = result.package
        if type(result_k) == "string" then
          result_k = require(package)[result_k]
        elseif result_k == nil then
          result_k = require(package)[t.name]
        end
        if type(result_k) ~= "function" then
          error("Bad target info field (function or string expected) ".. k .."=".. tostring(result_k))
        end
      elseif k == "bundle_run" then
        local package = t.package
        if type(result_k) == "string" then
          result_k = require(package)[result_k]
        end
        if result_k and type(result_k) ~= "function" then
          error("Bad target info field (function or string expected) ".. k .."=".. tostring(result_k))
        end
      elseif k == "bundle_target" then
        return t.is_bundle_aware and "bundle_".. t.name or t.name
      end
      rawset(t, k, result_k)
      return result_k
    end,
    __newindex = function (t, k, v)
      if v ~= nil then
        error("Target info is readonly: ".. tostring(k) .."=".. tostring(v))
      end
    end
  })
  if info.alias then
    DB[info.alias] = DB[info.name] -- latex2e
  end
end

local target_list = {
  -- Some hidden targets
  bundle_check = {
    package     = "l3build-check",
    alias       = "bundlecheck",
  },
  bundle_ctan = {
    package     = "l3build-ctan",
    alias       = "bundlectan",
  },
  bundle_unpack = {
    package     = "l3build-unpack",
    alias       = "bundleunpack",
  },
  bundle_tag = {
    package     = "l3build-tagging",
  },
  -- Public targets (with decription)
  check = {
    description   = "Run all automated tests",
    package       = "l3build-check",
    is_bundle_aware  = true,
  },
  clean = {
    description   = "Clean out directory tree",
    package       = "l3build-clean",
    bundle_run    = "bundle_clean",
  },
  ctan = {
    description   = "Create CTAN-ready archive",
    package       = "l3build-ctan",
    bundle_run    = "ctan",
  },
  doc = {
    description   = "Typesets all documentation files",
    package       = "l3build-typesetting",
  },
  install = {
    description   = "Installs files into the local texmf tree",
    package       = "l3build-install",
  },
  manifest = {
    description   = "Creates a manifest file",
    package       = "l3build-manifest",
  },
  save = {
    description   = "Saves test validation log",
    package       = "l3build-check",
  },
  tag = {
    description = "Updates release tags in files",
    package     = "l3build-tagging",
    is_bundle_aware  = true,
  },
  uninstall = {
    description   = "Uninstalls files from the local texmf tree",
    package       = "l3build-install",
  },
  unpack = {
    description   = "Unpacks the source files into the build tree",
    package       = "l3build-unpack",
    is_bundle_aware  = true,
  },
  upload = {
    description = "Send archive to CTAN for public release",
    package     = "l3build-upload",
  },
}

-- register builtin targets
for name, info in pairs(target_list) do
  info.name = name
  register(info, true)
end

---@class l3b_targets_t
---@field get_all_info  fun(hidden: boolean): fun(): target_info_t|nil
---@field get_info      fun(key: string): target_info_t
---@field register      fun(info: target_info_t, builtin: boolean)

return {
  get_all_info  = get_all_info,
  get_info      = get_info,
  register      = register,
}
