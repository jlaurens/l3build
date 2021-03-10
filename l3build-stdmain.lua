--[[

File l3build-stdmain.lua Copyright (C) 2018-2020 The LaTeX Project

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

-- code dependencies

local exit        = os.exit
local append      = table.insert

---@type utlib_t
local utlib       = require("l3b-utillib")
local entries     = utlib.entries
local deep_copy   = utlib.deep_copy

---@type fslib_t
local fslib         = require("l3b-fslib")
local all_names     = fslib.all_names
local file_exists   = fslib.file_exists

---@type l3build_t
local l3build = require("l3build")

---@type l3b_targets_t
local l3b_targets_t   = require("l3b-targets")
local get_target_info = l3b_targets_t.get_info

---@type l3b_vars_t
local l3b_vars  = require("l3build-variables")
---@type Main_t
local Main      = l3b_vars.Main
---@type Dir_t
local Dir       = l3b_vars.Dir

---@type l3b_aux_t
local l3b_aux   = require("l3build-aux")
local call      = l3b_aux.call

---@type l3b_check_t
local l3b_check       = require("l3build-check")
local l3b_check_vars  = l3b_check.Vars

local help  = require("l3build-help").help

-- module implementation

--
-- The overall main function
--

---comment
---@param target  string
---@param names?  string_list_t
local function main(target, names)
  -- Deal with unknown targets up-front
  local info = get_target_info(target)
  if not info then
    help()
    exit(1)
  end
  local error_level = 0
  if Main._at_bundle_top then
    if info.bundle_run then
      error_level = info.bundle_run(names)
    else
      -- Detect all of the modules
      local modules = Main.modules
      error_level = call(modules, info.bundle_target)
    end
  else
    if info.preflight then
      error_level = info.preflight(names)
      if error_level ~= 0 then
        exit(1)
      end
    end
    error_level = info.run(names)
  end
  -- All done, finish up
  if error_level ~= 0 then
    exit(1)
  else
    exit(0)
  end
end

---comment
local function multi_check()
  local options = l3build.options
  if options["target"] == "check" then
    local checkconfigs = l3b_check_vars.checkconfigs
    if #checkconfigs > 1 then
      local error_level = 0
      local opts = deep_copy(options)
      ---@type string_list_t
      local failed_configs = {}
      utlib.Vars.debug.chooser = true
      for config in entries(checkconfigs) do
        opts["config"] = { config }
        error_level = call({ "." }, "check", opts)
        if error_level ~= 0 then
          if options["halt-on-error"] then
            exit(1)
          else
            append(failed_configs, config)
          end
        end
      end
      if next(failed_configs) then
        for config in entries(failed_configs) do
          print("Failed tests for configuration " .. config .. ":")
          print("\n  Check failed with difference files")
          local test_dir = Dir.test
          if config ~= "build" then
            test_dir = test_dir .. "-" .. config
          end
          for name in all_names(test_dir, "*" .. _G.os_diffext) do
            print("  - " .. test_dir .. "/" .. name)
          end
          print("")
        end
        exit(1)
      else
        -- Avoid running the 'main' set of tests twice
        exit(0)
      end
    end
  end
end

local function prepare_config()
  local checkconfigs = l3b_check_vars.checkconfigs
  local options = l3build.options
  local config_1 = checkconfigs[1]
  local target = options["target"]
  if #checkconfigs == 1 and
    config_1 ~= "build" and
    (target == "check" or target == "save" or target == "clean") then
      local config_path = l3build.work_dir .. config_1:gsub( ".lua$", "") .. ".lua"
      if file_exists(config_path) then
        dofile(config_path)
        Dir.test = Dir.test .. "-" .. config_1
      else
        print("Error: Cannot find configuration " .. config_1)
        print("l3build.work_dir", l3build.work_dir)
        exit(1)
      end
  end
end

---@class l3b_main_t
---@field main            fun()
---@field target_list     table<string, table>
---@field multi_check     fun()
---@field prepare_config  fun()

return {
  main              = main,
  multi_check       = multi_check,
  prepare_config    = prepare_config,
}
