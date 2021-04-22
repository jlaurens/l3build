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

---@type corelib_t
local corelib         = require("l3b-corelib")
local white_p         = corelib.white_p
local black_p         = corelib.black_p
local eol_p           = corelib.eol_p
local get_spaced_p    = corelib.get_spaced_p
local spaced_comma_p  = corelib.spaced_comma_p
local spaced_colon_p  = corelib.spaced_colon_p
local consume_1_character_p = corelib.consume_1_character_p
local variable_p      = corelib.variable_p
local identifier_p    = corelib.identifier_p
local function_name_p = corelib.function_name_p
local get_line_number = corelib.get_line_number

-- Implementation

local TAG = {}

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

---Capture the current position under the given name with the given shifht
---@param str string
---@param shift number
---@return lpeg_t
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
---@type lpeg_t
local chunk_init =
    named_pos("min")
  * named_pos("max", 1)

---Prepare the match of a new chunk
---Make a local copy of the capture named "min".
---@type lpeg_t
local chunk_start =
  Cg( Cb("min"), "min")

---End of chunk pattern
--[===[
This pattern is used at the end of the current logical chunk.
Advance the cursor to the end of line or end of file,
then store the position in the capture named "max".
--]===]
---@type lpeg_t
local chunk_stop =
    white_p^0
  * P("\n")^-1
  * named_pos("max", 1)
  -- no capture
  -- the current position becomes the next chunk min

---@type lpeg_t
local one_line_chunk_stop =
  ( 1 - P("\n") )^0 -- anything but a newline
  * chunk_stop

---@type lpeg_t
local special_begin =
  ( white_p^1 + -B("-") ) -- 1+ spaces or negative lookbehind: no "-" behind
  * P("---") * -P("-")
  * white_p^0

---@type lpeg_t
local capture_comment = (
      get_spaced_p("@")
    * named_pos("content_min")
    * black_p^0 * ( white_p^1 * black_p^1 )^0
    * named_pos("content_max", 1)
    * white_p^0
  )
  + Cmt(
    black_p,
    function (s, i)
      error("Missing @ for a comment at line "
        .. get_line_number(s, i - 1)
        ..": ".. s:sub(i - 1, i + 50))
    end
  )
  + (
      named_pos("content_min")
    * named_pos("content_max", 1)
    * white_p^0
  )

---Sub grammar for lua types
---@type lpeg_t
local lua_type = P({
  "type",
  type =
    ( V("table")
    + V("fun")
    + identifier_p
    )
    * (get_spaced_p("[") -- for an array: `string[]`
      * get_spaced_p("]")
    )^0,
  table =
    P("table")   -- table<foo,bar>
    * (get_spaced_p("<")
      * V("type")
      * spaced_comma_p
      * V("type")
      * get_spaced_p(">")
    )^-1,
  fun =
      P("fun")
    * get_spaced_p("(")
    * (
        V("fun_params") * spaced_comma_p * V("fun_vararg")
      + V("fun_params")
      + V("fun_vararg")^-1
    )
    * get_spaced_p(")")
    * V("fun_return")^-1,
  fun_vararg =
    P("..."),
  fun_param =
    variable_p * spaced_colon_p * V("type"),
  fun_params =
    V("fun_param") * (spaced_comma_p * V("fun_param"))^0,
  fun_return =
      spaced_colon_p
    * V("type")
    * (spaced_comma_p * V("type"))^0,
})

---@type lpeg_t
local named_types = Cg( Ct(-- collect all the captures in an array
    C(lua_type)
  * ( get_spaced_p("|") * C(lua_type) )^0
), "types")


---@type lpeg_t
local named_optional =
    white_p^0 * Cg(P("?") * Cc(true) , "optional") * white_p^0
  + Cg(Cc(false), "optional") * white_p^0

---Capture the pattern "---@<name>..."
---@param name string
---@return lpeg_t
local function at_match(name)
  return
      special_begin
    * P("@".. name)
    * -black_p
    * white_p^0
end

