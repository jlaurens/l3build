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

local dofile  = dofile
local pairs   = pairs

---@type fslib_t
local fslib = require("l3b-fslib")
local file_exists = fslib.file_exists

---@type l3b_options_t
local l3b_options     = require("l3b-options")
local register_option = l3b_options.register

---@type l3b_targets_t
local l3b_targets     = require("l3b-targets")
local register_target = l3b_targets.register_info

-- Implementation

local GET_MAIN_VARIABLE = "get_main_variable"

---@class options_t: options_base_t
---@field config    string_list_t
---@field date      string
---@field debug     boolean
---@field dirty     boolean
---@field dry_run   boolean -- real name "dry-run"
---@field email     string
---@field engine    table
---@field epoch     string
---@field file      string
---@field first     string
---@field force     boolean
---@field full      boolean
---@field halt_on_error boolean -- real name "halt-on-error"
---@field help      boolean
---@field last      string
---@field message   string
---@field names     string_list_t
---@field quiet     boolean
---@field rerun     boolean
---@field shuffle   boolean
---@field target    string
---@field texmfhome string
---@field get_main_variable string

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

---Register the builtin options
local function register_builtin_options()
  for k, v in pairs(option_list) do
    v.long = k
    register_option(v, true)
  end
end

---Register the custom options by loading and executing
---the `options.lua` located at `work_dir`.
---@param work_dir string
local function register_custom_options(work_dir)
  local options_cfg = work_dir .. "options.lua"
  if file_exists(options_cfg) then
    _G.register_option = register_option
    dofile(options_cfg)
  end
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
    bundle_run    = "bundle_clean",
  },
  ctan = {
    description   = "Create CTAN-ready archive",
    package       = "l3build-ctan",
    bundle_run    = "ctan",
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

local function register_targets()
  -- register builtin targets
  for name, info in pairs(target_list) do
    info.name = name
    register_target(info, true)
  end
end

---@class l3b_cli_t
---@field GET_MAIN_VARIABLE         string
---@field register_builtin_options  fun()
---@field register_custom_options   fun()
---@field register_targets          fun()
---@field parse                     l3b_options_parse_f

return {
  GET_MAIN_VARIABLE         = GET_MAIN_VARIABLE,
  register_builtin_options  = register_builtin_options,
  register_custom_options   = register_custom_options,
  register_targets          = register_targets,
  parse                     = l3b_options.parse
}
