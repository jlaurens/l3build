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

---@module module

require("l3b-pathlib")

---@type fslib_t
local fslib = require("l3b-fslib")
local file_exists = fslib.file_exists

----@type Object
local Object = require("l3b-object")

---@type modlib_t
local modlib = require("l3b-modlib")

---@type Module
local Module = modlib.Module

-- Package implemenation

---@class Module: Object
---@field public path           string    @ the root path of the module
---@field public env            ModEnv @ the env of the receiver
---@field public is_main        boolean
---@field public parent_module  Module|nil
---@field public main_module    Module    @ may be self is the module is main
---@field public Dir            Module.Dir
---@field public dir            Module.Dir

function Module.__.getter:is_main()
  return self.parent == nil
end

---Load and run the `build.lua` file
---Static method when `dir` is provided,
---and instance method otherwise.
---`dir` defaults to the receiver's `path`.
---ENV is ignored when dir is not provided,
---and defaults to `_G` otherwise.
---@param dir? string
---@param ENV? ModEnv @ used as env, defaults to a readonly _G
---@param protected? boolean
function Module:load_build(dir, ENV, protected)
  local is_self
  if type(dir) ~= "string" then
    dir, ENV, protected = self.path, dir, ENV
    is_self = true
  else
    is_self = false
  end
  if type(ENV) ~= "table" then
    ENV, protected = nil, ENV
  end
  local path = ( dir or self.path ) / "build.lua"
  assert(file_exists(path), "Inconsistent module: no build.lua")
  if is_self then
    self:call_handlers_for_name("will load build.lua")
  end
  local f, msg = loadfile(path, "t", is_self and ( ENV or self.env.G ) or self.env)
  if not f then
    error(msg)
  end
  f() -- ignore any output, make a protected call?
  if is_self then
    self:call_handlers_for_name("did load build.lua")
    -- one shot
    self.load_build = function () end
  end
end

---Register the custom options.
---Load and execute an `options.lua`.
---Static method when `dir` is provided,
---and instance method otherwise.
---`dir` defaults to the receiver's `path`
---such that `options.lua`, if any, is near `build.lua`.
---ENV is ignored when dir is not provided.
---In that case, ENV defaults to `_G`.
---Otherwise, the receiver's `env` is used.
---@param dir? string
---@param ENV? table @ used as env, defaults to _G
function Module:register_custom_options(dir, ENV)
  local path = ( dir or self.path ) / "options.lua"
  if file_exists(path) then
    local f, msg = loadfile(path, "t", dir and ( ENV or _G ) or self.env)
    if not f then
      error(msg)
    end
    self:call_handlers_for_name("will_register_custom_options")
    f()
    self:call_handlers_for_name("did_register_custom_options")
  end
end

-- Populate Env
--[[
The environment of a module is an object with a dedicated class

--]]

---@class Module.Dir
---@field public module       Module @ Owner
---@field public work         string @Directory with the `build.lua` file.
---@field public main         string @Top level directory for the module|bundle
---@field public docfile      string @Directory containing documentation files
---@field public sourcefile   string @Directory containing source files
---@field public support      string @Directory containing general support files
---@field public testfile     string @Directory containing test files
---@field public testsupp     string @Directory containing test-specific support files
---@field public texmf        string @Directory containing support files in tree form
---@field public textfile     string @Directory containing plain text files
---@field public build        string @Directory for building and testing
---@field public distrib      string @Directory for generating distribution structure
---@field public local        string @Directory for extracted files in sandboxed TeX runs
---@field public result       string @Directory for PDF files when using PDF-based tests
---@field public test         string @Directory for running tests
---@field public typeset      string @Directory for building documentation
---@field public unpack       string @Directory for unpacking sources
---@field public ctan         string @Directory for organising files for CTAN
---@field public tds          string @Directory for organised files into TDS structure

---@type Module.Dir
Module.Dir = Object:make_subclass("Module.Dir")

function Module.Dir.__:intialize(module)
  self.module = module
end

function Module.Dir.__.getter:main()
  local main = self.module.main_module

  return
end

local declare = function (x) end
declare({
  maindir = {
    description = "Top level directory for the module/bundle",
    index = function (env, k)
      if env.is_embedded then
        -- retrieve the maindir from the main build.lua
        local s = get_main_variable(k)
        if s then
          return s / "."
        end
      end

      return l3build.main_dir / "."
    end,
  },
  supportdir = {
    description = "Directory containing general support files",
    index = function (env, k)
      return env.maindir / "support"
    end,
  },
  texmfdir = {
    description = "Directory containing support files in tree form",
    index = function (env, k)
      return env.maindir / "texmf"
    end
  },
  builddir = {
    description = "Directory for building and testing",
    index = function (env, k)
      return env.maindir / "build"
    end
  },
  docfiledir = {
    description = "Directory containing documentation files",
    value       = dot_dir,
  },
  sourcefiledir = {
    description = "Directory containing source files",
    value       = dot_dir,
  },
  testfiledir = {
    description = "Directory containing test files",
    index = function (env, k)
      return dot_dir / "testfiles"
    end,
  },
  testsuppdir = {
    description = "Directory containing test-specific support files",
    index = function (env, k)
      return env.testfiledir / "support"
    end
  },
  -- Structure within a development area
  textfiledir = {
    description = "Directory containing plain text files",
    value       = dot_dir,
  },
  distribdir = {
    description = "Directory for generating distribution structure",
    index = function (env, k)
      return env.builddir / "distrib"
    end
  },
  -- Substructure for CTAN release material
  localdir = {
    description = "Directory for extracted files in 'sandboxed' TeX runs",
    index = function (env, k)
      return env.builddir / "local"
    end
  },
  resultdir = {
    description = "Directory for PDF files when using PDF-based tests",
    index = function (env, k)
      return env.builddir / "result"
    end
  },
  testdir = {
    description = "Directory for running tests",
    index = function (env, k)
      return env.builddir / "test" .. env.config_suffix
    end
  },
  typesetdir = {
    description = "Directory for building documentation",
    index = function (env, k)
      return env.builddir / "doc"
    end
  },
  unpackdir = {
    description = "Directory for unpacking sources",
    index = function (env, k)
      return env.builddir / "unpacked"
    end
  },
  ctandir = {
    description = "Directory for organising files for CTAN",
    index = function (env, k)
      return env.distribdir / "ctan"
    end
  },
  tdsdir = {
    description = "Directory for organised files into TDS structure",
    index = function (env, k)
      return env.distribdir / "tds"
    end
  },
  workdir = {
    description = "Working directory",
    index = function (env, k)
      return l3build.work_dir:sub(1, -2) -- no trailing "/"
    end
  },
  config_suffix = {
    -- overwritten after load_unique_config call
    index = function (env, k)
      return ""
    end,
  },
})

return Module
