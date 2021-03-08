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

local gsub        = string.gsub

local exit        = os.exit
local append      = table.insert

---@type utlib_t
local utlib       = require("l3b.utillib")
local entries     = utlib.entries
local deep_copy   = utlib.deep_copy

---@type fslib_t
local fslib         = require("l3b.fslib")
local all_names     = fslib.all_names
local file_exists   = fslib.file_exists

---@type l3build_t
local l3build = require("l3build")

---@type l3b_vars_t
local l3b_vars  = require("l3b.variables")
---@type Main_t
local Main      = l3b_vars.Main
---@type Deps_t
local Deps      = l3b_vars.Deps
---@type Dir_t
local Dir       = l3b_vars.Dir

---@type l3b_aux_t
local l3b_aux       = require("l3b.aux")
local call          = l3b_aux.call
local deps_install  = l3b_aux.deps_install

---@type l3b_check_t
local l3b_check       = require("l3b.check")
local l3b_check_vars  = l3b_check.Vars
local check           = l3b_check.check
local save            = l3b_check.save

local help          = require("l3b.help").help
local l3b_ctan      = require("l3b.ctan")
local ctan          = l3b_ctan.ctan
local bundlectan    = l3b_ctan.bundlectan
local l3b_unpk      = require("l3b.unpack")
local unpack        = l3b_unpk.unpack
local bundleunpack  = l3b_unpk.Vars.bundleunpack
local l3b_clean     = require("l3b.clean")
local clean         = l3b_clean.clean
local bundleclean   = l3b_clean.bundleclean
local doc           = require("l3b.typesetting").doc
local l3b_inst      = require("l3b.install")
local install       = l3b_inst.install
local uninstall     = l3b_inst.uninstall
local manifest      = require("l3b.manifest").manifest
local tag           = require("l3b.tagging").manifest
local upload        = require("l3b.upload").upload

local target_list =
  {
    -- Some hidden targets
    bundlecheck =
      {
        func = check,
        pre  = function(names)
            if names then
              print("Bundle checks should not list test names")
              help()
              exit(1)
            end
            return 0
          end
      },
    bundlectan =
      {
        func = bundlectan
      },
    bundleunpack =
      {
        func = bundleunpack,
        pre  = function()
          return deps_install(Deps.unpack)
        end
      },
    -- Public targets
    check =
      {
        bundle_target = true,
        desc = "Run all automated tests",
        func = check,
      },
    clean =
      {
        bundle_func = bundleclean,
        desc = "Clean out directory tree",
        func = clean
      },
    ctan =
      {
        bundle_func = ctan,
        desc = "Create CTAN-ready archive",
        func = ctan
      },
    doc =
      {
        desc = "Typesets all documentation files",
        func = doc
      },
    install =
      {
        desc = "Installs files into the local texmf tree",
        func = install
      },
    manifest =
      {
        desc = "Creates a manifest file",
        func = manifest
      },
    save =
      {
        desc = "Saves test validation log",
        func = save
      },
    tag =
      {
        bundle_func = function(names)
            local modules = Main.modules
            local error_level = call(modules, "tag")
            -- Deal with any files in the bundle dir itself
            if error_level == 0 then
              error_level = tag(names)
            end
            return error_level
          end,
        desc = "Updates release tags in files",
        func = tag,
        pre  = function(names)
           if names and #names > 1 then
             print("Too many tags specified; exactly one required")
             exit(1)
           end
           return 0
         end
      },
    uninstall =
      {
        desc = "Uninstalls files from the local texmf tree",
        func = uninstall
      },
    unpack =
      {
        bundle_target = true,
        desc = "Unpacks the source files into the build tree",
        func = unpack
      },
    upload =
      {
        desc = "Send archive to CTAN for public release",
        func = upload
      },
  }

--
-- The overall main function
--

---comment
---@param target  string
---@param names?  string_list_t
local function main(target, names)
  -- Deal with unknown targets up-front
  if not target_list[target] then
    help()
    exit(1)
  end
  local error_level = 0
  if Main.module == "" then
    local modules = Main.modules
    if target_list[target].bundle_func then
      error_level = target_list[target].bundle_func(names)
    else
      -- Detect all of the modules
      if target_list[target].bundle_target then
        target = "bundle" .. target
      end
      error_level = call(modules, target)
    end
  else
    local info = target_list[target]
    if info.pre then
     error_level = info.pre(names)
     if error_level ~= 0 then
       exit(1)
     end
    end
    error_level = info.func(names)
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
  target_list       = target_list,
  multi_check       = multi_check,
  prepare_config    = prepare_config,
}
