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
Define the `ModEnv` class as model to a module environment.
--]===]
---@module modenv

require("l3b-pathlib")

----@type Env
local Env = require("l3b-env")

-- Module implemenation

---@class ModEnv: Env
---@type ModEnv
local ModEnv = Env:make_subclass("ModuleEnv")

local MODULE = {} -- unique tag for an unexposed private property

function ModEnv:__initialize(module)
  self:set_private_property(MODULE, module)
  assert(self:get_private_property(MODULE) == module)
end

---Computed property
---@param self ModEnv
---@return Module
ModEnv.__class_table[MODULE] = function (self)
  return self:get_private_property(MODULE)
end

---comment
---@param self any
---@return Module
function ModEnv.__class_table.maindir(self)
  return self[MODULE].main_module.path
end


return ModEnv,
---@class __modenv_t
---@field private MODULE any
_ENV.during_unit_testing and {
  MODULE = MODULE
}
