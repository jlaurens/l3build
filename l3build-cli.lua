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

--[=[
Functions to declare the command line interface, options and targets.
Add new options in `option_list` and add new targets in `target_list`.
New targets must have their counterpart in the corresponding package.
--]=]

local pairs   = pairs

---@type Object
local Object = require("l3b-object")

---@type fslib_t
local fslib = require("l3b-fslib")
local file_exists = fslib.file_exists

---@type l3b_options_t
local l3b_options     = require("l3b-options")
---@type OptionManager
local OptionManager = l3b_options.OptionManager

---@type l3b_targets_t
local l3b_targets = require("l3b-targets")
local TargetManager = l3b_targets.TargetManager

-- Implementation

local GET_MAIN_VARIABLE = "get_main_variable"

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

---@class CLIManager: Object
local CLIManager = Object:make_subclass("CLIManager")

function CLIManager:__initialize()
  self.option_manager = OptionManager()
  self.target_manager = TargetManager()
end

---comment
---@param info OptionInfo
---@param builtin boolean|nil
---@return OptionInfo
function CLIManager:register_option(info, builtin)
  return self.option_manager:register(info, builtin)
end

---Register the builtin options
---@param self CLIManager
function CLIManager.register_builtin_options(self)
  for k, v in pairs(option_list) do
    v.long = k
    assert(self:register_option(v, true))
  end
end

---Register the custom options by loading and executing
---the `options.lua` located at `work_dir`.
---@param work_dir string
function CLIManager:register_custom_options(work_dir)
  local options_cfg = work_dir / "options.lua"
  if file_exists(options_cfg) then
    local ENV = setmetatable({}, {
      __index = _G
    })
    ENV.register_option = function (info)
      return self:register_option(info)
    end
    local f, msg = loadfile(options_cfg, "t", ENV)
    if not f then
      error(msg)
    end
    f()
  end
end

---Retrieve the OptionInfo for the given name.
---@param name string
---@return OptionInfo|nil
function CLIManager:option_info_with_name(name)
  return self.option_manager:info_with_name(name)
end

---Retrieve the OptionInfo for the given key.
---@param name string
---@return OptionInfo|nil
function CLIManager:option_info_with_key(name)
  return self.option_manager:info_with_key(name)
end

---Iterator over all the options
---@return fun(): OptionInfo|nil
function CLIManager:get_all_option_infos()
  return self.option_manager:get_all_infos()
end

---Register the custom options by loading and executing
---the `options.lua` located at `work_dir`.
---@param info target_info_t
function CLIManager:register_target(info)
  return self.target_manager:register(info)
end

---Iterator over all the targets
---@param hidden boolean true to list all hidden targets too.
---@return fun(): TargetInfo|nil
function CLIManager:get_all_target_infos(hidden)
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

function CLIManager:register_targets()
  -- register builtin targets
  for name, info in pairs(target_list) do
    info.name = name
    self.target_manager:register_target(info, true)
  end
end

---@class l3b_cli_t
---@field public GET_MAIN_VARIABLE  string
---@field public CLIManager   CLIManager

return {
  GET_MAIN_VARIABLE = GET_MAIN_VARIABLE,
  CLIManager  = CLIManager,
}
