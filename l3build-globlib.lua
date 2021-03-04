--[[

File l3build-globlib.lua Copyright (C) 2018-2020 The LaTeX Project

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

--[=[ Usage:
local gblib           = require("l3b.globlib")
local glob_to_pattern = gblib.glob_to_pattern
--]=]

local print            = print

local match            = string.match
local sub              = string.sub

---@type utlib_t
local utlib        = require("l3b.utillib")
local extend_with = utlib.extend_with

-- Convert a file glob into a pattern for use by e.g. string.gub
-- Based on https://github.com/davidm/lua-glob-pattern
-- Simplified substantially: "[...]" syntax not supported as is not
-- required by the file patterns used by the team. Also note style
-- changes to match coding approach in rest of this file.
--
-- License for original globtopattern
--[[

   (c) 2008-2011 David Manura.  Licensed under the same terms as Lua (MIT).

  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in
  all copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
  THE SOFTWARE.
  (end license)

--]]

---Make a glob into a pattern
---@param glob string
---@return string
local function glob_to_pattern(glob)

  local pattern = "^" -- pattern being built
  local i = 0 -- index in glob
  local char -- char at index i in glob

  -- escape pattern char
  local function escape(char)
    return match(char, "^%w$") and char or "%" .. char
  end

  -- Convert tokens.
  while true do
    i = i + 1
    char = sub(glob, i, i)
    if char == "" then
      pattern = pattern .. "$"
      break
    elseif char == "?" then
      pattern = pattern .. "."
    elseif char == "*" then
      pattern = pattern .. ".*"
    elseif char == "[" then
      -- Ignored
      print("[...] syntax not supported in globs!")
    elseif char == "\\" then
      i = i + 1
      char = sub(glob, i, i)
      if char == "" then
        pattern = pattern .. "\\$"
        break
      end
      pattern = pattern .. escape(char)
    else
      pattern = pattern .. escape(char)
    end
  end
  return pattern
end

-- this is the map to export function symbols to the global space
local global_symbol_map = {
  glob_to_pattern = glob_to_pattern,
}

--[=[ Export function symbols ]=]
extend_with(_G, global_symbol_map)
-- [=[ ]=]

---@class gblib_t
---@field glob_to_pattern   fun(glob: string): string

return {
  global_symbol_map = global_symbol_map,
  glob_to_pattern   = glob_to_pattern,
}
