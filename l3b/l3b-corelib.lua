--[[

File l3b-corelib.lua Copyright (C) 2018-2020 The LaTeX Project

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

-- Autodoc lpeg patterns

---@module l3b-peg

-- Safeguard and shortcuts

local unpack  = table.unpack
local concat  = table.concat
local max     = math.max

local lpeg    = require("lpeg")
local locale  = lpeg.locale()
local P       = lpeg.P
local R       = lpeg.R
local S       = lpeg.S
local C       = lpeg.C
local V       = lpeg.V
local B       = lpeg.B
local Cb      = lpeg.Cb
local Cc      = lpeg.Cc
local Cg      = lpeg.Cg
local Cmt     = lpeg.Cmt
local Cp      = lpeg.Cp
local Ct      = lpeg.Ct

--[[ lpeg patterns
All forthcoming variables with suffix "_p" are
lpeg patterns or functions that return a lpeg pattern.
--]]

---@class lpeg_t @ convenient type for lpeg patterns

---@type lpeg_t
local white_p = S(" \t")          -- exclude "\n", no unicode space neither.

---@type lpeg_t
local black_p = P(1) - S(" \t\n") -- non space, non LF

---@type lpeg_t
local eol_p   = (
  P("\n") -- consume an eol
)^-1      -- 0 or 1 end of line

local ascii_p       = R("\x00\x7F") - P("\n") -- ones ascii char but a newline
local more_utf8   = R("\x80\xBF")
local utf8_p        =
    ascii_p
  + R("\xC2\xDF") * more_utf8
  + P("\xE0")     * R("\xA0\xBF") * more_utf8
  + P("\xED")     * R("\x80\x9F") * more_utf8
  + R("\xE1\xEF") * more_utf8     * more_utf8
  + P("\xF0")     * R("\x90\xBF") * more_utf8 * more_utf8
  + P("\xF4")     * R("\x80\x8F") * more_utf8 * more_utf8
  + R("\xF1\xF3") * more_utf8     * more_utf8 * more_utf8

local consume_1_character_p =
    utf8_p
  + Cmt( 1 - P("\n"),   -- and consume one byte for an erroneous UTF8 character
    function (s, i) print("UTF8 problem ".. s:sub(i-1, i-1)) end
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
  * ( P(".")  * variable_p )^0
  * ( P(":") * variable_p )^-1

---Get the line number for the given string
---Should cache intermediate results.
---@param str   string
---@param index integer
---@return integer
local function get_line_number(str, index)
  local result = 1
  for j = 1, index do
    if str:sub(j, j) == "\n" then
      result = result + 1
    end
  end
  return result
end

local dot_p = P(".")
local no_dot_p = P(1) - dot_p
local base_extension_p = Ct(
    C( no_dot_p^0) * ( dot_p * C( no_dot_p^0 ) )^0
  ) / function (t)
    local last = max(1, #t - 1) -- last index of the base part
    return {
      base = concat({ unpack(t, 1, last) }, "."),
      extension = unpack(t, last + 1, #t) or "",
    }
  end

string.l3b_base_extension = function (self)
  return base_extension_p:match(self)
end

---@class corelib_t
---@field public white_p                lpeg_t
---@field public black_p                lpeg_t
---@field public eol_p                  lpeg_t
---@field public ascii_p                lpeg_t
---@field public utf8_p                 lpeg_t
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
  eol_p                 = eol_p,
  ascii_p               = ascii_p,
  utf8_p                = utf8_p,
  get_spaced_p          = get_spaced_p,
  spaced_colon_p        = spaced_colon_p,
  spaced_comma_p        = spaced_comma_p,
  consume_1_character_p = consume_1_character_p,
  variable_p            = variable_p,
  identifier_p          = identifier_p,
  function_name_p       = function_name_p,
  get_line_number       = get_line_number,
}
