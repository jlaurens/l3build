--[[

File l3build-module.lua Copyright (C) 2018-2020 The LaTeX Project

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

--[===[
This package only provides minimal definitions of
Module and ModEnv classes.

The Module instances are a model of a module folder.

The ModEnv instances are the environments in which the
`build.lua` and various config files are loaded.

Both classes are expected to work together but for development reasons,
the declaration and the implementation are partly separated.

Complete Module with minimal ModEnv should work
and complete ModEnv with minimal Module shoud work as well.
Here "should work" means that a reasonable testing is possible.

--]===]
---@module modlib

local push = table.insert

---@type pathlib_t
local pathlib   = require("l3b-pathlib")
local dir_name  = pathlib.dir_name
local relative  = pathlib.relative

---@type utlib_t
local utlib   = require("l3b-utillib")
local entries = utlib.entries

---@type fslib_t
local fslib     = require("l3b-fslib")
local tree      = fslib.tree

----@type Object
local Object = require("l3b-object")

---@type Env
local Env = require("l3b-env")

---@type l3build_t
local l3build = require("l3build")
local find_container_up = l3build.find_container_up

--[=[ Package implementation ]=]

---@type Module
local Module = Object:make_subclass("Module")

---@type ModEnv
local ModEnv = Env:make_subclass("ModEnv")

---@class module_kv: object_kv
---@field public path string

local unique = {}

---Retrieve the unique `Module` instance
---@param kv module_kv
---@return Module|nil
function Module.__.unique_get(kv)
  return unique[kv.path / "."]
end

---Store the receiver as unique `Module` instance
---@param self Module
function Module.__:unique_set()
  unique[assert(self.path, "Missing path property")] = self
end

---Initialize the receiver.
---@param kv module_kv
---@return nil|string @ nil on success, an error message on failure.
function Module.__:initialize(kv)
  local up = find_container_up(kv.path,  "build.lua")
  if not up then
    return "No module at ".. kv.path
  end
  self.path = up / "."
  self.env = ModEnv({ module = self })
  self.__child_modules = {}
  self.__install_files = {} -- This does not belong here
end

local GTR = Module.__.getter

function GTR:path()
  error("Only on instances: path")
end

function GTR:env()
  local result = ModEnv({ module = self })
  self:cache_set("env", result)
  return result
end

function GTR:parent_module()
  if rawget(self, "is_main") then
    return Object.NIL
  end
  local up = find_container_up(self.path / "..",  "build.lua")
  if up then
    rawset(self, "is_main", false)
    local parent = Module({ path = up })
    rawset(self, "parent_module", parent)
    return parent
  end
  rawset(self, "is_main", true)
  return Object.NIL
end

function GTR:is_main()
  return self.parent_module == nil
end

function GTR:main_module(k)
  if not self.is_main then
    local parent = self.parent_module
    if parent then
      local main = parent.main_module
      rawset(self, k, main)
      return assert(main)
    end
  end
  rawset(self, k, self)
  return assert(self)
end

function GTR:child_modules(k)
  local result = rawget(self, k)
  if result == nil then
    local found = {}
    -- find all the "build.lua" files inside the receiver's directory
    -- We assume that tree goes from top to bottom
    for entry in tree(self.path, "*/**/build.lua", {
      exclude = function (e)
        for already in entries(found) do
          if not relative(e.src, already):match("^%.%./") then
            return true -- do not dig inside modules
          end
        end
      end
    }) do
      push(found, dir_name(entry.src))
    end
    result = {}
    for p in entries(found) do
      push(result, Module({ path = self.path / p }))
    end
    rawset(self, k, result)
  end
  return result
end

function GTR:install_files()
  return self.__install_files
end

function GTR:options()
  return l3build.options
end

function Module.__.setter:child_modules()
  error("Module readonly property: child_modules")
end

function Module.__.setter:install_files()
  error("Module readonly property: install_files")
end

local CONFIGURATION = {}

function GTR:configuration()
  return rawget(self, CONFIGURATION)
end

function GTR:config_suffix()
  local cfg = self.configuration
  return cfg and "-".. cfg or ""
end

function GTR:bundle()
  local main_module = self.main_module
  if main_module ~= self then
    return main_module.bundle
  end
  return ""
end

function Module.__.setter:configuration(value)
  assert(not value or #value > 0, "Bad configuration")
  return rawset(self, CONFIGURATION, value)
end

local MODULE = {} -- unique tag for an unexposed private property

---Static method to retrieve the module of a module environment
---@param env ModEnv
---@return any
function Module.__get_module_of_env(env)
  assert(env:is_descendant_of(ModEnv)) -- to prevent foo.__:get_module_of_env
  return env:private_get(MODULE)
end

---Static method to set the module of a module environment
---@generic T: ModEnv
---@param env     T
---@param module  Module
---@return T @ self
function Module.__set_module_of_env(env, module)
  assert(env:is_descendant_of(ModEnv)) -- to prevent foo.__:set_module_of_env
  return env:private_set(MODULE, module)
end


-- The ModeEnv class has an associate virtual module
-- which is simply the Module class.
Module.__set_module_of_env(ModEnv, Module)

---@class mod_env_kv: object_kv
---@field public module Module

---Intialize the receiver
---@param kv mod_env_kv
function ModEnv.__:initialize(kv)
  assert(rawget(kv.module, "env") == nil)
  Module.__set_module_of_env(self, kv.module)
  assert(Module.__get_module_of_env(self) == kv.module)
  self._G = self
  self.__detour_saved_G = _G -- this is the only available exposition of _G
  -- NB loadfile/dofile are ignored within code chunks
end

function ModEnv.__.getter:maindir()
  local module = Module.__get_module_of_env(self)
  local main_module = assert(module.main_module)
  return main_module.path
end

local default_keys = {
  abspath                            = "function",
  asciiengines                       = "string[]",
  auxfiles                           = "string[]",
  bakext                             = "string",
  basename                           = "function",
  biber                              = "function",
  biberexe                           = "string",
  biberopts                          = "string",
  bibfiles                           = "string[]",
  bibtex                             = "function",
  bibtexexe                          = "string",
  bibtexopts                         = "string",
  binaryfiles                        = "string[]",
  bstfiles                           = "string[]",
  builddir                           = "string",
  bundle                             = "string",
  call                               = "function",
  checkconfigs                       = "string[]",
  checkdeps                          = "string[]",
  checkengines                       = "string[]",
  checkfiles                         = "string[]",
  checkformat                        = "string",
  checkinit_hook                     = "function",
  checkopts                          = "string",
  checkruns                          = "number",
  checksearch                        = "boolean",
  checksuppfiles                     = "string[]",
  cleandir                           = "function",
  cleanfiles                         = "string[]",
  config                             = "string",
  config_suffix                      = "string",
  cp                                 = "function",
  ctandir                            = "string",
  ctanpkg                            = "string",
  ctanreadme                         = "string",
  ctanupload                         = "boolean",
  ctanzip                            = "string",
  curl_debug                         = "boolean",
  curlexe                            = "string",
  demofiles                          = "string",
  direxists                          = "function",
  dirname                            = "function",
  distribdir                         = "string",
  docfiledir                         = "string",
  docfiles                           = "string[]",
  docinit_hook                       = "function",
  dviext                             = "string",
  dynamicfiles                       = "string[]",
  epoch                              = "number",
  exclmodules                        = "string[]",
  excludefiles                       = "string[]",
  excludetests                       = "string[]",
  fileexists                         = "function",
  filelist                           = "function",
  flatten                            = "boolean",
  flattenscript                      = "boolean",
  flattentds                         = "boolean",
  forcecheckepoch                    = "boolean",
  forcedocepoch                      = "string",
  glob_to_pattern                    = "function",
  glossarystyle                      = "string",
  includetests                       = "string[]",
  indexstyle                         = "string",
  install_files                      = "function",
  installfiles                       = "string[]", -- Who dared to choose these names ?
  jobname                            = "function",
  localdir                           = "string",
  logext                             = "string",
  lveext                             = "string",
  lvtext                             = "string",
  maindir                            = "string",
  makeindex                          = "function",
  makeindexexe                       = "string",
  makeindexfiles                     = "string[]",
  makeindexopts                      = "string",
  manifest_extract_filedesc          = "function",
  manifest_setup                     = "function",
  manifest_sort_within_group         = "function",
  manifest_sort_within_match         = "function",
  manifest_write_group_file          = "function",
  manifest_write_group_file_descr    = "function",
  manifest_write_group_heading       = "function",
  manifest_write_opening             = "function",
  manifest_write_subheading          = "function",
  manifestfile                       = "function",
  maxprintline                       = "number",
  mkdir                              = "function",
  module                             = "string",
  modules                            = "string[]",
  normalize_path                     = "function",
  options                            = "table",
  os_ascii                           = "string",
  os_cmpexe                          = "string",
  os_cmpext                          = "string",
  os_concat                          = "string",
  os_diffexe                         = "string",
  os_diffext                         = "string",
  os_grepexe                         = "string",
  os_null                            = "string",
  os_pathsep                         = "string",
  os_setenv                          = "string",
  os_yes                             = "string",
  packtdszip                         = "boolean",
  path_matcher                       = "function",
  pdfext                             = "string",
  ps2pdfopt                          = "string",
  ps2pdfopts                         = "string",
  psext                              = "string",
  pvtext                             = "string",
  recordstatus                       = "boolean",
  ren                                = "function",
  resultdir                          = "string",
  rm                                 = "function",
  run                                = "function",
  runcmd                             = "function",
  runtest_tasks                      = "function",
  scriptfiles                        = "string[]",
  scriptmanfiles                     = "string[]",
  sourcefiledir                      = "string",
  sourcefiles                        = "string[]",
  specialformats                     = "table",
  specialtypesetting                 = "table",
  splitpath                          = "function",
  stdengine                          = "string",
  supportdir                         = "string",
  tag_hook                           = "function",
  tagfiles                           = "string[]",
  tdsdir                             = "string",
  tdslocations                       = "table",
  tdsroot                            = "string",
  test_order                         = "string[]",
  test_types                         = "table",
  testdir                            = "string",
  testfiledir                        = "string",
  testsuppdir                        = "string",
  tex                                = "function",
  texmfdir                           = "string",
  textfiledir                        = "string",
  textfiles                          = "string[]",
  tlgext                             = "string",
  tpfext                             = "string",
  typeset                            = "function",
  typeset_demo_tasks                 = "function",
  typesetcmds                        = "string",
  typesetdemofiles                   = "string[]",
  typesetdeps                        = "table",
  typesetdir                         = "string",
  typesetexe                         = "string",
  typesetfiles                       = "string[]",
  typesetopts                        = "string",
  typesetruns                        = "number",
  typesetsearch                      = "boolean",
  typesetsourcefiles                 = "string[]",
  typesetsuppfiles                   = "string[]",
  unpackdeps                         = "table",
  unpackdir                          = "string",
  unpackexe                          = "string",
  unpackfiles                        = "string[]",
  unpackopts                         = "string",
  unpacksearch                       = "boolean",
  unpacksuppfiles                    = "string[]",
  update_tag                         = "function",
  uploadconfig                       = "table",
  ["uploadconfig.announcement"]      = "string",
  ["uploadconfig.announcement_file"] = "string",
  ["uploadconfig.author"]            = "string",
  ["uploadconfig.bugtracker"]        = "string",
  ["uploadconfig.ctanPath"]          = "string",
  ["uploadconfig.curlopt_file"]      = "string",
  ["uploadconfig.description"]       = "string",
  ["uploadconfig.development"]       = "string",
  ["uploadconfig.email"]             = "string",
  ["uploadconfig.home"]              = "string",
  ["uploadconfig.license"]           = "string",
  ["uploadconfig.note"]              = "string",
  ["uploadconfig.note_file"]         = "string",
  ["uploadconfig.pkg"]               = "string",
  ["uploadconfig.repository"]        = "string",
  ["uploadconfig.summary"]           = "string",
  ["uploadconfig.support"]           = "string",
  ["uploadconfig.topic"]             = "string",
  ["uploadconfig.update"]            = "string",
  ["uploadconfig.uploader"]          = "string",
  ["uploadconfig.version"]           = "string",
  workdir                            = "string",
  zipexe                             = "string",
  zipopts                            = "string",
}

---@alias check_rewrite_f fun(path_in:   string, path_out: string, engine:   string, error_levels: error_level_n[]): error_level_n
---@alias check_compare_f fun(diff_file: string, tlg_file: string, log_file: string, cleanup: boolean, name: string, engine: string): error_level_n

---@class modlib_t
---@field public Module       Module
---@field public ModEnv       ModEnv
---@field public default_keys table<string,string|string[]>
---@field public rewrite_log  check_rewrite_f
-- At this stage, we are just preparing the definition the API of the module environment.
-- Both `rewrite_log`, `rewrite_pdf` and `compare_tlg` must exist
-- but we do not want to run these functions during testing
-- and we do not care about the real implementation.
-- This real implementation will be made while requiring the check module.
---@field public rewrite_pdf  check_rewrite_f
---@field public compare_tlg  check_compare_f
return {
  Module        = Module,
  ModEnv        = ModEnv,
  default_keys  = default_keys,
  rewrite_log   = function () error("rewrite_log is not implemented, require the check module") end, -- do nothing yet, will be implemented by the check module
  rewrite_pdf   = function () error("rewrite_pdf is not implemented, require the check module") end, -- same
  compare_tlg   = function () error("compare_tlg is not implemented, require the check module") end, -- sample
}
