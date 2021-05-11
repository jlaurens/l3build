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

---@type Object
local Object = require("l3b-object")

---@type utlib_t
local utlib             = require("l3b-utillib")
local is_error          = utlib.is_error
local items             = utlib.items
local values            = utlib.values
local compare_ascending = utlib.compare_ascending
local print_diff_time   = utlib.print_diff_time

-- Module implementation

--[===[
In the sequel, a target denotes at the same time
an action performed by `l3build` and the name of the target.
The action is triggered by providing a target name to the CLI,
for example `l3build doc` to build the documentation.
What is performed is determined by info tables defined below.

The actions can be different when performed from the top level
or from an embedded module (see `G.at_bundle_top`).
For a module, the action type is always determined
by the `run` field of the target info.
When at the top of a bundle, the action content is determined by

1) the `run_bundle` field if any,
2) if `has_bundle_variant` is true, the `bundle_foo` target is triggered
for all the modules.
3) the required `run` field when all else failed
`has_bundle_variant` is ignored when `run_bundle` is defined.
Due to code separation, the `run` is not always provided.

## Hidden targets

Some targets are oly used internally and should not be exposed.
These as marked hidden.

--]===]
---@module targets

-- function signatures

---@alias target_run_high_f   fun(options: options_t): error_level_n
---@alias target_preflight_f  fun(options: options_t): error_level_n
---@alias target_process_f    fun(names: string[]): error_level_n

---Target action implementation
--[===[
A target implementation defines what is performed in what circumstances.

Actions triggered from the top of a bundle may not be the same
as from a standalone module.

--]===]

local get_info

---@class target_impl_t
---@field public configure   target_preflight_f|nil @function to run preflight code
---Default required run action
--[===[
  This required action is performed on default circumstances.
--]===]
---@field public run         target_process_f @function to run the target, possible computed attributed
---@field public run_high    target_run_high_f|nil @function to run the target, not config loaded, possible computed attributed
---@field public run_bundle  target_process_f|nil @function to run the target, used at top level, possible computed attributed

---@class target_info_t -- model for a target
---@field public description  string @description
---@field public package      string @controller package name
---@field public name         string @name
---@field public alias        string @alias, to support old naming
---@field public builtin      boolean @whether the target is builtin
---@field public impl         target_impl_t @the target implementation

---@alias target_run_f      fun(self: TargetInfo, options: options_t, kvargs: target_process_kvargs_t): error_level_n
---@alias target_done_run_f fun(self: TargetInfo, options: options_t, kvargs: target_process_kvargs_t): boolean, error_level_n

---@class TargetInfo: target_info_t -- model for a target
---@field public configure  target_run_f
---@field public run        target_run_f
---@field public run_high   target_done_run_f
---@field public run_bundle target_done_run_f
---@field public run_module target_done_run_f

local TargetInfo = Object:make_subclass("TargetInfo", {
  __instance_table = {
    impl = function (self)
      -- retrieve the target implementation from a required module
      local pkg = require(self.package)
      local impl = pkg[self.name .."_impl"] or {
        run = pkg[self.name]
      }
      rawset(self, "impl", impl)
      return impl
    end,
  },
  __initialize = function (self, info, builtin)
    for k in items(
      "description",
      "package",
      "name",
      "alias",
      "impl"
    ) do
      self[k] = info[k]
    end
    self.builtin = not not ( info.builtin or builtin )
  end
})

function TargetInfo:configure(options)
  local configure = self.impl.configure
  if configure then
    if options.debug then
      print("DEBUG: configure ".. options.target)
    end
    local error_level = configure(options)
    if is_error(error_level) then
      return error_level
    end
  end
  return 0
end

function TargetInfo:run(options)
  local target = options.target
  if options.debug then
    print("DEBUG: run ".. target)
  end
  local run = self.impl.run
  if not run then
    error("No run action for target ".. target)
  end
  return run(options.names)
end

local CONTINUE = {}

---comment
---@param options options_t
---@param kvargs target_process_kvargs_t
---@return boolean
---@return any
function TargetInfo:run_high(options, kvargs)
  if self.impl.run_high then
    if options.debug then
      print("DEBUG: run_high ".. options.target)
    end
    local error_level = kvargs.preflight()
    if is_error(error_level) then
      return true, error_level
    end
    local result = self.impl.run_high(options)
    return result ~= CONTINUE, result
  end
  return false
end

function TargetInfo:run_bundle(options, kvargs)
  if kvargs.at_bundle_top then
    if self.impl.run_bundle then
      if options.debug then
        print("DEBUG: custom run_bundle ".. options.target)
      end
      return true, self.impl.run_bundle(options.names)
    end
  end
  return false
end

function TargetInfo:run_module(options, kvargs)
  if kvargs.at_bundle_top then
    local module_target = "module_".. options.target
    module_target = get_info(module_target)
      and module_target
      or options.target
    if options.debug then
      print("DEBUG: module run ".. module_target)
    end
    return true, kvargs.module_callback(module_target)
  end
  return false
