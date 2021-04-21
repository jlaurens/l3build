--[[

File l3b-autodoc+pattern.lua Copyright (C) 2018-2020 The LaTeX Project

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

---@module l3b-autodoc

-- Safeguard and shortcuts

local get_line_number = _G.get_line_number

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

local tag_temp = {}
-- Implementation

--[[ lpeg patterns
All forthcoming variables with suffix "" are
lpeg patterns or functions that return a lpeg pattern.
These patterns implement a subset of lua grammar
to recognize embedded documentation.
--]]

--[[ The embedded documentation grammar

We must look for the lua scope in order to resolve some
missing names. Function names must sometimes be guessed
from the code, which implies some parsing.

For that, we mainly recognize lua comments and literals,
everything else is a code chunk.

We keep track of the parser position in named captures.

--]]

---@class lpeg.Pattern @ convenient type

---@type lpeg.Pattern
local white = S(" \t")          -- exclude "\n", no unicode space neither.

---@type lpeg.Pattern
local black = P(1) - S(" \t\n") -- non space, non LF

---@type lpeg.Pattern
local eol   = (
  P("\n") -- consume an eol
)^-1      -- 0 or 1 end of line

local variable =
    ("_" + locale.alpha)      -- ascii letter, or "_"
  * ("_" + locale.alnum)^0    -- ascii letter, or "_" or digit

-- for a class, type name
local identifier =
  variable * ("." * variable)^0

-- for a class, type name
local fun =
  variable * (S(".:") * variable)^0

---Capture the current position under the given name with the given shifht
---@param str string
---@param shift number
---@return lpeg.Pattern
-- This is a one line doc for testing purposes
local function named_pos(str, shift)
  return  Cg(shift
      and Cp() / function (i) return i - shift end
      or  Cp(),
    str)
end

-- Named captures must exist before use.
-- Prefix any pattern with `chunk_init`
-- such that named captures are defined at the top level.
---@type lpeg.Pattern
local chunk_init =
    named_pos("min")
  * named_pos("max", 1)

---Prepare the match of a new chunk
---In order to further insert a code chunk info if necessary
---create it and save it as capture named "code_before".
---@type lpeg.Pattern
local chunk_start =
  Cg( Cb("min"), "min")

---End of chunk pattern
--[===[
This pattern is used at the end of the current logical chunk.
Advance the cursor to the end of line or end of file,
then store the position in the capture named "max".
--]===]
---@type lpeg.Pattern
local chunk_stop =
    white^0
  * P("\n")^-1
  * named_pos("max", 1)
  -- no capture
  -- the current position becomes the next chunk min

---@type lpeg.Pattern
local one_line_chunk_stop =
  ( 1 - P("\n") )^0 -- anything but a newline
  * chunk_stop

---@type lpeg.Pattern
local special_begin =
  ( white^1 + -B("-") ) -- 1+ spaces or negative lookbehind: no "-" behind
  * P("---") * -P("-")
  * white^0

---Pattern with horizontal spaces before and after
---@param del string|number|table|lpeg.Pattern
---@return lpeg.Pattern
local function get_spaced(del)
  return white^0 * del * white^0
end

---@type lpeg.Pattern
local colon = get_spaced(":")

---@type lpeg.Pattern
local comma = get_spaced(",")

---@type lpeg.Pattern
local capture_comment = (
      get_spaced("@")
    * named_pos("content_min")
    * black^0
    * ( white^1 * black^1 )^0
    * named_pos("content_max", 1)
    * white^0
  )
  + Cmt(
    black,
    function (s, i)
      error("Missing @ for a comment at line "
        .. get_line_number(s, i - 1)
        ..": ".. s:sub(i - 1, i + 50))
    end
  )
  + (
      named_pos("content_min")
    * named_pos("content_max", 1)
    * white^0
  )

---Sub grammar for lua types
---@type lpeg.Pattern
local lua_type = P({
  "type",
  type =
    (V("table")
    + V("fun")
    + identifier
    )
    * (get_spaced("[") -- for an array: `string[]`
      * get_spaced("]")
    )^0,
  table =
    P("table")   -- table<foo,bar>
    * (get_spaced("<")
      * V("type")
      * comma
      * V("type")
      * get_spaced(">")
    )^-1,
  fun =
      P("fun")
    * get_spaced("(")
    * (
        V("fun_params") * comma * V("fun_vararg")
      + V("fun_params")
      + V("fun_vararg")^-1
    )
    * get_spaced(")")
    * V("fun_return")^-1,
  fun_vararg =
    P("..."),
  fun_param =
    variable * colon * V("type"),
  fun_params =
    V("fun_param") * (comma * V("fun_param"))^0,
  fun_return =
      colon
    * V("type")
    * (comma * V("type"))^0,
})

---@type lpeg.Pattern
local named_types = Cg( Ct(-- collect all the captures in an array
    C(lua_type)
  * ( get_spaced("|") * C(lua_type) )^0
), "types")


---@type lpeg.Pattern
local named_optional =
    white^0 * Cg(P("?") * Cc(true) , "optional") * white^0
  + Cg(Cc(false), "optional") * white^0

---Capture the pattern "---@<name>..."
---@param name string
---@return lpeg.Pattern
local function at_match(name)
  return
      special_begin
    * P("@".. name)
    * -black
    * white^0
end

---comment
---@param Key string
---@return lpeg.Pattern
local error_annotation = function (Key)
  return Cmt(
      Cp()
    * one_line_chunk_stop,
    function (s, to, from)
      -- print(debug.traceback())
      error("Bad ".. Key .." annotation"
        .." at line ".. get_line_number(s, from)
        .. ": ".. s:sub(from, to))
    end
  )
end

local long_doc =
  chunk_init
  * Ct(
    ( white^1 + -B("-") ) -- 1+ spaces or no "-" before
    * P("--[===[")
    * eol
    * chunk_start
    * named_pos("content_min")
    * Cg(
      Cmt(
        P(0),
        function (s, i)
          local p = white^0 * P("-")^0 * P("]===]")
          for j = i, #s - 1 - 3 do
            local result = p:match(s, j)
            if result then
              return result, j - 1 -- capture `content_max`
            end
          end
          error("Missing delimiter `]===]`"
            .." after line ".. get_line_number(s, i - 1))
        end
      ),
      "content_max"
    )
    * chunk_stop
  )

local content =
    named_pos("content_min")
  * black^0
  * ( white^1 * black^1 )^0
  * named_pos("content_max", 1)

--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=

---One line comment
---@type lpeg.Pattern
local line_comment =
    chunk_init
  * ( white^1 + -B("-") )             -- 1+ spaces or no "-" before, the back test should never be reached
  * ( P("-")^4
    + P("--")
    * -P("-")                         -- >1 dashes, but not 3
    * -(P("[") * P("=")^0 * P("[")) -- no long comment
  )
  * white^0
  * Ct(
      chunk_start
    * content
    * chunk_stop
  )

---One line documentation
---@type lpeg.Pattern
local line_doc =
    chunk_init
  * special_begin
  * -P("@")       -- negative lookahead: not an annotation
  * white^0
  * Ct(
      chunk_start
    * content
    * chunk_stop
  )

local short_literal =
    chunk_init
    * Ct(
      white^0
    * Cg(S([['"]]), tag_temp)
    * chunk_start
    * named_pos("content_min")
    * Cg(
      Cmt(
        Cb(tag_temp),
        function (s, i, del)
          local j = i
          repeat
            local c = s:sub(j, j)
            if c == del then
              return j + 1, j - 1 -- capture also `content_max`
            elseif c == [[\]] then
              j = j + 2
            elseif c then
              j = j + 1
            else
              error("Missing closing delimiter " .. del
                .. " after line ".. get_line_number(s, i))
            end
          until false
        end
      ),
      "content_max"
    )
    * chunk_stop
  ) / function (t)
        t[tag_temp] = nil
        return t
      end

---@type lpeg.Pattern
local long_literal
do
  -- next patterns are used for both long literals and long comments
  local tag_temp = {}
  local open_p =
      P("[")
    * Cg( C(P("=")^0 ), tag_temp ) -- tagged capture of the equals
    * P("[")
    * eol                               -- optional EOL
    * named_pos("content_min")

  local close_p = Cg( Cmt(                 -- scan the string by hand
    Cb(tag_temp),
    function (s, i, equal)
      local p = white^0 * P("-")^0 * P("]") * equal * P("]")
      for j = i, #s - 1 - #equal do
        local result = p:match(s, j)
        if result then
          return result, j - 1, #equal -- 2 captured values: content_max and level
        end
      end
      error("Missing delimiter `]".. equal .."]`"
        .." after line ".. get_line_number(s, i - 1))
    end
  ), tag_temp)
  * Cg(
      Cb(tag_temp)
    / function (content_max, _)
        return content_max -- only the first captured value
      end,
    "content_max"
  )
  * Cg(
      Cb(tag_temp)
    / function (_, level)
        return level -- only the second captured value
      end,
    "level"
  )

  long_literal =
      chunk_init
    * Ct(
        open_p
      * chunk_start
      * close_p
      * chunk_stop
    ) / function (t)
          t[tag_temp] = nil
          return t
        end
end

---@type lpeg.Pattern
local long_comment

do
  -- next patterns are used for both long literals and long comments
  local tag_equal = {}
  local open_p =
      "["
    * Cg(P("=")^-2 + P("=")^4, tag_equal) -- tagged capture of the equals
    * "["
    * eol                               -- optional EOL
    * named_pos("content_min")

  local close_p = Cg(Cmt(                 -- scan the string by hand
    Cb(tag_equal),
    function (s, i, equal)
      local p = white^0 * P("-")^0 * P("]") * equal * P("]")
      for j = i, #s - 1 - #equal do
        local result = p:match(s, j)
        if result then
          return result, j - 1, #equal -- 2 captured values: content_max and level
        end
      end
      error("Missing delimiter `]".. equal .."]`"
        .." after line ".. get_line_number(s, i - 1))
    end
  ), tag_equal)
  * Cg(
      Cb(tag_equal)
    / function (content_max, _)
        return content_max -- only the first captured value
      end,
    "content_max"
  )
  * Cg(
      Cb(tag_equal)
    / function (_, level)
        return level -- only the second captured value
      end,
    "level"
  )

  ---@type lpeg.Pattern @ what makes the difference with a long literal
  local prefix =
  (white^1 + -B("-")) -- 1+ spaces or no "-" before
  * P("--")
  long_comment =
      chunk_init
    * prefix
    * Ct(
        open_p
      * chunk_start
      * close_p
      * chunk_stop
    ) / function (t)
          t[tag_equal] = nil
          return t
        end
end

local function get_annotation(KEY, core)
  return
      chunk_init
    * at_match(KEY) * (
      Ct(
          chunk_start
        * core
        * chunk_stop
      )
      + error_annotation(KEY)
    )
end

local core_field = Cg(
    P("public") + "protected" + "private",
    "visibility"
  )
  * white^1
  * Cg(
    variable,
    "name"
  )
  * white^1
  * named_types
  * capture_comment

local core_class =
    Cg(identifier, "name")
  * (colon * Cg(identifier, "parent"))^-1                 -- or nil
  * capture_comment

local core_type = named_types * capture_comment

local core_alias =
    Cg(identifier, "name")
  * white^1
  * named_types
  * capture_comment

local core_return =
    named_types
  * named_optional
  * capture_comment

local core_generic =
    Cg(variable, "type_1")          -- capture type_1
  * (colon
    * Cg(identifier, "parent_1")    -- and capture parent_1
  )^-1
  * (comma * (
      Cg(variable, "type_2")        -- capture type_2
    * (colon
      * Cg(identifier, "parent_2")  -- and capture parent_2
    )^-1
  ))^-1
  * capture_comment

local core_param =
    Cg(variable, "name")
  * named_optional
  * named_types
  * capture_comment

local core_vararg = core_type

local NAME_p = R("az", "09") * (R("az", "09") + S("_-."))^0

local core_module = Cg(NAME_p, "name") * capture_comment

local core_global =
    Cg(identifier, "name")
  * white^0
  * Cg(
    Ct(-- collect all the captures in an array
      ( C(lua_type)
        * ( get_spaced("|") * C(lua_type) )^0
      ) + P(0)
    ), "types")
  * capture_comment

local guess_function_name = P( {
  - B(black)
  * Ct(
      V("local function")
    + V("function ...")
    + V("local ... = function (")
    + V("... = function (")
  )
  * white^0
  * P("(")
  + ( P(1) - P("\n") ) * V(1), -- advance one character one the same line and try to match
  ["local function"] =
      P("local")
    * white^1
    * P("function")
    * white^1
    * Cg(
      variable,
      "name"
    )
    * Cg( Cc(true), "is_local"),
  ["function ..."] =
      P("function")
    * white^1
    * Cg(
      fun,
      "name"
    )
    * Cg( Cc(false), "is_local"),
  ["local ... = function ("] =
      P("local")
    * white^1
    * Cg(
      variable,
      "name"
    )
    * get_spaced("=")
    * P("function")
    * Cg( Cc(true), "is_local"),
  ["... = function ("] =
    Cg(
      fun,
      "name"
    )
    * get_spaced("=")
    * P("function")
    * Cg( Cc(false), "is_local"),
} )

local paragraph_break =
    chunk_init
  * Ct(                     -- 1) a table of named captures
    ( white^0 * P("\n") )^1
    * chunk_start
    * chunk_stop
  )

local more_utf8_p = R("\x80\xBF")
local utf8_p      =
    R("\x00\x7F") - P("\n") -- ones ascii char but a newline
  + R("\xC2\xDF") * more_utf8_p
  + P("\xE0")     * R("\xA0\xBF") * more_utf8_p
  + P("\xED")     * R("\x80\x9F") * more_utf8_p
  + R("\xE1\xEF") * more_utf8_p   * more_utf8_p
  + P("\xF0")     * R("\x90\xBF") * more_utf8_p * more_utf8_p
  + P("\xF4")     * R("\x80\x8F") * more_utf8_p * more_utf8_p
  + R("\xF1\xF3") * more_utf8_p   * more_utf8_p * more_utf8_p

local consume_1_character =
    utf8_p
  + Cmt( 1 - P("\n"),   -- and consume one byte for an erroneous UTF8 character
    function (s, i) print("UTF8 problem ".. s:sub(i-1, i-1)) end
  )

---@class AD.PTRN
---@field public line_comment     lpeg.Pattern
---@field public line_doc         lpeg.Pattern
---@field public short_literal    lpeg.Pattern
---@field public long_literal     lpeg.Pattern
---@field public long_comment     lpeg.Pattern
---@field public long_doc         lpeg.Pattern
---@field public get_annotation   fun(Key: string, core: lpeg.Pattern): lpeg.Pattern
---@field public core_field       lpeg.Pattern
---@field public core_class       lpeg.Pattern
---@field public core_type        lpeg.Pattern
---@field public core_alias       lpeg.Pattern
---@field public core_return      lpeg.Pattern
---@field public core_generic     lpeg.Pattern
---@field public core_param       lpeg.Pattern
---@field public core_vararg      lpeg.Pattern
---@field public core_module      lpeg.Pattern
---@field public core_global      lpeg.Pattern
---@field public guess_function_name  lpeg.Pattern
---@field public paragraph_break  lpeg.Pattern
---@field public consume_1_character  lpeg.Pattern
--
---@field public white        lpeg.Pattern
---@field public black        lpeg.Pattern
---@field public eol          lpeg.Pattern
---@field public variable     lpeg.Pattern
---@field public identifier   lpeg.Pattern
---@field public fun          lpeg.Pattern
---@field public named_pos    fun(str: string, shift: number): lpeg.Pattern
---@field public chunk_init   lpeg.Pattern
---@field public chunk_start  lpeg.Pattern
---@field public chunk_stop   lpeg.Pattern
---@field public one_line_chunk_stop lpeg.Pattern
---@field public special_begin lpeg.Pattern
---@field public get_spaced   fun(del: string|number|table|lpeg.Pattern): lpeg.Pattern
---@field public colon        lpeg.Pattern
---@field public comma        lpeg.Pattern
---@field public capture_comment  lpeg.Pattern
---@field public lua_type         lpeg.Pattern
---@field public named_types      lpeg.Pattern
---@field public named_optional   lpeg.Pattern
---@field public content          lpeg.Pattern
---@field public at_match         fun(name: string): lpeg.Pattern
---@field public error_annotation fun(Key: string): lpeg.Pattern

---@type AD.PTRN
local PTRN = {
  line_comment    = line_comment,
  line_doc        = line_doc,
  short_literal   = short_literal,
  long_literal    = long_literal,
  long_comment    = long_comment,
  long_doc        = long_doc,
  get_annotation  = get_annotation,
  core_field      = core_field,
  core_class      = core_class,
  core_type       = core_type,
  core_alias      = core_alias,
  core_return     = core_return,
  core_generic    = core_generic,
  core_param      = core_param,
  core_vararg     = core_vararg,
  core_module     = core_module,
  core_global     = core_global,
  guess_function_name = guess_function_name,
  paragraph_break = paragraph_break,
  consume_1_character = consume_1_character,

  white           = white,
  black           = black,
  eol             = eol,
  variable        = variable,
  identifier      = identifier,
  fun             = fun,
  named_pos       = named_pos,
  chunk_init      = chunk_init,
  chunk_start     = chunk_start,
  chunk_stop      = chunk_stop,
  one_line_chunk_stop = one_line_chunk_stop,
  special_begin   = special_begin,
  get_spaced      = get_spaced,
  colon           = colon,
  comma           = comma,
  capture_comment = capture_comment,
  lua_type        = lua_type,
  named_types     = named_types,
  named_optional  = named_optional,
  at_match        = at_match,
  error_annotation = error_annotation,
  content         = content,
}

return PTRN
