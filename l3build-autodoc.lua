--[[

File l3build-devlib.lua Copyright (C) 2018-2020 The LaTeX Project

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

-- Documentation of module `AD.Parser`
---Automatic documentation of lua code
--[==[

This tool covers automatic creation of lua code documentation
base on inline comments.

# Overview

A `lua` source file is parsed to collect some kind of
inline comments: the *annotations*. These annotations are
processed to create input files suitable for a later
typesetting with `luatex`.

The inline comments used for annotations all start with
exactly 3 dashes, no more. They follow the
[emmylua annotations]{https://emmylua.github.io/annotation.html}
with some extensions.

This syntax was chosen because it is widely used and known to
standard IDE .

Standalone annotations are
```
---@type type annotation
---@alias for type alias
```

Class annotations are
```
---@class class declaration annotation
---@field field annotation
---@see references
```

Function and methods annotations are
```
---@generic generic annotation
---@param parameter type annotation
---@return function return type annotation
---@vararg variadic arguments annotation
---@see references
```
Extensions are
```
---@module Only one per file
---@global For global constants
---@function when the function name cannot be guessed easily by the parser
```

All of these extra annotations are not widely used
and may not be processed by IDE's.

# Parsing a source file

The first challenge is to collect the annotations.
For that we must make the difference between comments and
literal strings. We cut the source into chunks described by
a chunk info table. This is the `parser.prepare` method.

In the `parser.parse` method, we use the chunk info to extract
documentation info, then we save this info to some file as a
formatted text file.

# documentation

Annotations should appear continuously when concerning the same class or function.
They form a group of annotations describing how things are implemented.
Whereas many annotations can contain embedded comment after a final `@`,
we can also document the whole with embedded documentation.

The embedded documentation starts with a short description
which is just a comment starting with exactly 3 dashes
which does not follow any such comment.
All similar comments after this one are the long description.
The long description may also be a long comment just after a short description
and before an annotation of some pure code chunk.
Regular comments are ignored.
--]==]

---@module l3build-AD.Parser

-- Safeguard and shortcuts

local type    = type
local open    = io.open
local append  = table.insert
local concat  = table.concat
local remove  = table.remove
local char    = string.char

local lpeg        = require("lpeg")
local locale      = lpeg.locale()
local P           = lpeg.P
local R           = lpeg.R
local S           = lpeg.S
local C           = lpeg.C
local V           = lpeg.V
local B           = lpeg.B
local Cb          = lpeg.Cb
local Cc          = lpeg.Cc
local Cg          = lpeg.Cg
local Cmt         = lpeg.Cmt
local Cp          = lpeg.Cp
local Ct          = lpeg.Ct

-- Namespace

local AD = {}

-- Implementation

--[[ lpeg patterns
All forthcoming variables with suffix "_p" are
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

`Cb("chunk_min")` is the first index of the current chunk
whereas `Cb("chunk_max")` is after the last one.

--]]

---@class lpeg.Pattern @ convenient type

---@type lpeg.Pattern
local white_p = S(" \t")          -- exclude "\n", no unicode space neither.

---@type lpeg.Pattern
local black_p = P(1) - S(" \t\n") -- non space, non LF

---@type lpeg.Pattern
local eol_p   = (
    P("\n")   -- consume an eol
)^-1          -- 0 or 1 end of line

-- Named captures must exist before use.
---@type lpeg.Pattern
local init_chunk_p =
    Cg(Cp(), "chunk_min")
  * Cg(0,    "chunk_max")

---Prepare the match of a new chunk
---In order to further insert a code chunk info if necessary
---create it and save it as capture named "code_before".
---@type lpeg.Pattern
local chunk_begin_p =
  Cg(
      Cb("min")
    * Cb("max")
    / function (min, max)
        if min <= max then
          return AD.Code({ -- new code between min and max has been registered
            min = min,
            max = max,
          })
        end
      end,
    "code_before"
  )
  * Cg(
    Cb("max")
    / function (c)
        return c + 1
      end,
    "min"
  ) -- now we have somehow Cb("min") == Cb("max") + 1

---End of chunk pattern
--[===[
This pattern is used at the end of the current logical chunk.
--]===]
---@type lpeg.Pattern
local chunk_end_p =
    white_p^0
  * eol_p
  * Cg(
    Cp(),
    "min"
  ) -- the current position becomes the next chunk min

---@type lpeg.Pattern
local one_line_chunk_end_p =
  (1 - P("\n"))^0 -- anything but a newline
  * chunk_end_p

local module_name_p =
  (R("az", "09") + S("_-"))^1

local variable_p =
    ("_" + locale.alpha)      -- ascii letter, or "_"
  * ("_" + locale.alnum)^0    -- ascii letter, or "_" or digit

  -- for a class, type name
local identifier_p =
  variable_p * ("." * variable_p)^0

---Capture the current position under the given name with the given shifht
---@param s string
---@param d number
---@return lpeg.Pattern
local function named_pos_p(s, d)
  return  Cg(d
      and Cp() / function (i) return i - d end
      or  Cp(),
    s)
end

local code_p =
    1                           -- one character
  - P("--")                     -- negative lookahed: not a comment
  - S([['"]])                   -- not a short string literal
  - P("[") * P("=")^0 * P("[")  -- not a long string literal

local special_begin_p =
  (white_p^1 + -B("-")) -- 1+ spaces or negative lookbehind: no "-" behind
  * P("---") * -P("-")
  * white_p^0

---Pattern with horizontal spaces before and after
---@param del string|number|table|lpeg.Pattern
---@return lpeg.Pattern
local function get_spaced_p(del)
  return white_p^0 * del * white_p^0
end

---@type lpeg.Pattern
local colon_p = get_spaced_p(":")

---@type lpeg.Pattern
local comma_p = get_spaced_p(",")

---@type lpeg.Pattern
local capture_comment_p =
    get_spaced_p("@")
  * named_pos_p("comment_min")
  * black_p^0
  * ( white_p^1 * black_p^1 )^0
  * named_pos_p("comment_max", 1)
  * white_p^0
  * -black_p      -- no black character except "@" comment

---Sub grammar for lua types
---@type lpeg.Pattern
local lua_type_p = P({
  "type",
  type =
    (V("table")
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
      * comma_p
      * V("type")
      * get_spaced_p(">")
    )^-1,
  fun =
      P("fun")
    * get_spaced_p("(")
    * (
        V("fun_params") * comma_p * V("fun_vararg")
      + V("fun_params")
      + V("fun_vararg")^-1
    )
    * get_spaced_p(")")
    * V("fun_return")^-1,
  fun_vararg =
    P("...") * colon_p * V("type"),
  fun_param =
    variable_p * colon_p * V("type"),
  fun_params =
    V("fun_param") * (comma_p * V("fun_param"))^0,
  fun_return =
      colon_p
    * V("type")
    * (comma_p * V("type"))^0,
})

---@type lpeg.Pattern
local named_types_p = Cg(Ct(-- collect all the captures in an array
    C(lua_type_p)
  * (get_spaced_p("|") * C(lua_type_p))^0
), "types")

---@class AD.Object @ fake class
---@field public initialize fun(self: AD.Object, ...)
---@field public finalize   fun(self: AD.Object)

---Class making utility
---@generic T: AD.Object
---@param Super?  table
---@param data?   T
---@return T
local function make_class(Super, data)
  ---@type AD.Object
  data = data or {}
  data.ID = {}        -- unique id by class
  data.__index = data
  data.__Class = data -- more readable than __index
  local function __call(self, d, ...)  -- self is a constructor
    d = d or {}
    setmetatable(d, self)
    if d.initialize then
      d:initialize(...)
    end
    return d
  end
  if Super then
    data.__Super = Super
    setmetatable(data, {
      __index = Super,
      __call  = __call,
    })
  else
    setmetatable(data, {
      __call  = __call,
    })
  end
  if data.finalize then
    data:finalize()
  end
  return data
end

---Records info about code chunks.
---The source is splitted into contiguous code chunks.
---Each code chunk has a chunk range from `min` to
---`max` included.
---@class AD.Info: AD.Object @ abstract class
---@field public id           string
---@field public min          integer
---@field public max          integer
---@field public match        lpeg.Pattern
---@field public code_before  AD.Info
---@field public capture      lpeg.Pattern @ all capture are sent at "chunk_max" location

AD.Info = make_class({
  min       =  1, -- the first index
  max       =  0, -- min > max => void range
  -- Next fields are defined by subclassers, see finalize
  -- match     = nil
  -- capture   = nil,
})

---@class AD.At: AD.Info  @ For embedded annotations `---@foo ...`
---@field public description            AD.Description
---@field public content_min            integer
---@field public content_max            integer
---@field public complete               lpeg.Pattern  @ complete pattern, see `finalize`.
---@field public get_short_description  fun(self: AD.At, s: string): string @ redundant declaration
---@field public get_long_description   fun(self: AD.At, s: string): string @ redundant declaration

---@type AD.At
AD.At = make_class(AD.Info, {
  description = AD.Description(),
  content_min = 1, -- only valid when content_min > min
  content_max = 0,
  -- Next fields are defined by subclassers, see `finalize`
  -- complete = nil
})

---Finalize the reveiver.
---Create a `complete` pattern from the `capture` pattern
---when not already defined.
---Both patterns must span over space characters to
---the next newline character when possible.
function AD.At:finalize()
  if not self.complete then
    self.complete =
      AD.Description.capture^-1
    * self.capture
    / function (desc_or_at, at)
        if at then -- 2 captures
          at.description = desc_or_at
          return at
        end
        return desc_or_at -- only one capture
      end
  end
  AD.At.__Super.finalize(self)
end

---Get the short description
---@param s string
---@return string
function AD.At:get_short_description(s)
  return self.description:get_short_value(s)
end

---Get the long description
---@param s string
---@return string
function AD.At:get_long_description(s)
  return self.description:get_long_value(s)
end

---Capture the pattern "---@<name>..."
---@param name string
---@return lpeg.Pattern
local function at_match_p(name)
  return
      special_begin_p
    * P("@".. name)
    * -black_p
    * white_p^0
end

---@class AD.Source: AD.Info @ The main source info.
---@field public infos AD.Info[]

do
  local more_utf8_p = R("\x80\xBF")
  local consume_one_character_p = (
      R("\x00\x7F") - P("\n") -- ones ascii char but a newline
    + R("\xC2\xDF") * more_utf8_p
    + P("\xE0")     * R("\xA0\xBF") * more_utf8_p
    + P("\xED")     * R("\x80\x9F") * more_utf8_p
    + R("\xE1\xEF") * more_utf8_p   * more_utf8_p
    + P("\xF0")     * R("\x90\xBF") * more_utf8_p * more_utf8_p
    + P("\xF4")     * R("\x80\x8F") * more_utf8_p * more_utf8_p
    + R("\xF1\xF3") * more_utf8_p   * more_utf8_p * more_utf8_p
    + Cmt((1 - P("\n")),   -- and consume one erroneous UTF8 character
      function (s, i) print("UTF8 problem ".. s:sub(i-1, i-1)) end
    )
  )
  * white_p^0
  * eol_p

  -- We capture the current begin of line position with name "bol"
  ---@type lpeg.Pattern
  local loop_p =
    (
      AD.LineComment.capture
    + AD.LongComment.capture
    + AD.At.Module.complete
    + AD.At.Class.complete
    + AD.At.Function.complete
    + AD.At.Generic.complete
    + AD.At.Param.complete
    + AD.At.Vararg.complete
    + AD.At.Return.complete
    + AD.At.See.complete
    + AD.At.Global.complete
    + AD.At.Alias.complete
    + AD.LineDoc.capture
    + AD.LongDoc.capture
    + AD.At.Field.capture     -- OK standalone field are ignored
    + AD.At.Type.capture      -- OK type annotation are unused in documentation
    + AD.ShortLiteral.capture -- OK
    + AD.LongLiteral.capture  -- OK
    + consume_one_character_p
  )
  * AD.Break.capture
  * Cg(Cp(), "max")         -- advance "max" to the current position

  ---@type AD.Source
  AD.Source = make_class(AD.Info, {
    capture =
        init_chunk_p
      * Cg(Ct(loop_p^0), "infos")
      / function (t)
          return AD.Source(t)
        end
  })
end

-- One line inline comments

---@class AD.LineComment: AD.Info

---@type AD.LineComment
AD.LineComment = make_class(AD.Info, {
  capture =
    (white_p^1 + -B("-"))             -- 1+ spaces or no "-" before, the back test should never be reached
    * (P("-")^4
      + P("--")
      * -P("-")                         -- >1 dashes, but not 3
      * -(P("[") * P("=")^0 * P("[")) -- no long comment
    )
    * white_p^0
    * Ct(
        chunk_begin_p
      * black_p^0 * (white_p^1 * black_p^1)^0
      * named_pos_p("after", 1)
    )
    * white_p^0
    * chunk_end_p
    / function (t)
        return AD.LineComment(t)
      end,
})

-- --- blah blah blah
---@class AD.LineDoc: AD.Info

---@type AD.LineDoc
AD.LineDoc = make_class(AD.Info, {
  capture =
      special_begin_p
    * -P("@")       -- negative lookahead: not an annotation
    * Ct(
        chunk_begin_p
      * white_p^0
      * named_pos_p("content_min")
      * black_p^0
      * (white_p^1 * black_p^1)^0
      * named_pos_p("content_max", 1)
    ) / function (t)
          return AD.LineDoc(t)
        end
    * chunk_end_p,
})

---@class AD.ShortLiteral: AD.Info

do
  local tag_del = {}
  ---@type AD.ShortLiteral
  AD.ShortLiteral = make_class(AD.Info, {
    capture = Ct(
        white_p^0
      * Cg([['"]], tag_del)
      * named_pos_p("content_min")
      * chunk_begin_p
      * Cg(Cmt(
        Cb(tag_del),
        function (s, i, del)
          repeat
            local c = s:sub(i, i)
            if c == del then
              return i + 1, i - 1 -- capture also `content_max`
            elseif c == [[\]] then
              i = i + 2
            elseif c then
              i = i + 1
            else
              error("Missing closing delimiter ".. del)
            end
          until false
        end
      ), "content_max")
      * chunk_end_p
      * Cg(nil, tag_del)
    ) / function (t)
          return AD.ShortLiteral(t)
        end,
  })
end

---@class AD.LongLiteral: AD.Info
---@field public level integer

do
  local tag_equal = {}
  -- next patterns are used for both long literals and long comments
  local open_p =
      "["
    * Cg(P("=")^0, tag_equal) -- tagged capture of the equals
    * "["
    * eol_p                   -- optional EOL
    * named_pos_p("content_min")

  local close_p = Cg(Cmt(   -- scan the string by hand
    Cb(tag_equal),
    function (s, i, equal)
      local p = P("]") * equal * P("]")
      for j = i, #s - 1 - #equal do
        if p:match(s, j) then
          return j + #equal + 2, j - 1, #equal -- 2 captures for content_max and level
        end
      end
      error("Missing delimiter `]".. equal .."]`")
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
  * Cg(nil, tag_equal) -- clean this named capture

  ---@type AD.LongLiteral
  AD.LongLiteral = make_class(AD.Info, {
    level = 0,
    capture = Ct(
        open_p
      * chunk_begin_p
      * close_p
      * chunk_end_p
    ) / function (t)
          return AD.LongLiteral(t)
        end
  })
end

---@class AD.LongComment: AD.Info
---@field public level integer @ level 3 is for long doc

do
  -- next patterns are used for both long literals and long comments
  local tag_equal = {}
  local open_p =
      "["
    * Cg(P("=")^-2 + P("=")^4, tag_equal) -- tagged capture of the equals
    * "["
    * eol_p                               -- optional EOL
    * named_pos_p("content_min")

  local close_p = Cg(Cmt(               -- scan the string by hand
    Cb(tag_equal),
    function (s, i, equal)
      local p = P("]") * equal * P("]")
      for j = i, #s - 1 - #equal do
        if p:match(s, j) then
          return j + #equal + 2, j - 1, #equal -- 2 captured values: content_max and level
        end
      end
      error("Missing delimiter `]".. equal .."]`")
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
  * Cg(nil, tag_equal) -- clean this named capture

  ---@type lpeg.Pattern @ what makes the difference with a long literal
  local prefix =
  (white_p^1 + -B("-")) -- 1+ spaces or no "-" before
  * P("--")
---@type AD.LongComment
  AD.LongComment = make_class(AD.Info, {
    level = 0,
    capture = Ct(
        prefix
      * open_p
      * chunk_begin_p
      * close_p
      * chunk_end_p
    ) / function (t)
          return AD.LongComment(t)
        end
  })
end

---@class AD.LongDoc: AD.Info

---@type AD.LongDoc
AD.LongDoc = make_class(AD.Info, {
  level = 0,
  capture = Ct(
    (white_p^1 + -B("-")) -- 1+ spaces or no "-" before
    * P("--[===[")
    * eol_p
    * named_pos_p("content_min")
    * chunk_begin_p
    * Cg(Cmt(
      P(0),
      function (s, i)
        local p = white_p^0 * P("-")^0 * P("]===]")
        for j = i, #s - 1 - 3 do
          local result = p:match(s, j)
          if result then
            return result, j - 1 -- capture `content_max`
          end
        end
      end
    ), "content_max")
    * chunk_end_p
  ) / function (t)
        return AD.LongDoc(t)
      end
})

---@alias AD.AllDoc AD.LongDoc|AD.LineDoc

---@class AD.Description: AD.Info
---@field public short            AD.LineDoc
---@field public long             AD.AllDoc[]
---@field public ignores          AD.AllDoc[]
---@field public get_short_value  fun(self: AD.Description, s: string): string @ redundant declaration
---@field public get_long_value   fun(self: AD.Description, s: string): string @ redundant declaration

do
  local tag_desc = {} -- unique tag
  AD.Description = make_class(AD.Info, {
    short   = AD.LineDoc(),
    long    = {},
    ignores = {},
    capture = Cg(
        -- start with a line documentation
        AD.LineDoc.capture
      / function (short)
          return AD.Description({
            short = short
          })
        end,
      tag_desc
    )
    * (
        -- next documentation is part of the "long" documentation
        (AD.LineDoc.capture + AD.LongDoc.capture)
      * Cb(tag_desc)
      / function (doc, desc)
          append(desc.long, doc)
        end
      -- other comments are recorded as ignored
      + (AD.LineComment.capture + AD.LongComment.capture)
      * Cb(tag_desc)
      / function (comment, desc)
          append(desc.ignores, comment)
        end
    )^0
    * Cb(tag_desc) -- the unique resulting capture
    * Cg(nil, tag_desc)
  })
end

---Get the short description
---@param s string
---@return string
function AD.Description:get_short_value(s)
  return s:sub(self.short.content_min, self.short.content_min)
end

---Get the long description
---@param s string
---@return string
function AD.Description:get_long_value(s)
  local t = {}
  for _, d in ipairs(self.long) do
    append(t, s:sub(d.content_min, d.content_max))
  end
  return concat(t, "\n")
end

local error_annotation_p = Cmt(
    Cp()
  * one_line_chunk_end_p,
  function (s, to, from)
    error("Bad annotation ".. s:sub(from, to))
  end
)

---@class AD.At.Field: AD.At
---@field public visibility string | "public" | "protected" | "private"
---@field public name       string
---@field public types      string[]

---@type AD.At.Field
AD.At.Field = make_class(AD.At, {
  visibility = "public",
  name = "",
  types = { "UNKNOWN" },
  -- @field [public|protected|private] field_name FIELD_TYPE[|OTHER_TYPE] [@comment]
  match = at_match_p("field")
    * one_line_chunk_end_p,
  capture = at_match_p("field") * (
    Ct( chunk_begin_p
      * Cg(
        P("public") + "protected" + "private",
        "visibility"
      )
      * white_p^1
      * Cg(
        variable_p,
        "name"
      )
      * white_p^1
      * named_types_p
      * capture_comment_p
      * chunk_end_p
    ) / function (at)
          return AD.At.Field(at)
        end
    + error_annotation_p
  )
})

-- @see references
---@class AD.At.See: AD.At
---@field public references string  @ the references

---@type AD.At.See
AD.At.See = make_class(AD.At, {
  references = "",
  capture = at_match_p("see") * (
    Ct( named_pos_p("content_min", 1)
      * chunk_begin_p
      * black_p^0
      * ( white_p^1 * black_p^1 )^0
      * named_pos_p("content_max", 1)
      * chunk_end_p
    ) / function (at)
          return AD.At.See(at)
        end
    + error_annotation_p
  ),
})

-- @class MY_TYPE[:PARENT_TYPE] [@comment]
---@class AD.At.Class: AD.At
---@field public name         string        @ the name of the receiver
---@field public parent       string|nil    @ the parent class if any, for class
---@field public fields       AD.At.Field[] @ list of fields
---@field public see          AD.At.See     @ references

---@type AD.At.Class
AD.At.Class = make_class(AD.At, {
  name = "UNKNOWN",
  capture = at_match_p("class") * (
    Ct( chunk_begin_p
      * Cg(identifier_p, "name")
      * (colon_p * Cg(identifier_p, "parent"))^-1                 -- or nil
      * capture_comment_p
      * chunk_end_p
    ) / function (at)
          return AD.At.Class(at)
        end
    + error_annotation_p
  ),
  -- class needs a custom complete method
  complete =
    -- capture a description or create a void one)
    (AD.Description.capture
    + Cc(AD.Description()))
    -- captupe a raw class annotation:
    -- create an AD.At.Class instance
    -- capture it with the name "at"
    * Cg(AD.At.Class.capture, "at")
    / function (desc, at)
        at.description = desc
      end
    * (
        AD.At.Field.complete
      * Cb("at")
      / function (at_field, at)
          append(at.fields, at_field)
        end
      + AD.At.See.complete
      * Cb("at")
      / function (at_see, at)
          at.see = at_see
        end
      + (AD.LineComment.capture + AD.LongComment.capture)
      * Cb("at")
      / function (ignore, at)
          append(at.ignores, ignore)
        end
    )^0
    -- No capture was made so far
    -- capture the current position, record it
    -- and return an AD.At.Class instance as sole capture
    * Cp()
    * Cb("at")
    / function (next_min, at)
        at.next_min = next_min
        return at
      end
})

-- @type MY_TYPE[|OTHER_TYPE] [@comment]
---@class AD.At.Type: AD.At
---@field public types        string[]    @ List of types

---@type AD.At.Type
AD.At.Type = make_class(AD.At, {
  types   = { "UNKNOWN" },
  match   = at_match_p("type")
    * one_line_chunk_end_p,
  capture = at_match_p("type") * (
    Ct( chunk_begin_p
      * named_types_p
      * capture_comment_p
      * chunk_end_p
    ) / function (at)
          return AD.At.Type(at)
        end
    + error_annotation_p
  )
})

-- @alias NEW_NAME TYPE [@ comment]
---@class AD.At.Alias: AD.At
---@field public name     string    @ the name of the alias
---@field public types    string[]  @ the target types

---@type AD.At.Alias
AD.At.Alias = make_class(AD.At, {
  name    = "UNKNOWN",
  types   = { "UNKNOWN" },
  match   = at_match_p("alias")
    * one_line_chunk_end_p,
  capture = at_match_p("alias") * (
    Ct( chunk_begin_p
      * Cg(identifier_p, "name")  -- capture name
      * white_p^1
      * named_types_p
      * capture_comment_p
      * chunk_end_p
    ) / function (at)
          return AD.At.Alias(at)
        end
    + error_annotation_p
  ),
})

-- @return MY_TYPE[|OTHER_TYPE] [@comment]
---@class AD.At.Return: AD.At
---@field public types  string[]  @ List of types

---@type AD.At.Return
AD.At.Return = make_class(AD.At, {
  types = { "UNKNOWN" },
  match   = at_match_p("return")
  * one_line_chunk_end_p,
  capture = at_match_p("return") * (
    Ct( chunk_begin_p
      * named_types_p
      * capture_comment_p
      * chunk_end_p
    ) / function (at)
          return AD.At.Return(at)
        end
    + error_annotation_p
  )
})

-- @generic T1 [: PARENT_TYPE] [, T2 [: PARENT_TYPE]] [ @ comment ]
---@class AD.At.Generic: AD.At
---@field public type_1   string      @ First type of generic annotations
---@field public parent_1 string|nil  @ First type of generic annotations
---@field public type_2   string|nil  @ Second type of generic annotations
---@field public parent_2 string|nil  @ Second type of generic annotations

---@type AD.At.Generic
AD.At.Generic = make_class(AD.At, {
  type_1 = "UNKNOWN",
  match   = at_match_p("generic")
    * one_line_chunk_end_p,
  capture = at_match_p("generic") * (
    Ct( chunk_begin_p
      * Cg(variable_p, "type_1")            -- capture type_1
      * (colon_p
        * Cg(identifier_p, "parent_1")      -- and capture parent_1
      )^-1
      * (comma_p * (
          Cg(variable_p, "type_2")        -- capture type_2
        * (colon_p
          * Cg(identifier_p, "parent_2")  -- and capture parent_2
        )^-1
      ))^-1
      * capture_comment_p
      * chunk_end_p
    ) / function (at)
          return AD.At.Generic(at)
        end
    + error_annotation_p
  )
})

-- @param param_name MY_TYPE[|other_type] [@comment]
---@class AD.At.Param: AD.At
---@field public name     string      @ the name of the alias
---@field public types    string[]    @ List of types

---@type AD.At.Param
AD.At.Param = make_class(AD.At, {
  name    = "UNKNOWN",
  types   = { "UNKNOWN" },
  match   = at_match_p("param")
    * one_line_chunk_end_p,
  capture = at_match_p("param") * (
    Ct( chunk_begin_p
      * Cg(variable_p, "name")                -- capture name
      * white_p^0 * Cg(P("?")^-1, "optional") -- capture optional
      * white_p^1
      * named_types_p
      * capture_comment_p
      * chunk_end_p
    ) / function (at)
          return AD.At.Param(at)
        end
    + error_annotation_p
  )
})

-- @vararg TYPE[|OTHER_TYPE] [ @ comment ]
---@class AD.At.Vararg: AD.At
---@field public types    string[]    @ the types of the variadic arguments

---@type AD.At.Vararg
AD.At.Vararg = make_class(AD.At, {
  types = { "UNKNOWN" },
  match   = at_match_p("vararg")
    * one_line_chunk_end_p,
  capture = at_match_p("vararg") * (
    Ct( chunk_begin_p
      * named_types_p
      * capture_comment_p
      * chunk_end_p
    ) / function (at)
          return AD.At.Vararg(at)
        end
    + error_annotation_p
  )
})

-- @module name [@ comment]
---@class AD.At.Module: AD.At
---@field public name     string      @ name of the module

---@type AD.At.Module
AD.At.Module = make_class(AD.At, {
  name = "UNKNOWN",
  capture = at_match_p("module") * (
    Ct( chunk_begin_p
      * Cg(module_name_p, "name")
      * capture_comment_p
      * chunk_end_p
    ) / function (at)
          return AD.At.Module(at)
        end
    + error_annotation_p
  )
})

-- @global name [@ comment]
---@class AD.At.Global: AD.At
---@field public name     string      @ name of the global variable

---@type AD.At.Global
AD.At.Global = make_class(AD.At, {
  name = "UNKNOWN",
  capture_description_long_p = at_match_p("global") * (
    Ct( chunk_begin_p
      * Cg(identifier_p, "name")
      * capture_comment_p
      * chunk_end_p
    ) / function (at)
          return AD.At.Global(at)
        end
    + error_annotation_p
  )
})

---@class AD.Code: AD.Info

---@type AD.Code
AD.Code = make_class(AD.Info)

---@class AD.Break: AD.Info

---@type AD.Break
AD.Break = make_class(AD.Info, {
  capture = Ct(
    ( white_p^0 * P("\n") )^1
    * chunk_begin_p
    * chunk_end_p
  ) / function (t)
        return AD.Break(t)
      end
})

-- @function name [@ comment]
---@class AD.At.Function: AD.At
---@field public name string  @ name of the function

---@type AD.At.Function
AD.At.Function = make_class(AD.At, {
  name = "UNKNOWN",
  compute = at_match_p("function") * (
    Ct( chunk_begin_p
      * Cg(identifier_p, "name")    -- capture the name
      * capture_comment_p
      * chunk_end_p
    ) / function (at)
          return AD.At.Function(at)
        end
    + error_annotation_p
  )
})

--[[
List of main patterns

  short_literal_p
  long_literal_p
  AD.LineComment.pattern
  AD.LongComment.pattern
  AD.code_p
  capture_doc_p
  capture_at_field_p
  capture_at_see_p
  capture_at_class_p
  capture_class_p
  capture_at_type_p
  capture_at_param_p
  capture_at_return_p
  capture_at_generic_p
  capture_at_vararg_p
  capture_at_module_p
  capture_at_global_p
 
--]]

-- Range

---@class AD.Range                @ a range of indices
---@field public min      integer @ minimum of the range
---@field public next_min integer @ just next_min the maximum of the range

---@class AD.Scope: AD.Range          @ A scope is a range with inner scopes
---@field public depth integer        @ the depth of this scope
---@field private _scopes AD.Range[]  @ inner scopes


AD.Scope = make_class({
  depth = 0,
  _scopes = {},
  initialize = function (self, depth, min, max)
    self.depth  = depth or self.depth or 0
    self.min    = min   or self.min   or 1
    self.max    = max   or self.max or self.min - 1
  end
})

---Append an inner scope
---@param scope AD.Scope
function AD.Scope:append_scope(scope)
  append(self._scopes, scope)
end

---Scopes iterator
---@return AD.Scope?
-- TODO manage the "?" and star types with name *****
function AD.Scope:scopes()
  local i = 0
  return function ()
    i = i + 1
    return self._scopes[i]
  end
end

---Whether the receiver has inner scopes or not
---@return boolean @ true when no inner scopes, false otherwise
-- TODO manage the "?" and star types with name *****
function AD.Scope:is_empty()
  return #self._scopes == 0
end

---Get the deepest scope at the given location
---@param i integer
---@return AD.Scope? @ nil is returned when `i` is out of the scope range
function AD.Scope:get_scope_at(i)
  if self.min <= i and i <= self.max then
    for s in self:scopes() do
      local result = s:get_scope_at(i)
      if result then
        return result
      end
    end
    return self
  end
  return nil
end

---@class AD.Parser                   @ AD.Parser
---@field private path string         @ the path of the source file
---@field private contents string     @ the contents to recover documentation from
---@field private _pure_code string   @ the contents without comment nor literals
---@field private _top_scope AD.Scope @ top scope

AD.Parser = {}

---Initialize the parser with given string.
---Prepare and store the string.
---@param s string
function AD.Parser:init_with_string(s)
  -- normalize newline characters
  self.contents = s
    :gsub("\r\n", "\n")
    :gsub("\n\r", "\n")
    :gsub("\r", "\n")
end

---Initialize the parser with the file at the given path.
---Read the file at the given path,
---prepare and store its contents.
---@param path string
function AD.Parser:init_with_contents_of_file(path)
  -- read the file contents
  local fh = open(path, "r")
  local s = fh:read("a")
  fh:close()
  self:init_with_string(s)
end

function AD.Parser:parse()
end

-- Export symbols to the _ENV for testing purposes
if _ENV.during_unit_testing then
  _ENV.white_p                    = white_p
  _ENV.black_p                    = black_p
  _ENV.eol_p                      = eol_p
  _ENV.module_name_p              = module_name_p
  _ENV.variable_p                 = variable_p
  _ENV.identifier_p               = identifier_p
  _ENV.code_p                     = code_p
  _ENV.special_begin_p            = special_begin_p
  _ENV.get_spaced_p               = get_spaced_p
  _ENV.colon_p                    = colon_p
  _ENV.comma_p                    = comma_p
  _ENV.lua_type_p                 = lua_type_p
  _ENV.named_types_p              = named_types_p
end

return AD
