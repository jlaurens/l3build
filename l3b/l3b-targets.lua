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

local time      = os.time
local difftime  = os.difftime

---@type utlib_t
local utlib         = require("l3b-utillib")
local items         = utlib.items
local sorted_values = utlib.sorted_values
local print_diff_time = utlib.print_diff_time

-- Module implementation

--[=[
In the sequel, a target denotes at the same time
an action performed by `l3build` and the name of the target.
The action is triggered by providing a target name to the CLI.
What is performed is determined by info tables defined below.

The actions can be different when performed from the top level
or from an embedded module (see `G.at_bundle_top`).
For a module, the action is always determined
by the `run` field of the target info.
When at the top of a bundle, the action is determined by
1) the `bundle_run` field if any,
2) if `has_bundle_variant` is true, the `bundle_foo` target is triggered
for all the modules.
3) the required `run` field when all else failed
`has_bundle_variant` is ignored when `bundle_run` is defined.
Due to code separation, the `run` is not always provided.

--]=]

-- function signatures

---@alias run_high_f           fun(options: options_t): error_level_n|nil
---@alias target_preflight_f  fun(options: options_t): error_level_n
---@alias target_process_f        fun(names: string_list_t): error_level_n

---@class target_impl_t
---@field prepare     target_preflight_f|nil function to run preflight code
---@field configure   target_preflight_f|nil function to run preflight code
---@field run         target_process_f function to run the target, possible computed attributed
---@field run_high    run_high_f|nil function to run the target, not config loaded, possible computed attributed
---@field bundle_run  target_process_f|nil function to run the target, used at top level, possible computed attributed

---@class target_info_t -- model for a target
---@field description string description
---@field package     string controller package name
---@field name        string name
---@field alias       string alias, to support old naming
---@field builtin     boolean whether the target is builtin
---@field impl        target_impl_t the target implementation

---@type table<string, target_info_t>
local DB = {}

---Enumerator of all the target infos.
---Sorted by name
---@kvarg hidden boolean true to list all hidden targets too.
---@return function
---@usage `for info in get_all_info() do ... end`
local function get_all_info(hidden)
  return sorted_values(DB, function (info)
    return not info.description
  end)
end

---Return the target info for the given name, if any.
---@kvarg name string
---@return target_info_t|nil
local function get_info(name)
  return DB[name]
end

---Register the target with the given name and info
---@kvarg info target_info_t
---@kvarg builtin boolean|nil
local function register_info(info, builtin)
  if DB[info.name] then
    error("Target name is already used: ".. info.name)
  end
  local result = {}
  for k in items(
    "description",
    "package",
    "name",
    "alias",
    "impl"
  ) do
    result[k] = info[k]
  end
  result.builtin = not not (info.builtin or builtin) -- boolean
  DB[info.name] = result
  if info.alias then
    DB[info.alias] = result -- latex2e
  end
end

---@class target_register_kvarg_t
---@field description   string|nil description
---@field name          string name
---@field prepare       target_preflight_f|nil function run before any other action code
---@field configure     target_preflight_f|nil function run before any other action code
---@field run           target_process_f|string function to run the target, possible computed attributed
---@field run_high      target_process_f|string|nil function to run the target, not config loaded, possible computed attributed
---@field bundle_run    target_process_f|string|nil function to run the target, used at top level, possible computed attributed

---Register the target with the given name and info
---@kvarg kvarg target_register_kvarg_t
---@kvarg builtin boolean|nil
local function register(kvarg, builtin)
  if DB[kvarg.name] then
    error("Target name is already used: ".. kvarg.name)
  end
  local info = {}
  for k in items(
    "description",
    "name"
  ) do
    info[k] = kvarg[k]
  end
  local impl = {}
  for k in items(
    "prepare",
    "configure",
    "run_high",
    "run",
    "bundle_run"
  ) do
    impl[k] = kvarg[k]
  end
  info.impl = impl
  info.builtin = not not builtin
  DB[kvarg.name] = info
end

---@alias target_process_top_callback_f fun(module_target: string): error_level_n call the target against all the modules

---@class target_process_kvarg_t
---@field preflight     fun(): error_level_n
---@field at_bundle_top nil|boolean
---@field top_callback  nil|target_process_top_callback_f

---Raises an error when the target is unknown.
---Get the implementation table of the target.
---Run its `prepare`, return on error.
---Run its `run_high` call if possible, after `preflight`. Return the result when not nil.
---Run its `configure` if possible, return on error.
---Run the `preflight`.
---Return its `main` call if any.
---If at bundle top:
---  Return its `bundle_run` call if possible
---  Return its `caller` call with the proper target name
---Finally return its `run` call.
---@param options options_t
---@param kvarg   target_process_kvarg_t
---@return error_level_n
local function process(options, kvarg)
  local start = time()
  local target = options.target
  local info = get_info(target)
  if not info then
    error("Unknown target name: ".. target)
  end
  local debug = options.debug
  local impl = info.impl  -- the implementation knows how to
  if not impl then
    local pkg = require(info.package)
    impl = pkg[target .."_impl"]
    if not impl then
      impl = {
        run = pkg[target]
      }
    end
  end
  local error_level = 0
  if impl.prepare then
    if debug then
      print("DEBUG: prepare ".. target)
    end
    error_level = impl.prepare(options)
    if error_level ~= 0 then
      return error_level
    end
  end
  if impl.run_high then -- before configure
    if debug then
      print("DEBUG: run_high ".. target)
    end
    kvarg.preflight()
    error_level = impl.run_high(options)
    if error_level ~= nil then
      print_diff_time(("Done %s in %%s"):format(target), difftime(time(), start))
      return error_level
    end
  end
  if impl.configure then
    if debug then
      print("DEBUG: configure ".. target)
    end
    error_level = impl.configure(options)
    if error_level ~= 0 then
      return error_level
    end
  end
  -- From now on, we can cache results in choosers
  kvarg.preflight()
  --[[utlib.flags.cache_bridge = true
  require("l3build-globals")]]
  local names = options.names
  if kvarg.at_bundle_top then
    if impl.bundle_run then
      if debug then
        print("DEBUG: custom bundle_run ".. target)
      end
      error_level = impl.bundle_run(names)
      print_diff_time(("Done %s in %%s"):format(target), difftime(time(), start))
      return error_level
    end
    local module_target = "module_".. target
    module_target = get_info(module_target)
      and module_target
      or target
    if debug then
      print("DEBUG: module run ".. module_target)
    end
    error_level = kvarg.top_callback(module_target)
    print_diff_time(("Done %s in %%s"):format(target), difftime(time(), start))
    return error_level
  end
  if debug then
    print("DEBUG: run ".. target)
  end
  if not impl.run then
    error("No run action for target ".. target)
  end
  error_level = impl.run(names)
  print_diff_time(("Done %s in %%s"):format(target), difftime(time(), start))
  return error_level
end

---@class l3b_targets_t
---@field get_all_info  fun(hidden: boolean): fun(): target_info_t|nil
---@field get_info      fun(key: string): target_info_t
---@field register      fun(info: target_info_t, builtin: boolean)
---@field register_info fun(info: target_info_t, builtin: boolean)
---@field process       target_process_f

return {
  get_all_info  = get_all_info,
  get_info      = get_info,
  register      = register,
  register_info = register_info,
  process       = process,
}
