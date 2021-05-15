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

----@type Object
local Object = require("l3b-object")

---@type fslib_t
local fslib = require("l3b-fslib")
local file_exists = fslib.file_exists

--@type l3build_t
local l3build = require("l3build")
local find_container_up = l3build.find_container_up

-- Module implemenation

---@class Module: Object
---@field public path           string  @ the root path of the module
---@field public _ENV           table   @ the _ENV of the receiver
---@field public is_main        boolean
---@field public parent_module  Module|nil
---@field public main_module    Module
---@field public dir            Module.Dir

---@type Module
local Module = Object:make_subclass("Module")

function Module:__initialize(path)
  self.path = path
  self._ENV = setmetatable({}, {
    __index = _G,
  })
  self.dir = Module.Dir(self)
end

function Module.__instance_table:is_main()
  return self.parent == nil
end

function Module.__instance_table:parent_module()
  if self.is_main then
    return nil
  end
  local up = find_container_up(self.path / "..",  "build.lua")
  if up then
    self.is_main = false
    local parent = Module(up)
    rawset(self, "parent_module", parent)
    return parent
  end
end

function Module.__instance_table:main_module()
  if self.is_main then
    rawset(self, "main_module", self)
    return self
  end
  local parent = self.parent_module
  local main = parent.main_module or parent
  rawset(self, "main_module", main)
  return main
end

function Module:load_build()
  local path = self.path / "build.lua"
  assert(file_exists(path), "Inconsistent module: no build.lua")
  local f, msg = loadfile(path, "t", self._ENV)
  if not f then
    error(msg)
  end
  self:call_hook_handlers_for_name("will load build.lua", module)
  f() -- ignore any output, make a protected call?
  self:call_hook_handlers_for_name("did load build.lua")
end

---@class Module.Dir
---@field public Module       Module @ Owner
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

function Module.Dir:__intialize(module)
  self.module = module
end

function Module.Dir.__instance_table:main()
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
