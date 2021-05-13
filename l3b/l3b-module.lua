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

---@type Object
local Object = require("l3b-object")

---@class Module: Object
---@field public path string @ the root path of the module
---@field protected ENV table @ the env of the receiver

---@type Module
local Module = Object:make_subclass("Module")

function Module:__initialize(path)
  self.path = path
  self.ENV = setmetatable({}, {
    __index = _G,
  })
end

return Module
