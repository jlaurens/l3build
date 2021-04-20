--[[

File l3b-autodoc.lua Copyright (C) 2018-2020 The LaTeX Project

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

-- Documentation of module `AD.Module`
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
---@module At most one per file
---@author
---@global For global constants
---@function When the function name cannot be guessed easily by the parser
```

All of these extra annotations are not widely used
and may not be processed by IDE's, at least they are harmless.

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

---@module l3b-autodoc

-- Safeguard and shortcuts

local open    = io.open
local append  = table.insert
local concat  = table.concat
local move    = table.move

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

-- Namespace

local AD = {}

local Object = require("l3b-object")

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
  P("\n") -- consume an eol
)^-1      -- 0 or 1 end of line

local variable_p =
    ("_" + locale.alpha)      -- ascii letter, or "_"
  * ("_" + locale.alnum)^0    -- ascii letter, or "_" or digit

-- for a class, type name
local identifier_p =
  variable_p * ("." * variable_p)^0

-- for a class, type name
local function_p =
  variable_p * (S(".:") * variable_p)^0

---Capture the current position under the given name with the given shifht
---@param str string
---@param shift number
---@return lpeg.Pattern
-- This is a one line doc for testing purposes
local function named_pos_p(str, shift)
  return  Cg(shift
      and Cp() / function (i) return i - shift end
      or  Cp(),
    str)
end

-- Named captures must exist before use.
-- Prefix any pattern with `chunk_init_p`
-- such that named captures are defined at the top level.
---@type lpeg.Pattern
local chunk_init_p =
    named_pos_p("min")
  * named_pos_p("max", 1)

---Prepare the match of a new chunk
---In order to further insert a code chunk info if necessary
---create it and save it as capture named "code_before".
---@type lpeg.Pattern
local chunk_start_p =
  Cg( Cb("min"), "min")

---End of chunk pattern
--[===[
This pattern is used at the end of the current logical chunk.
Advance the cursor to the end of line or end of file,
then store the position in the capture named "max".
--]===]
---@type lpeg.Pattern
local chunk_stop_p =
    white_p^0
  * P("\n")^-1
  * named_pos_p("max", 1)
  -- no capture
  -- the current position becomes the next chunk min

---@type lpeg.Pattern
local one_line_chunk_stop_p =
  ( 1 - P("\n") )^0 -- anything but a newline
  * chunk_stop_p

local special_begin_p =
  ( white_p^1 + -B("-") ) -- 1+ spaces or negative lookbehind: no "-" behind
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

---Get the line number for the given string
---Should cache intermediate results.
---Should be defined globally.
---@param str   string
---@param index integer
---@return lpeg.Pattern
local function get_line_number(str, index)
  local result = 1
  for j = 1, index do
    if str:sub(j, j) == "\n" then
      result = result + 1
    end
  end
  return result
end

---@type lpeg.Pattern
local capture_comment_p = (
      get_spaced_p("@")
    * named_pos_p("content_min")
    * black_p^0
    * ( white_p^1 * black_p^1 )^0
    * named_pos_p("content_max", 1)
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
      named_pos_p("content_min")
    * named_pos_p("content_max", 1)
    * white_p^0
  )

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
    P("..."),
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
local named_types_p = Cg( Ct(-- collect all the captures in an array
    C(lua_type_p)
  * ( get_spaced_p("|") * C(lua_type_p) )^0
), "types")


---@type lpeg.Pattern
local named_optional_p =
    white_p^0 * Cg(P("?") * Cc(true) , "optional") * white_p^0
  + Cg(Cc(false), "optional") * white_p^0

---Records info about code chunks.
---The source is splitted into contiguous code chunks.
---Each code chunk has a chunk range from `min` to
---`max` included.
---@class AD.Info: Object @ abstract class
---@field public id             string
---@field public min            integer
---@field public max            integer
---@field public get_core_p     fun(self: AD.Info): lpeg.Pattern
---@field public get_capture_p  fun(self: AD.Info): lpeg.Pattern
---@field public code_before    AD.Info
---@field public mask_contents  fun(self: AD.Info, t: string[])
---@field public is_instance_of fun(self: AD.Info, Class: AD.Info): boolean

AD.Info = Object:make_subclass({
  __TYPE = "AD.Info",
  min       =  1, -- the first index
  max       =  0, -- min > max => void range
  -- Next fields are defined by subclassers, see finalize
  -- get_core_p     = nil
  -- get_capture_p   = nil,
})

---The core part of the pattern
---Default implementation raises a error.
---Must be overriden by subclassers.
---@param self AD.Info
---@return lpeg.Pattern
function AD.Info:get_core_p()
  error("Missing AD.Info:get_core_p implementation for ".. self.TYPE)
end

---The full pattern
---The default implementation just forwards to the receiver's
---`get_core_p`
---@param self AD.Info
---@return lpeg.Pattern
function AD.Info:get_capture_p()
  return self:get_core_p()
end

---Mask the contents
---The default implementation does nothing
---@param t string[]
function AD.Info:mask_contents(t)
  return
end

---Mask the contents
---Replace some charactes with "*".
---@param t string[]
function AD.Info:do_mask_contents(t)
  local p = -S("-@ \t\n\"\'=[]") -- none of "-", "@"... 
  for i = self.min, self.max do
    if p:match(t[i]) then
      t[i] = "*"
    end
  end
  for _, info in ipairs(self.ignores) do
    info:mask_contents(t)
  end
end

---@class AD.Content: AD.Info
---@field public content_min  integer
---@field public content_max  integer
---@field public get_content  fun(self: AD.Content, s: string): string @ the substring of the argument corresponding to the content

---@type AD.Content
AD.Content = AD.Info:make_subclass({
  __TYPE = "AD.Content",
  content_min = 1, -- only valid when content_min > min
  content_max = 0,
  get_content = function (self, s)
    return s:sub(self.content_min, self.content_max)
  end,
  ---Mask the contents
  ---The default implementation does nothing
  ---@param t string[]
  mask_contents = function (self, t)
    self:do_mask_contents(t)
  end,
})

---The core pattern
---This pattern matches the specific part of
---inline annotations.
---It will be used by the default implementation
---of `capture`.
---The default implementation fires an error.
---@param self AD.Content
function AD.Content:get_core_p()
   return
      named_pos_p("content_min")
    * black_p^0
    * ( white_p^1 * black_p^1 )^0
    * named_pos_p("content_max", 1)
end

-- One line inline comments

---@class AD.LineComment: AD.Content

---@type AD.LineComment
AD.LineComment = AD.Content:make_subclass({
  __TYPE = "AD.LineComment",
  get_capture_p = function (self)
    return
        chunk_init_p
      * ( white_p^1 + -B("-") )             -- 1+ spaces or no "-" before, the back test should never be reached
      * ( P("-")^4
        + P("--")
        * -P("-")                         -- >1 dashes, but not 3
        * -(P("[") * P("=")^0 * P("[")) -- no long comment
      )
      * white_p^0
      * Ct(
          chunk_start_p
        * self:get_core_p()
        * chunk_stop_p
      ) / function (t)
          return AD.LineComment(t)
        end
    end,
})

-- --- blah blah blah
---@class AD.LineDoc: AD.Content

---@type AD.LineDoc
AD.LineDoc = AD.Content:make_subclass({
  __TYPE = "AD.LineDoc",
  get_capture_p = function (self)
    return
        chunk_init_p
      * special_begin_p
      * -P("@")       -- negative lookahead: not an annotation
      * white_p^0
      * Ct(
          chunk_start_p
        * self:get_core_p()
        * chunk_stop_p
      ) / function (t)
            return AD.LineDoc(t)
          end
    end,
})

---@class AD.ShortLiteral: AD.Content

do
  local tag_del = {}
  ---@type AD.ShortLiteral
  AD.ShortLiteral = AD.Content:make_subclass({
    __TYPE = "AD.ShortLiteral",
    get_capture_p = function (self)
      return
          chunk_init_p
        * Ct(
          white_p^0
        * Cg(S([['"]]), tag_del)
        * chunk_start_p
        * named_pos_p("content_min")
        * Cg(
          Cmt(
            Cb(tag_del),
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
        * chunk_stop_p
      ) / function (t)
            t[tag_del] = nil
            return AD.ShortLiteral(t)
          end
    end
  })
end

---@class AD.LongLiteral: AD.Content
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

  ---@type AD.LongLiteral
  AD.LongLiteral = AD.Content:make_subclass({
    __TYPE = "AD.LongLiteral",
    level = 0,
    get_capture_p = function (self)
      return
          chunk_init_p
        * Ct(
            open_p
          * chunk_start_p
          * close_p
          * chunk_stop_p
        ) / function (t)
              t[tag_equal] = nil
              return AD.LongLiteral(t)
            end
    end,
  })
end

---@class AD.LongComment: AD.Content
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

  local close_p = Cg(Cmt(                 -- scan the string by hand
    Cb(tag_equal),
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
  (white_p^1 + -B("-")) -- 1+ spaces or no "-" before
  * P("--")
---@type AD.LongComment
  AD.LongComment = AD.Content:make_subclass({
    __TYPE = "AD.LongComment",
    level = 0,
    get_capture_p = function (self)
      return
          chunk_init_p
        * prefix
        * Ct(
          open_p
        * chunk_start_p
        * close_p
        * chunk_stop_p
      ) / function (t)
            t[tag_equal] = nil
            return AD.LongComment(t)
          end
    end,
  })
end

---@class AD.LongDoc: AD.Content

---@type AD.LongDoc
AD.LongDoc = AD.Content:make_subclass({
  __TYPE = "AD.LongDoc",
  level = 0,
  get_capture_p = function (self)
    return
        chunk_init_p
      * Ct(
        ( white_p^1 + -B("-") ) -- 1+ spaces or no "-" before
        * P("--[===[")
        * eol_p
        * chunk_start_p
        * named_pos_p("content_min")
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
        * chunk_stop_p
      ) / function (t)
            return AD.LongDoc(t)
          end
  end,
})

---@alias AD.AllDoc AD.LongDoc|AD.LineDoc
---@alias AD.AllComment AD.LongComment|AD.LineComment

---@class AD.Description: AD.Info
---@field public short            AD.LineDoc
---@field public long             AD.AllDoc[]
---@field public ignores          AD.AllComment[]
---@field public get_short_value  fun(self: AD.Description, s: string): string @ redundant declaration
---@field public get_long_value   fun(self: AD.Description, s: string): string @ redundant declaration

do
  local tag_desc = {} -- unique tag
  AD.Description = AD.Info:make_subclass({
    TYPE    = "AD.Description",
    short   = AD.LineDoc(),
    __initialize = function (self)
      self.long     = self.long or {}
      self.ignores  = self.ignores or {}
    end,
    get_capture_p = function (self)
      return Cg(
          Cmt(
            -- Must start with a line documentation
            AD.LineDoc:get_capture_p(),
            function (_, i, short)
              local result = AD.Description({
                TYPE  = "AD.Description",
                short = short,
                min   = short.min,
                max   = short.max,
              })
              return i, result
            end
          ),
          tag_desc
        )
        * ( -- next documentation is part of the "long" documentation
          ( AD.LineDoc:get_capture_p() + AD.LongDoc:get_capture_p() )
          * Cb(tag_desc)
          / function (doc, desc)
              append(desc.long, doc)
              desc.max = doc.max
            end
          -- other comments are recorded as ignored
          + ( AD.LineComment:get_capture_p() + AD.LongComment:get_capture_p() )
          * Cb(tag_desc)
          / function (comment, desc)
              append(desc.ignores, comment)
              desc.max = comment.max
            end
        )^0
        * Cb(tag_desc) -- the unique resulting capture
        / function (desc)
            return desc
          end
    end,
    ---Mask the contents
    ---Forwards to `do_mask_contents`
    ---@param t string[]
    mask_contents = function (self, t)
      self:do_mask_contents(t)
    end,
  })
end

---Get the short description
---@param s string
---@return string
function AD.Description:get_short_value(s)
  return self.short:get_content(s)
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

---@class AD.At: AD.Content  @ For embedded annotations `---@foo ...`
---@field public description            AD.Description
---@field public is_annotation          boolean                             @ true
---@field public KEY                    string                              @ static  KEY, the "foo" in ---@foo
---@field public get_complete_p         fun(self: AD.At): lpeg.Pattern      @ complete pattern, see `finalize`.
---@field public get_short_description  fun(self: AD.At, s: string): string @ redundant declaration, for editors
---@field public get_long_description   fun(self: AD.At, s: string): string @ redundant declaration for editors
---@field public get_comment            fun(self: AD.Content, s: string): string @ the substring of the argument corresponding to the comment
---@field public ignores  AD.AllComment[]

local error_annotation_p = function (Key)
  return Cmt(
      Cp()
    * one_line_chunk_stop_p,
    function (s, to, from)
      -- print(debug.traceback())
      error("Bad ".. Key .." annotation"
        .." at line ".. get_line_number(s, from)
        .. ": ".. s:sub(from, to))
    end
  )
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

---@type AD.At
AD.At = AD.Content:make_subclass({
  TYPE          = "AD.At",
  KEY           = "UNKNOWN KEY", -- to be overriden
  is_annotation = true,
  content_min = 1, -- only valid when content_min > min
  content_max = 0,
  -- Next fields are defined by subclassers, see `finalize`
  -- complete = nil
  __initialize = function (self)
    self.ignores = self.ignores or {}
  end,
})

---Pattern to capture an annotation
---All annotations start with '---@<KEY>'.
---If this string is recognized, an object is created
---otherwise an error is thrown.
---This static method is eventually overriden by subclassers.
---The default implementation wraps the receiver's match
---pattern between management code.
---On success, this pattern returns one capture exactly
---which is an instance of itself.
---@param self AD.At @ self is a "subclass" of AD.At
---@return lpeg.Pattern
function AD.At:get_capture_p()
  return
        chunk_init_p
      * at_match_p(self.KEY) * (
      Ct(
          chunk_start_p
        * self:get_core_p() -- specific static pattern
        * chunk_stop_p
      )
      / function (at)
          return self(at)
        end
      + error_annotation_p(self.KEY)
    )
end

local capture_ignores_p = Ct(
  ( AD.LineComment:get_capture_p()
  + AD.LongComment:get_capture_p()
  )^0
)
---Pattern for a complete annotation
---A complete annotation is a normal annotation
---combined with the description that precedes it.
---The default pattern tries to match one `AD.Description`
---if any, and then it tries to match an annotation.
---@param self AD.At
---@return lpeg.Pattern
function AD.At:get_complete_p()
  return
    ( AD.Description:get_capture_p() + Cc(false) )
    * self:get_capture_p()
    * capture_ignores_p
    / function (desc, at, ignores)
        if desc then
          at.description = desc
        end
        move(ignores, 1, #ignores, #at.ignores + 1, at.ignores)
        return at
      end
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

---Get the comment associate to the annotation
---Default implementation forwards to the receiver's
---`get_content` method.
---@param self AD.At
---@param s string
---@return string
function AD.At:get_comment(s)
  return self:get_content(s)
end

---@class AD.At.Author: AD.At

---@type AD.At.Author
AD.At.Author = AD.At:make_subclass({
  TYPE        = "AD.At.Author",
  KEY         = "author",
})

---@class AD.At.Field: AD.At
---@field public visibility string | "public" | "protected" | "private"
---@field public name       string
---@field public types      string[]

---@type AD.At.Field
AD.At.Field = AD.At:make_subclass({
  TYPE        = "AD.At.Field",
  KEY         = "field",
  visibility  = "public",
  name        = "UNKNOWN NAME",
  __initialize  = function (self)
    self.types = self.types or {}
  end,
  -- @field [public|protected|private] field_name FIELD_TYPE[|OTHER_TYPE] [@comment]
  get_core_p = function (self)
    return Cg(
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
    end,
})

-- @see references
---@class AD.At.See: AD.At

---@type AD.At.See
AD.At.See = AD.At:make_subclass({
  TYPE  = "AD.At.See",
  KEY   = "see",
})

-- @class MY_TYPE[:PARENT_TYPE] [@comment]
---@class AD.At.Class: AD.At
---@field public name         string        @ the name of the receiver
---@field public parent       string|nil    @ the parent class if any, for class
---@field public fields       AD.At.Field[] @ list of fields
---@field public author       AD.At.Author
---@field public see          AD.At.See     @ references

do
  local tag_at = {} -- unique tag for a temporary capture

  ---@type AD.At.Class
  AD.At.Class = AD.At:make_subclass({
    TYPE  = "AD.At.Class",
    KEY   = "class",
    name  = "UNKNOWN CLASS NAME",
    __initialize = function (self)
      self.fields = self.fields  or {}
    end,
    get_core_p = function (_self)
      return 
          Cg(identifier_p, "name")
        * (colon_p * Cg(identifier_p, "parent"))^-1                 -- or nil
        * capture_comment_p
    end,
    -- class annotation needs a custom complete method
    get_complete_p = function (self)
      -- capture a description
      return Cg(
        Cmt( -- expand
          AD.At.Class.__Super.get_complete_p(self),
          function (_, i, at)
            return i, at
          end
        ),
        tag_at
      )
      * (   AD.At.Field:get_complete_p()
          * Cb(tag_at)
          / function (at_field, at)
            append(at.fields, at_field)
          end
        +   AD.At.Author:get_complete_p()
          * Cb(tag_at)
          / function (at_author, at)
              at.author = at_author
            end
        +   AD.At.See:get_complete_p()
          * Cb(tag_at)
          / function (at_see, at)
              at.see = at_see
            end
      )^0
      -- No capture was made so far
      -- capture the current position, record it
      -- and return the AD.At.Class instance as sole capture
      * Cp()
      * Cb(tag_at)
      / function (after, at)
          at.max = after - 1
          return at -- captured
        end
      -- the `tag_at` named temporary capture is no longer available
      -- because it was created locally
      -- see https://stackoverflow.com/questions/67019331
    end,
})
end

-- @type MY_TYPE[|OTHER_TYPE] [@comment]
---@class AD.At.Type: AD.At
---@field public types  string[]      @ List of types
---@field public is_global boolean    @ When global, name of the variable guessed from the following code
---@field public name   nil | string  @ When global, name of the variable guessed from the following code


---@type AD.At.Type
AD.At.Type = AD.At:make_subclass({
  TYPE  = "AD.At.Type",
  KEY   = "type",
  types = { "UNKNOWN TYPE NAME" },
  is_global = false,
  get_core_p = function (self)
    return
        named_types_p
      * capture_comment_p
  end,
})

-- @alias NEW_TYPE TYPE [@ comment]
---@class AD.At.Alias: AD.At
---@field public name   string    @ the name of the alias
---@field public types  string[]  @ the target types

---@type AD.At.Alias
AD.At.Alias = AD.At:make_subclass({
  TYPE  = "AD.At.Alias",
  KEY   = "alias",
  name  = "UNKNOWN ALIAS NAME",
  types = { "UNKNOWN TYPE NAME" },
  get_core_p = function (self)
    return
        Cg(identifier_p, "name")
      * white_p^1
      * named_types_p
      * capture_comment_p
  end,
})

-- @return MY_TYPE[|OTHER_TYPE] [?] [@comment]
---@class AD.At.Return: AD.At
---@field public types  string[]  @ List of types

---@type AD.At.Return
AD.At.Return = AD.At:make_subclass({
  TYPE  = "AD.At.Return",
  KEY   = "return",
  types = { "UNKNOWN TYPE NAME" },
  get_core_p = function (self)
    return
        named_types_p
      * named_optional_p
      * capture_comment_p
  end,
})

-- @generic T1 [: PARENT_TYPE] [, T2 [: PARENT_TYPE]] [ @ comment ]
---@class AD.At.Generic: AD.At
---@field public type_1   string      @ First type of generic annotations
---@field public parent_1 string|nil  @ First type of generic annotations
---@field public type_2   string|nil  @ Second type of generic annotations
---@field public parent_2 string|nil  @ Second type of generic annotations

---@type AD.At.Generic
AD.At.Generic = AD.At:make_subclass({
  TYPE    = "AD.At.Generic",
  KEY     = "generic",
  type_1  = "UNKNOWN TYPE NAME",
  get_core_p = function (self)
    return
        Cg(variable_p, "type_1")          -- capture type_1
      * (colon_p
        * Cg(identifier_p, "parent_1")    -- and capture parent_1
      )^-1
      * (comma_p * (
          Cg(variable_p, "type_2")        -- capture type_2
        * (colon_p
          * Cg(identifier_p, "parent_2")  -- and capture parent_2
        )^-1
      ))^-1
      * capture_comment_p
  end,
})

-- @param param_name MY_TYPE[|other_type] [@comment]
---@class AD.At.Param: AD.At
---@field public name     string      @ the name of the alias
---@field public optional boolean     @ whether this param is optional, defaults to false
---@field public types    string[]    @ List of types

---@type AD.At.Param
AD.At.Param = AD.At:make_subclass({
  TYPE      = "AD.At.Param",
  KEY       = "param",
  name      = "UNKNOWN PARAM NAME",
  optional  = false,
  types     = { "UNKNOWN TYPE NAME" },
  get_core_p = function ()
    return
        Cg(variable_p, "name")
      * named_optional_p
      * named_types_p
      * capture_comment_p
  end,
})

-- @vararg TYPE[|OTHER_TYPE] [ @ comment ]
---@class AD.At.Vararg: AD.At
---@field public types  string[]  @ the types of the variadic arguments

---@type AD.At.Vararg
AD.At.Vararg = AD.At:make_subclass({
  TYPE  = "AD.At.Vararg",
  KEY   = "vararg",
  types = { "UNKNOWN TYPE NAME" },
  get_core_p = function (self)
    return
        named_types_p
      * capture_comment_p
  end,
})

-- @module name [@ comment]
---@class AD.At.Module: AD.At
---@field public    name   string     @ name of the module
---@field public    author AD.At.Author
---@field public    see    AD.At.See  @ reference
---@field protected NAME_p string     @ pattern for module names

---@type AD.At.Module
AD.At.Module = AD.At:make_subclass({
  TYPE    = "AD.At.Module",
  KEY     = "module",
  name    = "UNKNOWN MODULE NAME",
  NAME_p  = R("az", "09") * (R("az", "09") + S("_-."))^0,
  get_core_p = function(self)
    return
      Cg(self.NAME_p, "name")
      * capture_comment_p
  end,
})

do
  local tag_at = {}
  function AD.At.Module:get_complete_p()
    return
      Cg(
        Cmt( -- necessary because the capture must be evaluated only once
          AD.At.Module.__Super.get_complete_p(self),
          function (_, i, at)
            return i, at -- return the capture
          end
        ),
        tag_at
      )
      * ( AD.At.Author:get_complete_p()
          * Cb(tag_at)
          / function (at_author, at)
              at.author = at_author
            end
        + AD.At.See:get_complete_p()
          * Cb(tag_at)
          / function (at_see, at)
              at.see = at_see
            end
      )^0
      * Cb(tag_at)
      * Cp() -- capture after
      / function (at, after)
          at.max = after - 1
          return at -- return the capture
        end
  end
end

-- @global name [TYPE [ | OTHER_TYPE]] [@ comment]
---@class AD.At.Global: AD.At
---@field public name string            @ name of the global variable
---@field public type nil | AD.At.Type  @ type annotation eventually

---@type AD.At.Global
AD.At.Global = AD.At:make_subclass({
  TYPE  = "AD.At.Global",
  KEY   = "global",
  name  = "UNKNOWN GLOBALE NAME",
  get_core_p = function (self)
    return
        Cg(identifier_p, "name")
      * white_p^0
      * Cg(
        Ct(-- collect all the captures in an array
          ( C(lua_type_p)
            * ( get_spaced_p("|") * C(lua_type_p) )^0
          ) + P(0)
        ), "types")
      * capture_comment_p
  end,
})
do
  local tag_at = {}
  function AD.At.Global:get_complete_p()
    -- capture a description
    return Cg(
      Cmt(
        AD.At.Global.__Super.get_complete_p(self),
        function (_, i, at)
          return i, at
        end
      ),
      tag_at
    )
    * (   AD.At.Type:get_complete_p()
        * Cb(tag_at)
        / function (at_type, at)
          at.type = at_type
        end
    )^0
    -- No capture was made so far
    -- capture the current position, record it
    -- and return the AD.At.Class instance as sole capture
    * Cp()
    * Cb(tag_at)
    / function (after, at)
        at.max = after - 1
        return at -- captured
      end
    -- the temporary group is no longer available ?
    -- see https://stackoverflow.com/questions/67019331
  end

end

-- @function name [@ comment]
---@class AD.At.Function: AD.At
---@field public name     string          @ name of the function
---@field public params   AD.At.Param[]   @ parameters of the function
---@field public vararg   AD.At.Vararg    @ variadic arguments
---@field public generic  AD.At.Generic   @ generic annotation
---@field public returns  AD.At.Return[]  @ parameters of the function
---@field public author   AD.At.Author
---@field public see      AD.At.See       @ reference
---@field public GUESS_p  lpeg.Pattern
do
  local tag_at = {} -- unique capture tag
  ---@type lpeg.Pattern
  local start_with_param_p =
      AD.At.Param:get_capture_p() -- when no ---@function was given
    / function (at_param)
        return AD.At.Function({
          min     = at_param.min,
          params  = {
            at_param
          }
        })
      end
  ---@type lpeg.Pattern
  local more_param_p =
      AD.At.Param:get_complete_p()
    * Cb(tag_at)
    / function (at_param, at)
        append(at.params, at_param)
        -- returning no capture for this very pattern
        -- does not affect captures already made outside
        -- either named or not
      end

  ---@type lpeg.Pattern
  local start_with_vararg_p =
    AD.At.Vararg:get_capture_p()
    / function (at_vararg)
        return AD.At.Function({
          min     = at_vararg.min,
          vararg  = at_vararg
        })
      end
  ---@type lpeg.Pattern
  local more_vararg_p =
      AD.At.Vararg:get_complete_p()
    * Cb(tag_at)
    / function (at_vararg, at)
        at.vararg = at_vararg
      end
  ---@type lpeg.Pattern
  local start_with_generic_p =
    AD.At.Generic:get_capture_p() -- when no ---@function was given
    / function (at_generic)
        return AD.At.Function({
          min     = at_generic.min,
          generic = at_generic,
        })
      end
  ---@type lpeg.Pattern
  local more_generic_p =
      AD.At.Generic:get_complete_p()
    * Cb(tag_at)
    / function (at_generic, at)
        at.generic = at_generic
      end
  ---@type lpeg.Pattern
  local start_with_return_p =
    AD.At.Return:get_capture_p() -- when no ---@function was given
    / function (at_return)
        return AD.At.Function({
          min     = at_return.min,
          returns = {
            at_return
          }
        })
      end
  ---@type lpeg.Pattern
  local more_return_p =
      AD.At.Return:get_complete_p()
    * Cb(tag_at)
    / function (at_return, at)
        append(at.returns, at_return)
      end
  ---@type lpeg.Pattern
  local more_ignore_p =
    ( AD.LineComment:get_capture_p() + AD.LongComment:get_capture_p() )
    * Cb(tag_at)
    / function (at_ignore, at)
        append(at.ignores, at_ignore)
      end
  ---@type lpeg.Pattern
  local author_p =
      AD.At.Author:get_complete_p()
    * Cb(tag_at)
    / function (at_author, at)
        at.author = at_author
      end
  ---@type lpeg.Pattern
  local see_p =
      AD.At.See:get_complete_p()
    * Cb(tag_at)
    / function (at_see, at)
        at.see = at_see
      end
  ---@type AD.At.Function
  AD.At.Function = AD.At:make_subclass({
    TYPE  = "AD.At.Function",
    KEY   = "function",
    name  = "UNKNOWN FUNCTION NAME",
    __initialize = function (self)
      self.params   = self.params  or {}
      self.returns  = self.returns or {}
    end,
    get_core_p = function (self)
      return
          Cg(identifier_p, "name")  -- capture the name
        * capture_comment_p
    end,
    get_complete_p = function (self)
      -- capture a description
      return
        -- capture a complete functions annotation:
        -- create an AD.At.Function instance
        -- capture it with the tag `tag_at`
        Cg(
          Cmt(
              ( AD.Description:get_capture_p() + Cc(false) )
            * ( self:get_capture_p()
              + start_with_param_p  -- when no ---@function is available
              + start_with_vararg_p
              + start_with_generic_p
              + start_with_return_p
            ),
            function (_, i, desc, at)
              if desc then
                at.description = desc
              end
              return i, at -- return the capture
            end
          )
          ,
          tag_at
        )
        -- now capture all the other attributes
        * (
            more_ignore_p
          + more_param_p
          + more_vararg_p
          + more_generic_p
          + more_return_p
          + see_p
          + author_p
        )^0
        * Cp() -- capture after
        * Cb(tag_at)
        / function (after, at)
            at.max = after - 1
            return at -- return the capture
          end
    end,
    -- pattern to guess the name of the documented function
    GUESS_p = P( {
      - B(black_p)
      * Ct(
          V("local function")
        + V("function ...")
        + V("local ... = function (")
        + V("... = function (")
      )
      * white_p^0
      * P("(")
      + ( P(1) - P("\n") ) * V(1), -- advance one character one the same line and try to match
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
          function_p,
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
            function_p,
            "name"
          )
          * get_spaced_p("=")
          * P("function")
          * Cg( Cc(false), "is_local"),
    })
  }
)
end


---@class AD.Code: AD.Info

---@type AD.Code
AD.Code = AD.Info:make_subclass({
  __TYPE = "AD.Code",
})

---@class AD.Break: AD.Info

---@type AD.Break
AD.Break = AD.Info:make_subclass({
  __TYPE = "AD.Break",
  get_capture_p = function (self)
    return
        chunk_init_p
      * Ct(                     -- 1) a table of named captures
        ( white_p^0 * P("\n") )^1
        * chunk_start_p
        * chunk_stop_p
      ) / function (t)
            return AD.Break(t)  -- 2) an instance with that table
          end
  end
})

---@class AD.Source: AD.Info @ The main source info.
---@field public infos AD.Info[]

do
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

  local consume_one_character_p = (
      utf8_p
    + Cmt( 1 - P("\n"),   -- and consume one byte for an erroneous UTF8 character
      function (s, i) print("UTF8 problem ".. s:sub(i-1, i-1)) end
    )
  )

  -- We capture the current begin of line position with name "bol"
  ---@type lpeg.Pattern
  local loop_p =
    ( AD.LineComment:get_capture_p()
    + AD.LongComment:get_capture_p()
    + AD.At.Module:get_complete_p()
    + AD.At.Class:get_complete_p()
    + AD.At.Function:get_complete_p()
    + AD.At.Generic:get_complete_p()
    + AD.At.Param:get_complete_p()
    + AD.At.Vararg:get_complete_p()
    + AD.At.Return:get_complete_p()
    + AD.At.Author:get_complete_p()
    + AD.At.See:get_complete_p()
    + AD.At.Global:get_complete_p()
    + AD.At.Type:get_complete_p()     -- type annotations can correspond to global variables
    + AD.At.Alias:get_complete_p()
    + AD.LineDoc:get_capture_p()
    + AD.LongDoc:get_capture_p()
    + AD.At.Field:get_capture_p()     -- standalone field are ignored
    + AD.ShortLiteral:get_capture_p()
    + AD.LongLiteral:get_capture_p()
    +   consume_one_character_p
      * white_p^0
      * eol_p
  )
  * AD.Break:get_capture_p()^0
  * named_pos_p("max")        -- advance "max" to the current position

  -- Export symbols to the _ENV for testing purposes
  if _ENV.during_unit_testing then
    _ENV.consume_one_character_p    = consume_one_character_p
    _ENV.loop_p                     = loop_p
  end
  ---@type AD.Source
  AD.Source = AD.Info:make_subclass({
    __TYPE = "AD.Source",
    get_capture_p = function (self)
      return
          Ct( Cg( Ct(loop_p^0), "infos") )
        / function (t)
            return AD.Source(t)
          end
      end
  })
end

-- Range

---@class AD.Range                @ a range of indices
---@field public min      integer @ minimum of the range
---@field public next_min integer @ just next_min the maximum of the range

---@class AD.Scope: AD.Range          @ A scope is a range with inner scopes
---@field public depth integer        @ the depth of this scope
---@field private _scopes AD.Range[]  @ inner scopes

AD.Scope = Object:make_subclass({
  __TYPE = "AD.Scope",
  depth = 0,
  _scopes = {},
  __initialize = function (self, depth, min, max)
    self.depth  = depth or self.depth or 0
    self.min    = min   or self.min   or 1
    self.max    = max   or self.max   or self.min - 1
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

-- High level objects.
-- Hides implementation details

---@class AD.AtProxy
---@field public    name     string
---@field public    source   string
---@field public    comment  string
---@field public    short_description     string
---@field public    long_description      string
---@field public    as_latex              string
---@field public    as_latex_environment  string
---@field private   _at AD.At @ "@" annotation info
---@field protected _module AD.Module

AD.AtProxy = Object:make_subclass({
  __TYPE = "AD.AtProxy",
  LATEX_ENVIRONMENT = "unknown",
  __initialize = function (self, module, at)
    self._module = module
    self._at = at
  end,
  __computed_index = function (self, k)
    if k == "source" then
      return self._module.__contents
    end
    if k == "name" then
      return self._at[k]
    end
    if k == "comment" then
      local result = self._at:get_content(self.source)
      return #result > 0 and result or nil
    end
    if k == "short_description" then
      local desc = self._at.description
      if desc then
        return self._at:get_short_description(self.source)
      end
    end
    if k == "long_description" then
      local desc = self._at.description
      if desc then
        return self._at:get_long_description(self.source)
      end
    end
    if k == "types" then
      return self._at[k] and concat(self._at[k], "|")
    end
    if k == "as_latex_environment" then
      local content = self.as_latex
      return content and #content > 1 and
        ([[\begin{<?>}
]]):gsub("<%?>", self.LATEX_ENVIRONMENT)
        .. content
        .. ([[\end{<?>}
]]):gsub("<%?>", self.LATEX_ENVIRONMENT) or ""
    end
    if k == "as_latex" then
      return
          self.latex_name
        .. self.latex_value
        .. self.latex_types
        .. self.latex_comment
        .. self.latex_short_description
        .. self.latex_long_description
    end
    if k == "latex_name" then
      local replacement = self.name
      return replacement and ([[
\Name{<?>}
]]):gsub("<%?>", replacement) or ""
      end
    if k == "latex_types" then
    local replacement = self.types
    return replacement and ([[
\Types{<?>}
]]):gsub("<%?>", replacement) or ""
    end
    if k == "latex_comment" then
      local replacement = self.comment
      return replacement and ([[
\Comment{<?>}
]]):gsub("<%?>", replacement) or ""
    end
    if k == "latex_short_description" then
      local replacement = self.short_description
      return replacement and ([[
\ShortDescription{<?>}
]]):gsub("<%?>", replacement) or ""
    end
    if k == "latex_long_description" then
      local replacement = self.long_description
      return replacement and ([[
\begin{LongDescription}
<?>
\end{LongDescription}
]]):gsub("<%?>", replacement) or ""
      end
      if k == "latex_value" then
        local replacement = self.value
        return replacement and ([[
\Value{<?>}
]]):gsub("<%?>", replacement) or ""
      end
  end,
})

---@class AD.Param: AD.AtProxy
---@field public  types string[]
---@field private _at   AD.At.Param

AD.Param = AD.AtProxy:make_subclass({
  __TYPE = "AD.Param",
  LATEX_ENVIRONMENT = "param",
  __AtClass = AD.At.Param,
})

---@class AD.Vararg: AD.AtProxy
---@field public  types string[]
---@field private _at   AD.At.Vararg

AD.Vararg = AD.AtProxy:make_subclass({
  __TYPE = "AD.Vararg",
  LATEX_ENVIRONMENT = "vararg",
  __AtClass = AD.At.Vararg,
  __computed_index = function (self, k)
    if k == "types" then
      return self._at[k] and concat(self._at[k], "|")
    end
    return AD.Param.__Super.__computed_index(self, k)
  end
})

---@class AD.Return: AD.AtProxy
---@field public  types string[]
---@field private _at   AD.At.Return

AD.Return = AD.AtProxy:make_subclass({
  __TYPE = "AD.Return",
  LATEX_ENVIRONMENT = "return",
  __AtClass = AD.At.Return,
  __computed_index = function (self, k)
    if k == "types" then
      return self._at[k] and concat(self._at[k], "|")
    end
    return AD.Param.__Super.__computed_index(self, k)
  end
})

---@class AD.See: AD.AtProxy

AD.See = AD.AtProxy:make_subclass({
  __TYPE = "AD.See",
  LATEX_ENVIRONMENT = "see",
  __AtClass = AD.At.See,
  -- next is not very clean but it works and is simple
  __computed_index = function (self, k)
    if k == "comment" then
      return nil
    end
    if k == "value" then
      return AD.See.__Super.__computed_index(self, "comment")
    end
    return AD.See.__Super.__computed_index(self, k)
  end,
})

---@class AD.Author: AD.AtProxy
AD.Author = AD.AtProxy:make_subclass({
  __TYPE = "AD.Author",
  LATEX_ENVIRONMENT = "author",
  __AtClass = AD.At.Author,
  -- next is not very clean but it works and is simple
  __computed_index = function (self, k)
    if k == "comment" then
      return nil
    end
    if k == "value" then
      return AD.Author.__Super.__computed_index(self, "comment")
    end
    return AD.Author.__Super.__computed_index(self, k)
  end,
})

---@class AD.Function: AD.AtProxy
---@field public  all_param_names fun(): string | nil
---@field public  get_param       fun(name: string): AD.Param | nil
---@field public  all_params      fun(): AD.Param | nil
---@field public  vararg          AD.Vararg
---@field public  all_return_indices  fun(): integer | nil
---@field public  get_return      fun(i: integer): AD.Return | nil
---@field public  all_returns     fun(): AD.Return | nil
---@field private _at AD.At.Function
---@field private __params table<string, AD.Param>
---@field private __returns table<string, AD.Return>

AD.Function = AD.AtProxy:make_subclass({
  __TYPE = "AD.Function",
  LATEX_ENVIRONMENT = "function",
  __AtClass = AD.At.Function,
  __initialize = function (self, ...)
    ---@type AD.Param[]
    self.__params = {}
    ---@type AD.Return[]
    self.__returns = {}
  end,
})

function AD.Function:__computed_index(k)
  if k == "all_param_names" then
    local i = 0
    return function ()
      i = i + 1
      local param = self._at.params[i]
      return param and param.name
    end
  end
  ---Parameter iterator
  ---@function AD.Function.all_params
  ---@return fun(): string
  if k == "all_params" then
    local iterator = self.all_param_names
    return function ()
      local name = iterator()
      return name and self:get_param(name)
    end
  end
  if k == "vararg" then
    local result = AD.Vararg({}, self._module, self._at.vararg)
    self.vararg = result
    return result
  end
  if k == "see" then
    local result = AD.See({}, self._module, self._at.see)
    self.vararg = result
    return result
  end
  if k == "author" then
    local result = AD.Author({}, self._module, self._at.author)
    self.vararg = result
    return result
  end
  ---Return indices iterator
  ---@function AD.Function.all_return_indices
  ---@return fun(): string
  if k == "all_return_indices" then
    local i = 0
    return function ()
      i = i + 1
      return i <= #self._at.returns and i
    end
  end
  ---Parameter iterator
  ---@function AD.Function.all_params
  ---@return fun(): string
  if k == "all_returns" then
    local iterator = self.all_return_indices
    return function ()
      local i = iterator()
      return i and self:get_return(i)
    end
  end
  if k == "as_latex" then
    return self.latex_name
    .. self.latex_comment
    .. self.latex_short_description
    .. self.latex_long_description
    .. self.latex_params
    .. self.vararg.as_latex_environment
    .. self.see.as_latex_environment
    .. self.author.as_latex_environment
  end
  if k == "latex_params" then
    local t = {}
    for param_name in self.all_param_names do
      local p_info = self:get_param(param_name)
      local as_latex = p_info.as_latex_environment
      if as_latex and #as_latex>0 then
        append(t, as_latex)
      end
    end
    if #t > 0 then
      return [[
\begin{params}
]]
        .. concat(t, "")
        .. [[
\end{params}
]]
    end
    return ""
  end
  if k == "latex_vararg" then
    return k
  end
  if k == "latex_see" then
    local replacement = self.see
    return replacement and ([[
\See{<?>}
    ]]):gsub("<?>", replacement) or ""
  end
  if k == "latex_author" then
    return k
  end
  return AD.Function.__Super.__computed_index(self, k)
end

---Get the paramater with the given name
---@param name string @ one of the srings listed by the receiver's `all_param_names` enumerator.
---@return AD.Param | nil @ `nil` when no parameter exists with the given name.
function AD.Function:get_param(name)
  local params = self.__params
  local result = params[name]
  if result then
    return result
  end
  for _, param in ipairs(self._at.params) do
    if param.name == name then
      result = AD.Param({}, self._module, param)
      params[name] = result
      return result
    end
  end
end

---Get the return with the given index
---@param i integer @ one of the indices returned by the receiver's `all_return_indices` enumerator
---@return AD.Return | nil @ `nil` when the indice is out of the authorized range.
function AD.Function:get_return(i)
  local returns = self.__returns
  local result = returns[i]
  if result then
    return result
  end
  local at = self._at.returns[i]
  if at then
    result = AD.Return({}, self._module, at)
    self.__returns[i] = result
  end
  return result
end

---@class AD.Field: AD.AtProxy
---@field public visibility string
---@field protected as_latex string

AD.Field = AD.AtProxy:make_subclass({
  __TYPE = "AD.Field",
  LATEX_ENVIRONMENT = "field",
  __AtClass = AD.At.Field,
  __computed_index = function (self, k)
    if k == "visibility" then
      return self._at[k]
    end
    return AD.Field.__Super.__computed_index(self, k)
  end
})

---@class AD.Method: AD.Function
---@field public base_name  string
---@field public class      AD.Class

AD.Method = AD.Function:make_subclass({
  __TYPE = "AD.Method",
  CLASS_BASE_p = Ct(
    Cg(
      C (
        ( variable_p * P(".") )^0
        * variable_p * P(":")
      + ( variable_p * P(".") )^1
      )
      / function (c)
        return c:sub(1, -2)
      end,
      "class"
    )
    * Cg(
      variable_p,
      "base"
    ) )
    * P(-1),
  __computed_index = function (self, k)
    if k == "base_name" then
      local m = self.CLASS_BASE_p:match(self.name)
      if m then
        self[k] = m.base
        return m.base
      end
    end
    if k == "class_name" then
      local m = self.CLASS_BASE_p:match(self.name)
      if m then
        self[k] = m.class
        return m.class
      end
    end
    if k == "class" then
      local c_info = self._module:get_class(self.class_name)
      if c_info then
        self[k] = c_info
        return c_info
      end
    end
    return AD.Method.__Super.__computed_index(self, k)
  end
})

---@class AD.Class: AD.AtProxy
---@field public    author    AD.Author
---@field public    see       AD.See
---@field protected _at       AD.At.Class
---@field public    all_field_names fun(): nil | string
---@field public    all_fields    fun(): nil | AD.Field
---@field public    get_field     fun(name: string): nil | AD.Field
---@field private   __fields  AD.Field[]
---@field public    all_method_names fun(): nil | string
---@field public    all_methods   fun(): nil | AD.Method
---@field public    get_method    fun(name: string): nil | AD.Method
---@field private   __methods AD.Method[]

AD.Class = AD.AtProxy:make_subclass({
  __TYPE = "AD.Class",
  LATEX_ENVIRONMENT = "class",
  __AtClass = AD.At.Class,
  __initialize = function (self, ...)
    ---@type AD.Field[]
    self.__fields = {}
    ---@type table<string, AD.Method>
    self.__methods = {}
  end,
  __computed_index = function (self, k)
    if k == "all_field_names" then
      local i = 0
      return function ()
        i = i + 1
        local f = self._at.fields[i]
        if f then
          return f.name
        end
      end
    end
    if k == "all_fields" then
      local iterator = self.all_field_names
      return function ()
        local name = iterator()
        return name and self:get_field(name)
      end
    end
    if k == "all_method_names" then
      local p = P(self.name)
        * P(".")
        * C(variable_p)
        * -black_p
      local iterator = self._module.all_fun_names
      return function ()
        repeat
          local function_name = iterator()
          if function_name then
            local result = p:match(function_name)
            if result then
              return result
            end
          end
        until not function_name
      end
    end
    if k == "all_methods" then
      local iterator = self.all_method_names
      return function ()
        local name = iterator()
        return name and self:get_method(name)
      end
    end
    if k == "author" then
      local at_k = self._at[k]
      if at_k then
        local result = AD.Author({}, self._module, at_k)
        self[k] = result
        return result
      end
    end
    if k == "see" then
      local at_k = self._at[k]
      if at_k then
        local result = AD.See({}, self._module, at_k)
        self[k] = result
        return result
      end
    end
    if k == "as_latex" then
      return self.latex_name
      .. self.latex_comment
      .. self.latex_short_description
      .. self.latex_long_description
      .. self.latex_fields
      .. self.see.as_latex_environment
      .. self.author.as_latex_environment
    end
    if k == "latex_fields" then
      local t = {}
      for field_name in self.all_field_names do
        local f_info = self:get_field(field_name)
        local as_latex = f_info.as_latex_environment
        if as_latex and #as_latex>0 then
          append(t, as_latex)
        end
      end
      if #t > 0 then
        return [[
\begin{fields}
]]
        .. concat(t, "")
        .. [[
\end{fields}
]]
      end
      return ""
    end
    return AD.Class.__Super.__computed_index(self, k)
  end,
})

---Get the paramater with the given name
---@param name string   @ one of the srings listed by the receiver's `all_field_names` enumerator.
---@return AD.Field | nil @ `nil` when no field exists with the given name.
function AD.Class:get_field(name)
  local fields = self.__fields
  local result = fields[name]
  if result then
    return result
  end
  for _, field in ipairs(self._at.fields) do
    if field.name == name then
      result = AD.Field({}, self._module, field)
      fields[name] = result
      return result
    end
  end
end

---Get the paramater with the given name
---@param name string   @ one of the srings listed by the receiver's `all_field_names` enumerator.
---@return AD.Method | nil @ `nil` is returned when no method exists with the given name.
function AD.Class:get_method(name)
  local methods = self.__methods
  local result = methods[name]
  if result then
    return result
  end
  local at = self._module:get_fun(self.name ..".".. name)
  if at then
    result = AD.Method({}, self._module, at)
    methods[name] = result
    return result
  end
end

---@class AD.Type: AD.AtProxy
---@field public types      string[]
---@field public is_global  boolean
---@field public GLOBAL_p   lpeg.Pattern

AD.Type = AD.AtProxy:make_subclass({
  __TYPE = "AD.Type",
  __AtClass = AD.At.Type,
  GLOBAL_p = white_p^0 * P("_G.") * C(identifier_p),
  __computed_index = function (self, k)
    if k == "types" then
      local at_k = self._at[k]
      return at_k and concat(at_k, "|")
    end
    return AD.Type.__Super.__computed_index(self, k)
  end,
})

---@class AD.Global: AD.AtProxy
---@field public    types string[]
---@field protected _type AD.Type
---@field private _at AD.At.Global | AD.At.Type

AD.Global = AD.AtProxy:make_subclass({
  __TYPE = "AD.Global",
  LATEX_ENVIRONMENT = "global",
  __AtClass = AD.At.Global,
  __computed_index = function (self, k)
    if k == "_type" then
      local result
      if self._at:is_instance_of(AD.At.Type) then
        result = AD.Type({}, self._module, self._at)
        self[k] = result
        return result
      else
        local at_type = self._at.type
        if at_type then
          result = AD.Type({}, self._module, at_type)
          self[k] = result
          return result
        end
      end
    end
    if k == "types" then
      local at_type = self._type
      if at_type then
        local result = at_type.types
        self[k] = result
        return result
      end
    end
    if k == "short_description"
    or k == "long_description"
    or k == "comment"
    then
      if self._at:is_instance_of(AD.At.Type) then
        local at_type = self._at
        if at_type then
          local result = at_type[k]
          if result then
            self[k] = result
            return result
          end
        end
      end
    end
    return AD.Global.__Super.__computed_index(self, k)
  end,
})

---@class AD.Module
---@field public  path            string      @ the path of the source file
---@field public  name            string      @ the name of the module as defined in the first module annotation
---@field public  all_funs       fun(): AD.Function | nil  @ function names iterator
---@field public  all_globals         fun(): AD.Global | nil    @ globals name iterator
---@field public  all_classe_names    fun(): string | nil @ class names iterator
---@field public  all_fun_names       fun(): string | nil @ function names iterator
---@field public  all_global_names    fun(): string | nil @ globals name iterator
---@field public  get_global          fun(name: string): AD.Global | nil @ globals name iterator
---@field public  get_class           fun(name: string): AD.Class | nil @ globals name iterator
---@field public  get_fun             fun(name: string): AD.Function | nil @ globals name iterator
---@field private __contents      string      @ the contents to recover documentation from
---@field private __get_instance  fun(name: string, Class: AD.AtProxy, store: table<string,AD.AtProxy>): AD.AtProxy
---@field private __all_infos     fun(): AD.Info | nil      @ info iterator
---@field private __infos         AD.Info[]     @ info repository
---@field private __globals       AD.Global[]   @ cache for globals
---@field private __classes       AD.Class[]    @ cache for classes
---@field private __functions     AD.Function[] @ cache for functions

AD.Module = Object:make_subclass({
  __TYPE = "AD.Module",
  LATEX_ENVIRONMENT = "module",
  name = "UNKOWN MODULE NAME",
  __initialize = function (self)
    ---@type table<string, AD.Global>
    self.__globals    = {}
    ---@type table<string, AD.Class>
    self.__classes    = {}
    ---@type table<string, AD.Function>
    self.__functions  = {}
    if self.contents then
      self:init_with_string(self.contents)
      self.contents = nil
    elseif self.file_path then
      self:init_with_contents_of_file(self.file_path)
    else
      error("One of `contents` or `file_path` must be provided")
    end
    self:parse()
  end,
  __computed_index = function (self, k)
    if k == "as_latex_environment" then
      local content = self.as_latex
      return content and #content > 1 and
        ([[\begin{<?>}
]]):gsub("<%?>", self.LATEX_ENVIRONMENT)
        .. content
        .. ([[\end{<?>}
]]):gsub("<%?>", self.LATEX_ENVIRONMENT) or ""
    end
    if k == "as_latex" then
      return
          self.latex_name
        .. self.latex_comment
        .. self.latex_short_description
        .. self.latex_long_description
        .. self.latex_globals
        .. self.latex_functions
        .. self.latex_classes
    end
  end
})

---Global names iterator
--[===[
@ Usage
```
for name in module.all_global_names do
    -- something with name
end
```
--]===]
---@function AD.Module.all_global_names
---@return AD.Global | nil
function AD.Module.__computed_table:all_global_names()
  local iterator = self.__all_infos
  return function ()
    repeat
      local at = iterator()
      if at:is_instance_of(AD.At.Global) then
        return at.name
      end
    until not at
  end
end

---Global instances iterator
--[===[
@ Usage
```
for global in module.all_globals do
  -- something with global
end
```
--]===]
---@function AD.Module.all_globals
---@return AD.Global | nil
function AD.Module.__computed_table:all_globals()
  local iterator = self.all_global_names
  return function ()
    local name = iterator()
    return name and self:get_global(name)
  end
end
---Class names iterator
--[===[
@ Usage
```
for name in module.all_class_names do
  -- something with name
end
```
--]===]
---@function AD.Module.all_class_names
---@return AD.Class | nil
function AD.Module.__computed_table:all_class_names()
  local iterator = self.__all_infos
  return function ()
    repeat
      local at = iterator()
      if at:is_instance_of(AD.At.Class) then
        return at.name
      end
    until not at
  end
end
---Class iterator
--[===[
@ Usage
```
for class in module.all_classes do
  -- something with class
end
```
--]===]
---@function AD.Module.all_classes
---@return AD.Class | nil
function AD.Module.__computed_table:all_classes()
  local iterator = self.all_class_names
  return function ()
    local name = iterator()
    return name and self:get_class(name)
  end
end
---Function names iterator
--[===[
@ Usage
```
for name in module.all_fun_names do
  -- something with name
end
```
--]===]
---@function AD.Module.all_fun_names
---@return AD.Class | nil
function AD.Module.__computed_table:all_fun_names()
  local iterator = self.__all_infos
  return function ()
    repeat
      local at = iterator()
      if at:is_instance_of(AD.At.Function) then
        print("DEBUG")
        if type(at.name) ~= "string" then
          print(debug.traceback())
          print("ERR@R", type(at.name), at.name, "FIALIED")
          error("FAILED")
        end
        return at.name
      end
    until not at
  end
end

---Function iterator
--[===[
@ Usage
```
for fun in module.all_funs do
  -- something with fun
end
```
--]===]
---@function AD.Module.all_funs
---@return AD.Class | nil
function AD.Module.__computed_table:all_funs()
  local iterator = self.all_fun_names
  return function ()
    local name = iterator()
    return name and self:get_fun(name)
  end
end

---Get the info annotation object for the given name and class.
---@generic T: Object
---@param name string
---@param Class T
---@param store table<string,T>
---@return nil | T
function AD.Module:__get_instance(name, Class, store)
  local result = store[name]
  if result then
    return result
  end
  for info in self.__all_infos do
    if  info:is_instance_of(Class.__AtClass)
    and info.name == name
    then
      result = Class(nil, self, info)
      store[name] = result
      return result
    end
  end
end

---Get the global info for the given name
---@param name string
---@return nil | AD.Global
function AD.Module:get_global(name)
  local result = self.__globals[name]
  if result then
    return result
  end
  for at in self.__all_infos do
    if  at:is_instance_of(AD.At.Global)
    or  at:is_instance_of(AD.At.Type) and at.is_global
    then
      if at.name == name then
        result = AD.Global(nil, self, at)
        self.__globals[name] = result
        return result
      end
    end
  end
end

---Get the class info for the given name
---@param name string
---@return nil | AD.Class
function AD.Module:get_class(name)
  return self:__get_instance(name, AD.Class, self.__classes)
end

---Get the function info for the given name
---@param name string
---@return nil | AD.Function
function AD.Module:get_fun(name)
  return self:__get_instance(name, AD.Function, self.__functions)
end

---@class AD.Module.iterator_options
---@field public map    fun(t: AD.Info): any      @ defaults to the identity map
---@field public ignore fun(t: AD.Info): boolean  @ defaults to always true

---Iterator over infos of the given class
---@generic T: AD.Info, Out: any
---@param Class T
---@param options AD.Module.iterator_options
---@return fun(): Out | nil
function AD.Module:iterator(Class, options)
  options = options or {}
  local iterator = self.__all_infos
  return function ()
    repeat
      local result = iterator()
      if result then
        if result:is_instance_of(Class) then
          if not options.ignore
          or not options.ignore(result)
          then
            return options.map and options.map(result)
              or result
          end
        end
      end
    until not result
  end
end

AD.Module.__computed_index = function (self, k)
  -- computed properties
  if k == "__all_infos" then
    local i = 0
    return function ()
      i = i + 1
      return self.__infos[i]
    end
  end
  if k == "name" then
    for info in self.__all_infos do
      if info:is_instance_of(AD.At.Module) then
        self.name = info.name
        return self.name
      end
    end
  end
  if k == "all_class_names" then
    return self:iterator(AD.At.Class, {
      map = function (info)
        return info.name
      end
    })
  end
  if k == "all_classes" then
    local iterator = self.all_class_names
    return function()
      local name = iterator()
      if name then
        return self:get_class(name)
      end
    end
  end
  if k == "all_fun_names" then
    return self:iterator(AD.At.Function, {
      map = function (info)
        return info.name
      end
    })
  end
  if k == "all_funs" then
    local iterator = self.all_fun_names
    return function()
      local name = iterator()
      if name then
        return self:get_fun(name)
      end
    end
  end
  if k == "all_global_names" then
    -- we create 2 iterators:
    -- 1) for ---@global
    -- 2) for ---@type + _G.foo = ...
    local g_iterator = self:iterator(AD.At.Global, {
      map = function (at)
        return at.name
      end,
    })
    local t_iterator = self:iterator(AD.At.Type, {
      map = function (at)
        return at.name
      end,
      ignore = function (at)
        return not at.is_global
      end,
    })
    -- we merge the two iterators above:
    return function ()
      return g_iterator() or t_iterator()
    end
  end
  if k == "all_globals" then
    local iterator = self.all_global_names
    return function()
      local name = iterator()
      if name then
        return self:get_global(name)
      end
    end
  end
  return AD.Module[k]
end

---Initialize the parser with given string.
---Prepare and store the string.
---@param s string
function AD.Module:init_with_string(s)
  -- normalize newline characters
  self.__contents = s
    :gsub("\r\n", "\n")
    :gsub("\n\r", "\n")
    :gsub("\r", "\n")
end

---Initialize the parser with the file at the given path.
---Read the file at the given path,
---prepare and store its contents.
---@param path string
function AD.Module:init_with_contents_of_file(path)
  -- read the file contents
  local fh = open(path, "r")
  local s = fh:read("a")
  fh:close()
  self:init_with_string(s)
end

do
  ---@param self AD.Module
  local function make_after_codes(self)
    for i = 2, #self.__infos do
      local min = self.__infos[i - 1].max + 1
      local max = self.__infos[i].min - 1
      if min <= max then
        self.__infos[i - 1].after_code = AD.Code({
          min = min,
          max = max,
        })
      end
    end
    -- what comes after the last info:
    local last = self.__infos[#self.__infos]
    if last.max < #self.__contents then
      last.after_code = AD.Code({
        min = last.max + 1,
        max = #self.__contents,
      })
    end
  end
  --[[
  ---Make the masked contents
  ---The masked contents is obtained replacing black characters
  ---in literals and comments with a "*"
  local function make_masked_contents(self)
    -- explode the receiver's `__contents` into a regular array of bytes
    local t = Ct( C(P(1))^0 ):match(self.__contents)
    for info in self.__all_infos do
      info:mask_contents(t)
    end
    self.masked_contents = concat(t, "")
  end
  ]]
  ---@param self AD.Module
  local function guess_function_names(self)
    local p = AD.At.Function.GUESS_p
    for info in self:iterator(AD.At.Function) do
      if info.name == AD.At.Function.name then
        local code = info.after_code
        if not code then
          error("Cannot guess function name of ".. self.__contents:sub(info.min, info.max))
        end
        local s = self.__contents:sub(code.min, code.max)
        local t = p:match(s)
        if not t then
          error("Cannot guess function name from ".. s)
        end
        info.name     = t.name
        info.is_local = t.is_local
      end
    end
  end

  ---@param self AD.Module
  local function make_is_method(self)
    local p = AD.Method.CLASS_BASE_p
    for f_name in self.all_fun_names do
      if type(f_name) ~= "string" then
        print("WTH")
        _G.pretty_print(f_name)
      end
      local m = p:match(f_name)
      if m then
        local at = self:get_fun(m.class)
        if at then
          at.is_method = true
        end
      end
    end
  end

  local function make_types_global(self)
    local p = AD.Type.GLOBAL_p
    for at in self:iterator(AD.At.Type) do
      local code = at.after_code
      if code then
        local s = self.__contents:sub(code.min, code.max)
        local name = p:match(s)
        if name then
          at.is_global = true
          at.name = name
          return false
        end
      end
      return true
    end
  end

  function AD.Module:parse()
    local p = AD.Source:get_capture_p()
    local m = p:match(self.__contents)
    self.__infos = m.infos
    make_after_codes(self)
    make_types_global(self)
    -- self:make_masked_contents()
    guess_function_names(self)
    make_is_method(self) -- after guess...
  end
end

-- Export symbols to the _ENV for testing purposes
if _ENV.during_unit_testing then
  _ENV.white_p                    = white_p
  _ENV.black_p                    = black_p
  _ENV.eol_p                      = eol_p
  _ENV.variable_p                 = variable_p
  _ENV.identifier_p               = identifier_p
  _ENV.function_p                 = function_p
  _ENV.special_begin_p            = special_begin_p
  _ENV.get_spaced_p               = get_spaced_p
  _ENV.colon_p                    = colon_p
  _ENV.comma_p                    = comma_p
  _ENV.lua_type_p                 = lua_type_p
  _ENV.named_types_p              = named_types_p
  _ENV.named_optional_p           = named_optional_p
  _ENV.named_pos_p                = named_pos_p
  _ENV.at_match_p                 = at_match_p
  _ENV.chunk_start_p              = chunk_start_p
  _ENV.chunk_stop_p               = chunk_stop_p
  _ENV.chunk_init_p               = chunk_init_p
  _ENV.capture_comment_p          = capture_comment_p
end

return AD
