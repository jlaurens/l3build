--[[

File l3b-docmngr.lua Copyright (C) 2018-2020 The LaTeX Project

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

-- Documentation of module `docmngr`

---Documentation manager
--[===[
# Overview

This modules manages the documentation extracted from source files.
It translates this documentation to latex and save the result to some appropriate location.
Then it builds the documentation.

This module does not declare any user interface for this building action.

# Implementation details

Forthcoming documentation.

--]===]
---@module l3b-docmngr

-- Safeguard and shortcuts

local Object = require("l3b-object")

---@type utlib_t
local utlib = require("l3b-utillib")
local second_of = utlib.second_of




local AD = require("l3b-autodoc")

---@class DocManager: Object
---@field private __modules AD.Module[]

local DocManager = Object:make_subclass("DM", {
  __initialize = function(self, work_path)
    self.work_path = work_path
    self.__modules = {}
  end,
  __instance_table = {
    all_modules = function (self)
      local i = 0
      return function ()
        i = i + 1
        return self.__modules[i]
      end
    end
  },
})

function DocManager:get_module(path)
  
end

---@class docmngr_t
---@field public __modules AD.Module[] @ private list of modules

return DocManager