---comment
---@param Key string
---@return lpeg_t
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
    ( white_p^1 + -B("-") ) -- 1+ spaces or no "-" before
    * P("--[===[")
    * eol_p
    * chunk_start
    * named_pos("content_min")
    * Cg(
      Cmt(
        P(0),
        function (s, i)
          local p = white_p^0 * P("-")^0 * P("]===]")
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
  * black_p^0
  * ( white_p^1 * black_p^1 )^0
  * named_pos("content_max", 1)

--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=

---One line comment
---@type lpeg_t
local line_comment =
    chunk_init
  * ( white_p^1 + -B("-") )             -- 1+ spaces or no "-" before, the back test should never be reached
  * ( P("-")^4
    + P("--")
    * -P("-")                         -- >1 dashes, but not 3
    * -(P("[") * P("=")^0 * P("[")) -- no long comment
  )
  * white_p^0
  * Ct(
      chunk_start
    * content
    * chunk_stop
  )

---One line documentation
---@type lpeg_t
local line_doc =
    chunk_init
  * special_begin
  * -P("@")       -- negative lookahead: not an annotation
  * white_p^0
  * Ct(
      chunk_start
    * content
    * chunk_stop
  )

local short_literal =
    chunk_init
    * Ct(
      white_p^0
    * Cg(S([['"]]), TAG)
    * chunk_start
    * named_pos("content_min")
    * Cg(
      Cmt(
        Cb(TAG),
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
        t[TAG] = nil
        return t
      end

---@type lpeg_t
local long_literal
do
  -- next patterns are used for both long literals and long comments
  local open_p =
      P("[")
    * Cg( C(P("=")^0 ), TAG ) -- tagged capture of the equals
    * P("[")
    * eol_p                               -- optional EOL
    * named_pos("content_min")

  local close_p = Cg( Cmt(                 -- scan the string by hand
    Cb(TAG),
    function (s, i, equal)
      local p = white_p^0 * P("-")^0 * P("]") * equal * P("]")
      for j = i, #s - 1 - #equal do
        local result = p:match(s, j)
        if result then
          return result, j - 1, #equal -- 2 captured values: content_max and level
        end
      end
      error("Missing delimiter `]".. equal .."]`"
        .." after line ".. get_line_number(s, i - 1))
    end
  ), TAG)
  * Cg(
      Cb(TAG)
    / function (content_max, _)
        return content_max -- only the first captured value
      end,
    "content_max"
  )
  * Cg(
      Cb(TAG)
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
          t[TAG] = nil
          return t
        end
end

---@type lpeg_t
local long_comment

do
  local open_p =
      "["
    * Cg(P("=")^-2 + P("=")^4, TAG) -- tagged capture of the equals
    * "["
    * eol_p                               -- optional EOL
    * named_pos("content_min")

  local close_p = Cg(Cmt(                 -- scan the string by hand
    Cb(TAG),
    function (s, i, equal)
      local p = white_p^0 * P("-")^0 * P("]") * equal * P("]")
      for j = i, #s - 1 - #equal do
        local result = p:match(s, j)
        if result then
          return result, j - 1, #equal -- 2 captured values: content_max and level
        end
      end
      error("Missing delimiter `]".. equal .."]`"
        .." after line ".. get_line_number(s, i - 1))
    end
  ), TAG)
  * Cg(
      Cb(TAG)
    / function (content_max, _)
        return content_max -- only the first captured value
      end,
    "content_max"
  )
  * Cg(
      Cb(TAG)
    / function (_, level)
        return level -- only the second captured value
      end,
    "level"
  )

  ---@type lpeg_t @ what makes the difference with a long literal
  local prefix =
  (white_p^1 + -B("-")) -- 1+ spaces or no "-" before
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
          t[TAG] = nil
          return t
        end
end

---The full annotation pattern
---wraps `core`. May throw and error.
---@param key string
---@param core lpeg_t
---@return lpeg_t
local function get_annotation(key, core)
  if not core then
    print("\n**** DEBUG key", key)
    print(debug.traceback())
  end
  return
      chunk_init
    * at_match(key) * (
      Ct(
          chunk_start
        * core
        * chunk_stop
      )
      + error_annotation(key)
    )
end

local core_field = Cg(
    P("public") + "protected" + "private",
    "visibility"
  )
  * white_p^1
  * Cg(
    variable_p,
    "name"
  )
  * white_p^1
  * named_types
  * capture_comment

local core_class =
    Cg(identifier_p, "name")
  * ( spaced_colon_p * Cg(identifier_p, "parent") )^-1                 -- or nil
  * capture_comment

local core_type = named_types * capture_comment

local core_alias =
    Cg(identifier_p, "name")
  * white_p^1
  * named_types
  * capture_comment

local core_return =
    named_types
  * named_optional
  * capture_comment

local core_generic =
    Cg(variable_p, "type_1")          -- capture type_1
  * (spaced_colon_p
    * Cg(identifier_p, "parent_1")    -- and capture parent_1
  )^-1
  * (spaced_comma_p * (
      Cg(variable_p, "type_2")        -- capture type_2
    * (spaced_colon_p
      * Cg(identifier_p, "parent_2")  -- and capture parent_2
    )^-1
  ))^-1
  * capture_comment

local core_param =
    Cg(variable_p, "name")
  * named_optional
  * named_types
  * capture_comment

local core_vararg = core_type

local NAME_p = R("az", "09") * (R("az", "09") + S("_-."))^0

local core_module = Cg(NAME_p, "name") * capture_comment

local core_global =
    Cg(identifier_p, "name")
  * white_p^0
  * Cg(
    Ct(-- collect all the captures in an array
      ( C(lua_type)
        * ( get_spaced_p("|") * C(lua_type) )^0
      ) + P(0)
    ), "types")
  * capture_comment

  local core_author =
  Cg(
    black_p^0 * ( white_p^1 * black_p^1 )^0,
    "value"
  )

local core_see = core_author

local core_function =
    Cg(identifier_p, "name")  -- capture the name
  * capture_comment

local guess_function_name = P( {
  - B(black_p)
  * Ct(
      V("local function")
    + V("function ...")
    + V("local ... = function (")
    + V("... = function (")
  )
  * white_p^0
  * P("(")
  + ( P(1) - P("\n") ) * V(1), -- advance one character on the same line and try to match
  ["local function"] =
      P("local")
    * white_p^1
    * P("function")
    * white_p^1
    * Cg(
      variable_p,
      "name"
    )
    * Cg( Cc(true), "is_local"),
  ["function ..."] =
      P("function")
    * white_p^1
    * Cg(
      function_name_p,
      "name"
    )
    * Cg( Cc(false), "is_local"),
  ["local ... = function ("] =
      P("local")
    * white_p^1
    * Cg(
      variable_p,
      "name"
    )
    * get_spaced_p("=")
    * P("function")
    * Cg( Cc(true), "is_local"),
  ["... = function ("] =
    Cg(
      function_name_p,
      "name"
    )
    * get_spaced_p("=")
    * P("function")
    * Cg( Cc(false), "is_local"),
} )

local paragraph_break =
    chunk_init
  * Ct(                     -- 1) a table of named captures
    ( white_p^0 * P("\n") )^1
    * chunk_start
    * chunk_stop
  )

---@class lpeg_autodoc_t
---@field public line_comment     lpeg_t
---@field public line_doc         lpeg_t
---@field public short_literal    lpeg_t
---@field public long_literal     lpeg_t
---@field public long_comment     lpeg_t
---@field public long_doc         lpeg_t
---@field public get_annotation   fun(Key: string, core: lpeg_t): lpeg_t
---@field public core_field       lpeg_t
---@field public core_class       lpeg_t
---@field public core_type        lpeg_t
---@field public core_alias       lpeg_t
---@field public core_return      lpeg_t
---@field public core_generic     lpeg_t
---@field public core_param       lpeg_t
---@field public core_vararg      lpeg_t
---@field public core_module      lpeg_t
---@field public core_global      lpeg_t
---@field public core_author      lpeg_t
---@field public core_see         lpeg_t
---@field public core_function    lpeg_t
---@field public guess_function_name  lpeg_t
---@field public paragraph_break  lpeg_t
--
---@field public named_pos    fun(str: string, shift: number): lpeg_t
---@field public chunk_init   lpeg_t
---@field public chunk_start  lpeg_t
---@field public chunk_stop   lpeg_t
---@field public one_line_chunk_stop lpeg_t
---@field public special_begin lpeg_t
---@field public capture_comment  lpeg_t
---@field public lua_type         lpeg_t
---@field public named_types      lpeg_t
---@field public named_optional   lpeg_t
---@field public content          lpeg_t
---@field public at_match         fun(name: string): lpeg_t
---@field public error_annotation fun(Key: string): lpeg_t

return {
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
  core_author     = core_author,
  core_see        = core_see,
  core_function   = core_function,
  guess_function_name = guess_function_name,
  paragraph_break = paragraph_break,

  named_pos       = named_pos,
  chunk_init      = chunk_init,
  chunk_start     = chunk_start,
  chunk_stop      = chunk_stop,
  one_line_chunk_stop = one_line_chunk_stop,
  special_begin   = special_begin,
  capture_comment = capture_comment,
  lua_type        = lua_type,
  named_types     = named_types,
  named_optional  = named_optional,
  at_match        = at_match,
  error_annotation = error_annotation,
  content         = content,
  consume_1_character = consume_1_character_p,
}
