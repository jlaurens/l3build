--[[

File l3b-environment.lua Copyright (C) 2018-2020 The LaTeX Project

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

An Env instance is suitable for lua environments.

The particularity is the activation process.
When used as a lua environment, we must have access to
global and (possibly) Object inherited properties.
When used as simple data table, global
and object properties are no longer inherited.

--]===]
---@module env

---@type Object
local Object = require("l3b-object")

-- module implementation

---@visibility private
---@class Env00: Object

local Env00 = Object:make_subclass("Env00")

local INACTIVE = {}

function Env00:__computed_index(k)
  local kk = rawget(Env00, INACTIVE)
  if kk then
    return Object.NIL
  end
  local result = Env00[k]
  if result ~= nil then
    return result
  end
  return _G[k]
end

---@visibility private
---@class Env0: Env00
---@type Env0
local Env0 = Env00:make_subclass("Env0")

function Env0:__computed_index(k)
  local inactive = Object.__get_private_property(self, INACTIVE)
  if inactive then
    rawset(Env00, INACTIVE, k)
  end
  return nil
end

---Last filter before return
---Subclassers must call this filter when overriding.
---@generic T: any
---@param k any
---@param v T
---@return T
function Env0.__index_will_return(k, v)
  local kk = rawget(Env00, INACTIVE)
  if kk then
    if k == kk then
      rawset(Env00, INACTIVE, nil)
    end
  end
  return v
end

---@class Env: Object
local Env = Env0:make_subclass("Env")

---Activate the environment
---Active environments inherit properties
---and methods from `Object` and `_G`.
---@param env Env
function Object.activate_env(env)
  Object.__set_private_property(env, INACTIVE, nil)
end

---Deactivate the environment
---Inactive environments do not inherit properties
---and methods from `Object` nor `_G`.
---@param env Env
function Object.deactivate_env(env)
  Object.__set_private_property(env, INACTIVE, true)
end

return Env
