--[[

File l3b-lpeglib.lua Copyright (C) 2018-2020 The LaTeX Project

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
  This module only relies on lpeg.
  It defines some patterns for standard string matching and opertions.
--]===]
---@module lpeglib

local print   = print
local push    = table.insert
local concat  = table.concat

local lpeg    = require("lpeg")
local locale  = lpeg.locale()
local P       = lpeg.P
local Cmt     = lpeg.Cmt
local S       = lpeg.S
local R       = lpeg.R
local B       = lpeg.B
local C       = lpeg.C
local Cc      = lpeg.Cc
local Cf      = lpeg.Cf

---@class lpeg_t @ convenient type for lpeg patterns
---@alias lpeg_grammar_t table<string|number,lpeg_t> @ convenient type for lpeg grammar

---@type lpeg_t
local white_p = S(" \t")          -- exclude "\n", no unicode space neither.

---@type lpeg_t
local eol_p   = (
  P("\n") -- consume an eol
)^-1      -- 0 or 1 end of line

local ascii_p     = R("\x00\x7F") -- one ascii char

local more_utf8   = R("\x80\xBF")

local strict_utf8_2_p =
  R("\xC2\xDF") * more_utf8
local strict_utf8_3_p =
    P("\xE0")     * R("\xA0\xBF") * more_utf8
  + P("\xED")     * R("\x80\x9F") * more_utf8
  + R("\xE1\xEF") * more_utf8     * more_utf8
local strict_utf8_4_p =
    P("\xF0")     * R("\x90\xBF") * more_utf8 * more_utf8
  + P("\xF4")     * R("\x80\x8F") * more_utf8 * more_utf8
  + R("\xF1\xF3") * more_utf8     * more_utf8 * more_utf8

local strict_utf8_p =
      strict_utf8_2_p
    + strict_utf8_3_p
    + strict_utf8_4_p

local utf8_p      = ascii_p + strict_utf8_p

local alt_ascii_p = R("\x00\x7F") - P("\n") -- one ascii char but a newline
local alt_utf8_p  = alt_ascii_p + strict_utf8_p

---@type lpeg_t
local black_p = utf8_p - S(" \t\n") -- non horizontal space, non LF

-- black_p has no fixed length and can't be backed matched
---@type lpeg_t
local after_no_black_p =
    B( S(" \t\n") )
  + - B(ascii_p)
  * - B(strict_utf8_2_p)
  * - B(strict_utf8_3_p)
  * - B(strict_utf8_4_p)

local consume_1_character_p =
    alt_utf8_p
  + Cmt(
    1 - P("\n"),   -- and consume one byte for an erroneous UTF8 character
    function (s, i)
      _G.UFT8_DECODING_ERROR = true
      print("UTF8 problem ".. s:sub(i-1, i-1))
    end
  )

---Pattern with horizontal spaces before and after
---@param del string|number|table|lpeg_t
---@return lpeg_t
local function get_spaced_p(del)
  return white_p^0 * del * white_p^0
end

---@type lpeg_t
local spaced_colon_p = get_spaced_p(":")

---@type lpeg_t
local spaced_comma_p = get_spaced_p(",")

local variable_p =
    ("_" + locale.alpha)      -- ascii letter, or "_"
  * ("_" + locale.alnum)^0    -- ascii letter, or "_" or digit

-- for a class, type name
local identifier_p =
  variable_p * ("." * variable_p)^0

-- for a function
local function_name_p =
    variable_p
  * ( P(".") * variable_p )^0
  * ( P(":") * variable_p )^-1

local function get_base_class(str)
  ---@type lpeg_t
  local p = Cf(
      Cc({
        parents = {}, -- new table at each run
      })
    * C(variable_p)
    * ( P(".") * C(variable_p) )^0
    * ( P(":") * C(variable_p) )^-1,
    function (t, base)
      push(t.parents, t.base)
      t.base = base
      return t
    end
  )
  local t = p:match(str)
  return t.base,
    #t.parents > 0
      and concat(t.parents, ".")
      or  nil
end

  
---@class lpeglib_t
---@field public white_p                lpeg_t
---@field public black_p                lpeg_t
---@field public after_no_black_p       lpeg_t
---@field public eol_p                  lpeg_t
---@field public alt_ascii_p            lpeg_t
---@field public alt_utf8_p             lpeg_t
---@field public consume_1_character_p  lpeg_t
---@field public get_spaced_p           fun(p: lpeg_t): lpeg_t
---@field public spaced_colon_p         lpeg_t
---@field public spaced_comma_p         lpeg_t
---@field public variable_p             lpeg_t
---@field public identifier_p           lpeg_t
---@field public function_name_p        lpeg_t

return {
  white_p               = white_p,
  black_p               = black_p,
  after_no_black_p      = after_no_black_p,
  eol_p                 = eol_p,
  ascii_p               = ascii_p,
  utf8_p                = utf8_p,
  alt_ascii_p           = alt_ascii_p,
  alt_utf8_p            = alt_utf8_p,
  get_spaced_p          = get_spaced_p,
  spaced_colon_p        = spaced_colon_p,
  spaced_comma_p        = spaced_comma_p,
  consume_1_character_p = consume_1_character_p,
  variable_p            = variable_p,
  identifier_p          = identifier_p,
  function_name_p       = function_name_p,
  get_base_class        = get_base_class,
}
