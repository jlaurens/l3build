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

----@type Object
local Object = require("l3b-object")

----@type Env
local Env = require("l3b-env")

--@type l3build_t
local l3build = require("l3build")
local find_container_up = l3build.find_container_up

-- Package implementation

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
function Module.__unique_instance(kv)
  return unique[kv.path / "."]
end

---Store the revceiver as unique `Module`
function Module:__make_unique_instance()
  unique[self.path] = self
end

---Initialize the receiver.
---@param kv module_kv
---@return nil|string @ nil on success, an error message on failure.
function Module:__initialize(kv)
  local up = find_container_up(kv.path,  "build.lua")
  if not up then
    return "No module at ".. kv.path
  end
  self.path = up / "."
  self.env = ModEnv({ module = self })
end

function Module.__class_table:path()
  return "path of virtual module"
end

function Module.__class_table:env()
  local result = ModEnv({ module = self })
  self:cache_set("env", result)
  return result
end

function Module.__instance_table:parent_module()
  if self.is_main then
    return nil
  end
  local up = find_container_up(self.path / "..",  "build.lua")
  if up then
    self.is_main = false
    local parent = Module({ path = up })
    rawset(self, "parent_module", parent)
    return parent
  end
end

function Module.__class_table:main_module()
  if not self.is_main then
    local parent = self.parent_module
    if parent then
      local main = parent.main_module or parent
      rawset(self, "main_module", main)
      return assert(main)
    end
  end
  rawset(self, "main_module", self)
  return assert(self)
end


local MODULE = {} -- unique tag for an unexposed private property

---Static method to retrieve the module of a module environment
---@param env ModEnv
---@return any
function Module.__get_module_of_env(env)
  assert(env:is_descendant_of(ModEnv)) -- to prevent foo:__get_module_of_env
  return env:__get_private_property(MODULE)
end

---Static method to set the module of a module environment
---@generic T: ModEnv
---@param env     T
---@param module  Module
---@return T @ self
function Module.__set_module_of_env(env, module)
  assert(env:is_descendant_of(ModEnv)) -- to prevent foo:__set_module_of_env
  return env:__set_private_property(MODULE, module)
end


-- The ModeEnv class has an associate virtual module
-- which is simply the Module class.
Module.__set_module_of_env(ModEnv, Module)

---@class mod_env_kv: object_kv
---@field public module Module

---Intialize the receiver
---@param kv mod_env_kv
function ModEnv:__initialize(kv)
  assert(rawget(kv.module, "env") == nil)
  Module.__set_module_of_env(self, kv.module)
  assert(Module.__get_module_of_env(self) == kv.module)
  self._G = self
  self.__detour_saved_G = _G -- this is the only available exposition of _G
  -- NB loadfile/dofile are ignored within code chunks
end

function ModEnv.__class_table:maindir()
  local module = Module.__get_module_of_env(self)
  local main_module = assert(module.main_module)
  return main_module.path
end


---@class modlib_t
---@field public Module Module
---@field public ModEnv ModEnv
return {
  Module = Module,
  ModEnv = ModEnv,
}