end

---@alias __target_DB_t table<string,TargetInfo>
---@type __target_DB_t
local DB = {}

---Enumerator of all the target infos.
---Target infos are sorted by name.
---@param hidden boolean true to list all hidden targets too.
---@return function
---@usage `for info in get_all_infos() do ... end`
local function get_all_infos(hidden)
  return values(DB, {
    compare = compare_ascending,
    exclude = function (info)
      return not info.description
    end
  })
end

---Return the target info for the given name, if any.
---@param name string
---@return TargetInfo|nil
function get_info(name)
  return DB[name]
end

---Register the target with the given target info
---
---@param info target_info_t
---@param builtin boolean|nil
local function register_info(info, builtin)
  assert(
    info.name,
    "l3b-targets.register_info: Missing info.name"
  )
  if DB[info.name] then
    error(
      "l3b-targets.register_info: Target name is already used: "
      .. tostring(info.name)
    )
  end
  if info.alias and DB[info.alias] then
    error("l3b-targets.register_info: Target alias "
      .. tostring(info.alias)
      .." is already used by "
      .. tostring(DB[info.alias].name)
    )
  end
  local result = TargetInfo(nil, info, builtin)
  DB[info.name] = result
  if info.alias then
    DB[info.alias] = result -- latex2e
  end
end

---@class target_register_kvargs_t
---@field public description   string|nil @description
---@field public name          string @name
---@field public configure     target_preflight_f|nil @function run before any other action code
---@field public run           target_process_f|string @function to run the target, possible computed attributed
---@field public run_high      target_process_f|string|nil @function to run the target, not config loaded, possible computed attributed
---@field public run_bundle    target_process_f|string|nil @function to run the target, used at top level, possible computed attributed

---@alias target_process_module_callback_f fun(module_target: string): error_level_n call the target against all the modules

---@class target_process_kvargs_t
---@field public preflight        target_preflight_f
---@field public at_bundle_top    nil|boolean
---@field public module_callback  nil|target_process_module_callback_f

---Action processor.
--[===[

## arguments

### `options`

The `options` table can come from two different situations

1)  it collects the CLI options given by the user
2)  it collects the CLI options given by l3build
    when it fires another action

The process workflows is

```
if run_high then
  preflight
  run_high
end
if configure then
  configure
end
if not already preflight then
  preflight
end
if at bundle top then
  if run_bundle then
    run_bundle
    return
  end
  module_callback
  return
end
run
```

### `kvargs`

Must define a `preflight`, may define a flag and a call back.
See target_process_kvargs_t.

--]===]
---Get the implementation table of the target.
---Run its `prepare`, return on error.
---Run its `run_high` call if possible, after `preflight`. Return the result when not nil.
---Run its `configure` if possible, return on error.
---Run the `preflight`.
---Return its `main` call if any.
---If at bundle top:
---  Return its `run_bundle` call if possible
---  Return its `caller` call with the proper target name
---Finally return its `run` call.
---@param options options_t @ Options from the command line
---@param kvargs   target_process_kvargs_t
---@return error_level_n
local function process(options, kvargs)
  local start = time()
  local target = options.target
  ---@type TargetInfo
  local info  = get_info(target)
  assert(info, "Unknown target name: ".. tostring(target))
  ---@type boolean
  local done
  ---@type error_level_n
  local error_level = 0

  done, error_level = info:run_high(options, kvargs)
  if not done then
    error_level = info:configure(options, kvargs)
    if not is_error(error_level) then
      -- From now on, we can eventually cache results in bridges
      --[[utlib.flags.cache_bridge = true
      require("l3build-globals")]]
      done, error_level = info:run_bundle(options, kvargs)
      if not done and not is_error(error_level) then
        done, error_level = info:run_module(options, kvargs)
        if not done and not is_error(error_level) then
          error_level = kvargs.preflight()
        end
        -- where should it be
        if not is_error(error_level) then
          error_level = info:run(options, kvargs)
        end
      end
    end
  end
  print_diff_time(
    ("Done %s in %%s"):format(target),
    difftime(time(), start)
  )
  return error_level
end

---@class l3b_targets_t
---@field public CONTINUE       any @ Special return value
---@field public get_all_infos  fun(hidden: boolean): fun(): TargetInfo|nil
---@field public get_info       fun(key: string): TargetInfo
---@field public register_info  fun(info: TargetInfo, builtin: boolean)
---@field public process        target_process_f

return {
  CONTINUE      = CONTINUE,
  get_all_infos = get_all_infos,
  get_info      = get_info,
  register_info = register_info,
  process       = process,
},
---@class __l3b_targets_t
---@field private DB __target_DB_t
_ENV.during_unit_testing and {
  DB = DB,
  TargetInfo = TargetInfo,
}
