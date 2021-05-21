--[[

File l3build-cli.lua Copyright (C) 2018-2020 The LaTeX Project

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

--[==[
Main controller
--]==]
---@module main

local pairs   = pairs
local exit    = os.exit
local concat  = table.concat

require("l3b-pathlib") -- string div

---@type corelib_t
local corelib = require("l3b-corelib")
local GET_MAIN_VARIABLE = corelib.GET_MAIN_VARIABLE

---@type fslib_t
local fslib = require("l3b-fslib")
local file_exists = fslib.file_exists
local set_tree_excluder = fslib.set_tree_excluder
local set_working_directory_provider = fslib.set_working_directory_provider

---@type Object
local Object = require("l3b-object")

-- We are in module mode
---@type Module
local Module = require("l3b-module")

local l3build = require("l3build")

--[==[ DEBUG flags ]==]
---@type oslib_t
-- local oslib = require("l3b-oslib")
-- oslib.Vars.debug.run = true
--[==[ DEBUG flags end ]==]

---@type l3b_aux_t
local l3b_aux = require("l3build-aux")
local call    = l3b_aux.call

---@type l3b_options_t
local l3b_options     = require("l3b-options")
---@type OptionManager
local OptionManager = l3b_options.OptionManager

---@type l3b_targets_t
local l3b_targets = require("l3b-targets")
local TargetManager = l3b_targets.TargetManager

---@type l3build_t
local l3build = require("l3build")

-- Implementation

---@class options_t: options_base_t
---@field public config    string[]
---@field public date      string
---@field public debug     boolean
---@field public dirty     boolean
---@field public dry_run   boolean @-- real name "dry-run"
---@field public email     string
---@field public engine    table
---@field public epoch     string
---@field public file      string
---@field public first     string
---@field public force     boolean
---@field public full      boolean
---@field public halt_on_error boolean @-- real name "halt-on-error"
---@field public help      boolean
---@field public last      string
---@field public message   string
---@field public names     string[]
---@field public quiet     boolean
---@field public rerun     boolean
---@field public shuffle   boolean
---@field public target    string
---@field public texmfhome string
---@field public get_main_variable string

local option_list = {
  config = {
    description = "Sets the config(s) used for running tests",
    short = "c",
    type  = "table"
  },
  date = {
    description = "Sets the date to insert into sources",
    type  = "string"
  },
  debug = {
    description = "Runs target in debug mode (not supported by all targets)",
    type = "boolean"
  },
  dirty = {
    description = "Skip cleaning up the test area",
    type = "boolean"
  },
  ["dry-run"] = {
    description = "Dry run for install",
    type = "boolean"
  },
  email = {
    description = "Email address of CTAN uploader",
    type = "string"
  },
  engine = {
    description = "Sets the engine(s) to use for running test",
    short = "e",
    type  = "table"
  },
  epoch = {
    description = "Sets the epoch for tests and typesetting",
    type  = "string"
  },
  file = {
    description = "Take the upload announcement from the given file",
    short = "F",
    type  = "string"
  },
  first = {
    description = "Name of first test to run",
    type  = "string"
  },
  force = {
    description = "Force tests to run if engine is not set up",
    short = "f",
    type  = "boolean"
  },
  full = {
    description = "Install all files",
    type = "boolean"
  },
  ["halt-on-error"] = {
    description = "Stops running tests after the first failure",
    short = "H",
    type  = "boolean"
  },
  help = {
    description = "Print this message and exit",
    short = "h",
    type  = "boolean"
  },
  last = {
    description = "Name of last test to run",
    type  = "string"
  },
  message = {
    description = "Text for upload announcement message",
    short = "m",
    type  = "string"
  },
  quiet = {
    description = "Suppresses TeX output when unpacking",
    short = "q",
    type  = "boolean"
  },
  rerun = {
    description = "Skip setup: simply rerun tests",
    type  = "boolean"
  },
  ["show-log-on-error"] = {
    description = "If 'halt-on-error' stops, show the full log of the failure",
    type  = "boolean"
  },
  shuffle = {
    description = "Shuffle order of tests",
    type  = "boolean"
  },
  texmfhome = {
    description = "Location of user texmf tree",
    type = "string"
  },
  version = {
    description = "Print version information and exit",
    type = "boolean"
  },
  [GET_MAIN_VARIABLE] = {
    description = "Status returns the value of the main variable given its name",
    type = "string"
  }
}


---@class Main: Object
local Main = Object:make_subclass("Main")

function Main.__:initialize()
  self.option_manager = OptionManager()
  self.target_manager = TargetManager()
  self.module = Module(l3build.work_dir)
  set_working_directory_provider(function()
    return self.module.path
  end)
end

---comment
---@param info OptionInfo
---@param builtin boolean|nil
---@return OptionInfo
function Main:register_option(info, builtin)
  return self.option_manager:register(info, builtin)
end

---Register the builtin options
---@param self Main
function Main.register_builtin_options(self)
  for k, v in pairs(option_list) do
    v.long = k
    assert(self:register_option(v, true))
  end
end

---Retrieve the OptionInfo for the given name.
---@param name string
---@return OptionInfo|nil
function Main:option_info_with_name(name)
  return self.option_manager:info_with_name(name)
end

---Retrieve the OptionInfo for the given key.
---@param name string
---@return OptionInfo|nil
function Main:option_info_with_key(name)
  return self.option_manager:info_with_key(name)
end

---Iterator over all the options
---@return fun(): OptionInfo|nil
function Main:get_all_option_infos()
  return self.option_manager:get_all_infos()
end

---Register the custom options by loading and executing
---the `options.lua` located at `work_dir`.
---@param info target_info_t
function Main:register_target(info)
  return self.target_manager:register(info)
end

---Register the custom options by loading and executing
---the `options.lua` located at `work_dir`.
---@param name string
---@return TargetInfo
function Main:target_info_with_name(name)
  return self.target_manager:get_info(name)
end

---Iterator over all the targets
---@param hidden boolean true to list all hidden targets too.
---@return fun(): TargetInfo|nil
function Main:get_all_target_infos(hidden)
  return self.target_manager:get_all_infos(hidden)
end

local target_list = {
  -- Some hidden targets
  module_check = { -- all modules
    package     = "l3build-check",
  },
  module_ctan = {
    package     = "l3build-ctan",
    alias       = "bundlectan",
  },
  module_unpack = {
    package     = "l3build-unpack",
  },
  module_tag = {
    package     = "l3build-tag",
  },
  -- Public targets (with decription)
  check = {
    description   = "Run all automated tests",
    package       = "l3build-check",
  },
  clean = {
    description   = "Clean out directory tree",
    package       = "l3build-clean",
    run_bundle    = "bundle_clean",
  },
  ctan = {
    description   = "Create CTAN-ready archive",
    package       = "l3build-ctan",
    run_bundle    = "ctan",
  },
  doc = {
    description   = "Typesets all documentation files",
    package       = "l3build-doc",
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
  status = {
    description   = "Display status informations",
    package       = "l3build-help",
  },
  tag = {
    description = "Updates release tags in files",
    package     = "l3build-tag",
  },
  uninstall = {
    description   = "Uninstalls files from the local texmf tree",
    package       = "l3build-install",
  },
  unpack = {
    description   = "Unpacks the source files into the build tree",
    package       = "l3build-unpack",
  },
  upload = {
    description = "Send archive to CTAN for public release",
    package     = "l3build-upload",
  },
}

function Main:register_targets()
  -- register builtin targets
  for name, info in pairs(target_list) do
    info.name = name
    self.target_manager:register(info, true)
  end
end

---Parse the command line arguments.
---When the key is not recognized by the system,
---`on_unknown` gets a chance to recognize it.
---When this function returns a falsy value it means no recognition.
---More details to follow.
---@param arg table
---@param on_unknown fun(key: string): boolean|fun(any: any, options: options_base_t) true when catched, false otherwise
---@return table
function Main:parse(arg, on_unknown)
  return self.option_manager:parse(arg, on_unknown)
end

---Action processor.
--[==[

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
See process_kvargs_t.

--]==]
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
---@param kvargs  process_kvargs_t
---@return error_level_n
function Main:process(options, kvargs)
  return self.target_manager:process(options, kvargs)
end

function Main:configure_module_cli()
  ---@type handler_registration_t
  local registration_1 = self.module:register_handler(
    "will_register_custom_options",
    function (module)
      function module._ENV.register_option(info)
        return self:register_option(info)
      end
    end
  )
  local registration_2 =  self.module:register_handler(
    "did_register_custom_options",
    function (module)
      module._ENV.register_option = nil
    end
  )
  self.module:register_custom_options()
  self.module:unregister_handler(registration_1)
  self.module:unregister_handler(registration_2)
end

function Main:configure_cli()
  self:register_builtin_options()
  self:register_targets()
  self:configure_module_cli()
end

function Main:load_build(dir)
  -- Load configuration file if running as a script
  if l3build.is_l3build then
    local path = dir / "build.lua"
    if file_exists(path) then
      local f, msg = loadfile(path, "t", _G)
      if not f then
        error(msg)
      end
      _G.register_target = function(info)
        return self:register_target(info)
      end
      f() -- ignore any output
      _G.register_target = nil
    end
  end
end

function Main:run()


  self:configure_cli()

  local options = self:parse(arg, function (arg_i)
    -- Private special debugging options "--debug-<key>"
    local key = arg_i:match("^debug%-(%w[%w%d_-]*)")
    if key then
      l3build.debug[key:gsub("-", "_")] = true
      return true
    end
  end)
  if not options.quiet and not options.debug then
    print("BANNER", concat(l3build.banner, "\n"))
  end
  l3build.banner = {}

  ---@type l3b_globals_t
  local l3b_globals = require("l3build-globals")

  l3b_globals.export()

  l3build.options = options

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

  self:load_build(l3build.work_dir)

  if _G.main then
    return _G.main(options.target)
  end

  ---@type G_t
  local G   = l3b_globals.G
  ---@type Dir_t
  local Dir = l3b_globals.Dir

  exit(self:process(options, {
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


---@class l3b_main_t
---@field public GET_MAIN_VARIABLE  string
---@field public Main               Main

return {
  GET_MAIN_VARIABLE = GET_MAIN_VARIABLE,
  Main  = Main,
}
