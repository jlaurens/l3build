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
local Cf          = lpeg.Cf
local Cg          = lpeg.Cg
local Cmt         = lpeg.Cmt
local Cp          = lpeg.Cp
local Ct          = lpeg.Ct

-- Implementation

--[[ lpeg patterns
All forthcoming variables with suffix "_p" are
lpeg patterns or functions that return a lpeg pattern.
These patterns implement a subset of lua grammar
to recognize embedded documentation.
--]]

--[[ The embedded documentation grammar

--]]

--[[ lpeg patterns
All forthcoming variables with suffix "_p" are
lpeg patterns or functions that return a lpeg pattern.
These patterns implement a subset of lua grammar
to recognize embedded documentation.
--]]

---@class lpeg.pattern @ convenient type

---@type lpeg.pattern
local white_p = S(" \t")        -- exclude "\n", no unicode space neither.
---@type lpeg.pattern
local black_p = 1 - S(" \t\n")  -- non space, non LF

---@type lpeg.pattern
local eol_p = P("\n")^-1        -- 0 or 1 end of line

local white_and_eol_p = white_p^0 * eol_p


local module_name_p =
  ( R("az") + R("09") + S("_-") )^1 -- 

local variable_p =
    ( "_" + locale.alpha )      -- ascii letter, or "_"
  * ( "_" + locale.alnum )^0    -- ascii letter, or "_" or digit

  -- for a class, type name
local identifier_p =
  variable_p * ( "." * variable_p )^0

local capture_text_p  =         -- capture text between horizontal spaces
    white_p^0                   -- more spaces
  * C(black_p^0                 -- Capture the text from black to black
    * (
        white_p^1
      * black_p^1
    )^0
  )                             -- no newline
  * white_p^0                   -- more spaces

  ---id of source chunk for extra line break
---The other code chunk will end with exactly one line break
---except at the end
local BREAK         = "BREAK"
---id of source chunk for line code
local CODE          = "CODE"
---id of source chunk for short literals
local SHORT_LITERAL = "SHORT_LITERAL"
---id of source chunk for long literals
local LONG_LITERAL  = "LONG_LITERALOC"
---id of source chunk for embedded documentation
local DOC           = "DOC"
---id of source chunk for comment
local LINE_COMMENT  = "COMMENT"
---id of source chunk for long comments
local LONG_COMMENT  = "LONG_COMMENT"

-- Annotation id

local GLOBAL    = "global"
local MODULE    = "module"
local TYPE      = "type"
local ALIAS     = "alias"
local CLASS     = "class"
local FIELD     = "field"
local GENERIC   = "vararg"
local FUNCTION  = "function"
local PARAM     = "param"
local VARARG    = "vararg"
local RETURN    = "return"
local SEE       = "see"

local AD = {}

---@class AD.ShortLiteral
---@field public id string | "short literal"
---@field public min integer
---@field public max integer

---The return match is an instance of AD.ShortLiteral
local short_literal_p
do
  ---@param del string | '"' | "'"
  ---@return lpeg.pattern
  local function get_short_literal_p (del)
    return
        del
      * ( P([[\]]) * 1    -- escape sequences
        + ( 1 - P(del) )  -- no single quotes
      )^0
      * del
  end
  ---@type lpeg.pattern
  short_literal_p = Cmt(
      white_p^0
    * Cp()                      -- capture before
    * ( get_short_literal_p("'")
      + get_short_literal_p('"')
    )
    * Cp()                      -- capture after
    * white_and_eol_p,
    ---@return integer
    ---@return AD.ShortLiteral
    function (_s, i, before, after)
      return i, {
        id  = SHORT_LITERAL,
        min = before + 1,
        max = after - 2,
      }
    end
  )
end


---@class AD.LongLiteral
---@field public id string | "long literal"
---@field public min integer
---@field public max integer

---The return match is an instance of AD.LongLiteral
local long_literal_p
do
  -- next patterns are used for both long literals and long comments
  local open_p =
      "["
    * Cg(P("=")^0, "open")  -- named capture of the equals
    * "["
    * eol_p                 -- optional EOL
  local close_p =
      "]"
    * C(P("=")^0)           -- capture the closing equals
    * "]"
  local will_close_p = Cmt(
    close_p * Cb("open"),
    function (_s, _i, close_arg, open_arg)
      return close_arg == open_arg
    end
  )
  long_literal_p = Cmt(
      open_p
    * Cp()
    * (1 - will_close_p)^0
    * close_p,
  ---@return integer
  ---@return AD.LongLiteral
  function (s, i, min)
      return i, {
        id = LONG_LITERAL,
        min = min,
        max = i - 2,
      }
    end
  )
end

---@type lpeg.pattern
local capture_eol_p =
    Cp()           -- capture the current position
  * white_and_eol_p

---@class AD.Line_comment
---@field public id string | "line comment"
---@field public min integer
---@field public max integer

local line_comment_p = Cmt(
  ( white_p^1 + -B("-") )             -- 1+ spaces or no "-" before
  * ( P("--") * -P("-") + P("-")^4 )  -- >1 dashes, but not 3
  * white_p^0
  * Cp()                              -- position of the first black character if any
  * black_p^0 * ( white_p^1 * black_p^1 )^0
  * capture_eol_p,
  ---@return integer
  ---@return AD.Line_comment
  function (s, i, min, after)
    return i, {
      id  = LINE_COMMENT,
      min = min,
      max = after - 1,
    }
  end
)

---@class AD.Long_comment
---@field public id string | "long comment"
---@field public min integer
---@field public max integer

local long_comment_p = Cmt(
  ( white_p^1 + -B("-") ) -- 1+ spaces or no "-" before
  * P("--") * -P("-")     -- exactly 2 dashes
  * long_literal_p
  * white_and_eol_p,
  ---@return integer
  ---@return AD.Long_comment
  function (s, i, t)
    t.id = LONG_COMMENT
    return i, t
  end
)

local doc_begin_p =
  ( white_p^1 + -B("-") ) -- 1+ spaces or no "-" before
  * P("---") * -P("-")
  * white_p^0

local function capture_min_p(t)
  return
      doc_begin_p
    * "@".. t
    * white_p^1
    * Cp()  -- Capture the position of the first back character if any
end

local capture_comment_and_eol_p =
    white_p^0
  * (
    "@"
    * capture_text_p  -- capture the text
  )^-1
  * capture_eol_p

---Pattern with horizontal spaces before and after
---@param del string|number|table|lpeg.pattern
---@return lpeg.pattern
local function get_spaced_p(del)
  return white_p^0 * del * white_p^0
end

---@type lpeg.pattern
local colon_p = get_spaced_p(":")
---@type lpeg.pattern
local comma_p = get_spaced_p(",")

---@type lpeg.pattern
local capture_black_code_p = Cmt(
  ( white_p^1 + line_comment_p + long_comment_p )^0 -- two captures
  * -doc_begin_p
  * Cp()              -- capture the position of the first back character
  * black_p
  * ( -eol_p )^0 * eol_p,
  function (s, i, comment_1, comment_2, black_code_n)
    return i, black_code_n  -- keep only the last pattern
  end
)

---@type lpeg.pattern
local type_p = P({
  "table",
  "fun_param",
  "fun_params",
  "fun_vararg",
  "fun_return",
  "fun",
  "type",
  table = "table"   -- table<foo,bar>
    + ( get_spaced_p("<")
      * V("type")
      * comma_p
      * V("type")
      * get_spaced_p(">")
    )^-1,
  fun_param =
      variable_p
    * colon_p
    * V("type"),
  fun_params =
    V("fun_param") * (
        comma_p
      * V("fun_param")
    )^0,
  fun_vararg =
      "..."
    * colon_p
    * V("type"),
  fun_return =
      colon_p
    * V("type")
    * ( comma_p * V("type") )^0,
  fun =
    "fun"
    * get_spaced_p("(")
    * ( V("fun_vararg")^-1
      + V("fun_params") * (
        comma_p * V("fun_vararg")
      )^-1
    )
    * get_spaced_p(")")
    * V("fun_return")^-1,
  type =
      V("table")
    + V("fun")
    + ( identifier_p        -- eg `string`
      * ( get_spaced_p("[") -- for an array: `string[]`
        * get_spaced_p("]")
      )^-1                  -- eventually
    )
    + ( get_spaced_p("(")   -- `(fun():integer)
      * V("type")
      * get_spaced_p(")")
    ),
})

-- --- blah blah blah
---@class AD.Doc
---@field public id string | "doc"

local annotation_doc_p = Cmt(
    doc_begin_p
  * Cp()
  * black_p^0                 -- Capture the text from black to black
  * ( white_p^1 * black_p^1 )^0
  * capture_eol_p,
  function (s, i, min, eol_n)
    return i, {
      id = CODE,
      min = min,
      max = eol_n - 1,
    }
  end
)

---@type lpeg.pattern
local capture_types_p = Ct( -- collect all the captures in an array
    C(type_p)
  * ( get_spaced_p("|") * C(type_p) )^0
)

---@class AD.Field
---@field public id         string | "field"
---@field public visibility string | "public" | "protected" | "private"
---@field public name       string
---@field public types      string[]
---@field public comment    string
---@field public min        integer   @ first index of characters to hide in pure code
---@field public max        integer   @ last index of characters to hide in pure code

-- @field [public|protected|private] field_name FIELD_TYPE[|OTHER_TYPE] [@comment]
local annotation_field_p = Cmt(
    capture_min_p(FIELD)
  * C( P("public") + "protected" + "private" ) -- capture visibility
  * white_p^1
  * C(variable_p)                              -- capture name
  * white_p^1
  * capture_types_p
  * capture_comment_and_eol_p,
  ---@return integer
  ---@return AD.Field
  function (s, i, min, visibility, name, types, comment, eol_n)
    return i, {
      id = "field",
      min = min,
      visibility = visibility,
      name = name,
      types = types,
      comment = comment,
      max = eol_n - 1,
    }
  end
)

local capture_fields_p = Cmt(
  Ct(                               -- capture fields
    ( annotation_field_p
    + line_comment_p
    + long_comment_p
    )^0
  ),
  ---@return integer
  ---@return AD.Field[]
  function (s, i, t)
    local tt = {}
    for _, f in ipairs(t) do
      if f.id == FIELD then
        append(t, f)
      end
    end
    return i, tt
  end
)

-- @see references
---@class AD.See
---@field public id         string  @ id of the annotation, one of the constants above
---@field public references string  @ the references
---@field public min        integer @ first index of characters to hide in pure code
---@field public max        integer @ last index of characters to hide in pure code

local annotation_see_p = Cmt(
    capture_min_p(SEE)
  * capture_text_p              -- capture refs
  * capture_eol_p,
  function (s, i, min, refs, after)
    return i, {
      id          = SEE,
      min         = min,
      references  = refs,
      max         = after - 1,
    }
  end
)

-- @class MY_TYPE[:PARENT_TYPE] [@comment]
---@class AD.Class
---@field public id         string      @ id of the annotation, one of the constants above
---@field public name       string      @ the name of the receiver
---@field public parent     string      @ the parent class if any, for class
---@field public comment    string      @ associate comment
---@field public fields     AD.Field[]  @ List of field annotations
---@field public see        string      @ references
---@field public black_code integer     @ first index of black code after the documentation
---@field public min        integer     @ first index of characters to hide in pure code
---@field public max        integer     @ last index of characters to hide in pure code

local annotation_class_p = Cmt(
    capture_min_p(CLASS)
  * C(identifier_p)                   -- capture name
  * ( colon_p * C(identifier_p) )^-1  -- capture parent
  * capture_comment_and_eol_p
  * capture_fields_p
  * annotation_see_p^-1               -- capture see
  * capture_black_code_p^-1,
  ---@return integer
  ---@return AD.Class
  function (s, i, min, name, parent, comment, eol_n, fields, see, black_code_n)
    return i, {
      id            = CLASS,
      name          = name,
      parent        = parent,
      min           = min,
      comment       = comment,
      max           = eol_n - 1,
      fields        = fields,
      see           = see,
      black_code_n  = black_code_n,
    }
  end
)

-- @type MY_TYPE[|OTHER_TYPE] [@comment]
---@class AD.Type
---@field public id       string    @ id of the annotation, one of the constants above
---@field public types    string[]  @ List of types
---@field public comment  string    @ associated comment
---@field public min      integer   @ first index of characters to hide in pure code
---@field public max      integer   @ last index of characters to hide in pure code

local annotation_type_p = Cmt(
    capture_min_p(TYPE)   
  * capture_types_p
  * capture_comment_and_eol_p,
  ---@return integer
  ---@return AD.Type
  function (s, i, min, types, comment, eol_n)
    return i, {
      id      = TYPE,
      min     = min,
      types   = types,
      comment = comment,
      max     = eol_n - 1,
    }
  end
)

-- @alias NEW_NAME TYPE [@ comment]
---@class AD.Alias
---@field public id     string  @ id of the annotation, one of the constants above
---@field public name   string  @ the name of the alias
---@field public type   string  @ the target type
---@field public min    integer @ first index of characters to hide in pure code
---@field public max    integer @ last index of characters to hide in pure code

local alias_p = Cmt(
    capture_min_p(ALIAS)
  * C(identifier_p)               -- capture name
  * capture_comment_and_eol_p,
  ---@return integer
  ---@return AD.Alias
  function (s, i, min, name, comment, eol_n)
    return i, {
      id      = ALIAS,
      min     = min,
      name    = name,
      comment = comment,
      max     = eol_n - 1,
    }
  end
)

-- @param param_name MY_TYPE[|other_type] [@comment]
---@class AD.Param
---@field public id       string    @ id of the annotation, one of the constants above
---@field public name     string    @ the name of the alias
---@field public types    string[]  @ List of types
---@field public comment  string    @ associated comment
---@field public min      integer   @ first index of characters to hide in pure code
---@field public max      integer   @ last index of characters to hide in pure code

local annotation_param_p = Cmt(
    capture_min_p(PARAM)
  * C(variable_p)                 -- capture name
  * white_p^1
  * capture_types_p
  * capture_comment_and_eol_p,
  ---@return integer
  ---@return AD.Param
  function (s, i, min, name, types, comment, eol_n)
    return i, {
      id      = PARAM,
      min     = min,
      name    = name,
      types   = types,
      comment = comment,
      max     = eol_n - 1,
    }
  end
)

-- @return MY_TYPE[|OTHER_TYPE] [@comment]
---@class AD.Return
---@field public id       string    @ id of the annotation, one of the constants above
---@field public value    string    @ value of the annotation
---@field public comment  string    @ associated comment
---@field public types    string[]  @ List of types
---@field public min      integer   @ first index of characters to hide in pure code
---@field public max      integer   @ last index of characters to hide in pure code

local annotation_return_p = Cmt(
    capture_min_p(RETURN)
  * capture_types_p
  * capture_comment_and_eol_p,
  ---@return integer
  ---@return AD.Return
  function (s, i, min, types, comment, eol_n)
    return i, {
      id = RETURN,
      min = min,
      types = types,
      comment = comment,
      max = eol_n - 1,
    }
  end
)

-- @generic T1 [: PARENT_TYPE] [, T2 [: PARENT_TYPE]]
---@class AD.Generic
---@field public id       string  @ id of the annotation, one of the constants above
---@field public value    string  @ value of the annotation
---@field public type_1   string  @ First type of generic annotations
---@field public parent_1 string  @ First type of generic annotations
---@field public type_2   string  @ Second type of generic annotations
---@field public parent_2 string  @ Second type of generic annotations
---@field public min      integer @ first index of characters to hide in pure code
---@field public max      integer @ last index of characters to hide in pure code

local annotation_generic_p = Cmt(
    capture_min_p(GENERIC)
  * C(variable_p)                     -- capture type_1
  * ( colon_p * C(identifier_p) )^-1  -- capture parent_1
  * C(variable_p)                     -- capture type_2
  * ( colon_p * C(identifier_p) )^-1  -- capture parent_2
  * capture_eol_p,
  ---@return integer
  ---@return AD.Generic
  function (s, i, min, type_1, parent_1, type_2, parent_2, eol_n)
    return i, {
      id        = GENERIC,
      min       = min,
      type_1    = type_1,
      parent_1  = parent_1,
      type_2    = type_2,
      parent_2  = parent_2,
      max = eol_n - 1,
    }
  end
)

-- @vararg TYPE
---@class AD.Vararg
---@field public id   string  @ id of the annotation, one of the constants above
---@field public type string  @ the type of the variadic arguments
---@field public min  integer @ first index of characters to hide in pure code
---@field public max  integer @ last index of characters to hide in pure code

local annotation_vararg_p = Cmt(
    capture_min_p(VARARG)
  * C(identifier_p)
  * capture_eol_p,
  ---@return integer
  ---@return AD.Vararg
  function (s, i, min, type, eol_n)
    return i, {
      id = VARARG,
      min = min,
      type = type,
      max = eol_n - 1,
    }
  end
)

-- @module name [@ comment]
---@class AD.Module
---@field public id         string  @ id of the annotation, one of the constants above
---@field public name       string  @ name of the module
---@field public min  integer @ first index of characters to hide in pure code
---@field public max  integer @ last index of characters to hide in pure code

local annotation_module_p = Cmt(
    capture_min_p(MODULE)
  * C(module_name_p)
  * capture_comment_and_eol_p,
  function (s, i, min, name, comment, eol_n)
    return i, {
      id      = MODULE,
      min     = min,
      name    = name,
      comment = comment,
      max     = eol_n - 1,
    }
  end
)

-- @function name [@ comment]
---@class AD.Function
---@field public id   string  @ id of the annotation, one of the constants above
---@field public name string  @ name of the function
---@field public min  integer @ first index of characters to hide in pure code
---@field public max  integer @ last index of characters to hide in pure code

local annotation_function_p = Cmt(
    capture_min_p(FUNCTION)
  * C(identifier_p)         -- capture the name
  * capture_comment_and_eol_p,
  ---@return integer
  ---@return AD.Function
  function (s, i, min, name, comment, eol_n)
    return i, {
      id      = FUNCTION,
      min     = min,
      name    = name,
      comment = comment,
      max     = eol_n - 1,
    }
  end
)

-- @global name [@ comment]
---@class AD.Global
---@field public id   string  @ id of the annotation, one of the constants above
---@field public name string  @ name of the global variable
---@field public min  integer @ first index of characters to hide in pure code
---@field public max  integer @ last index of characters to hide in pure code

local annotation_global_p = Cmt(
  capture_min_p(GLOBAL)
* C(identifier_p)         -- capture the name
* capture_comment_and_eol_p,
---@return integer
---@return AD.Global
function (s, i, min, name, comment, eol_n)
  return i, {
    id      = GLOBAL,
    min     = min,
    name    = name,
    comment = comment,
    max     = eol_n - 1,
  }
  end
)

---@class AD.Code
---@field public id   string  @ id of the annotation, one of the constants above
---@field public min  integer @ first index of characters to hide in pure code
---@field public max  integer @ last index of characters to hide in pure code

local annotation_code_p = Cmt(
    white_p^0
  * ( (
      1
    - P("--")
    - S([['"]])
    - P("[") * P("=")^0 * P("[")
    - P("\n")
  ) )^0
  * capture_eol_p,
  ---@return integer
  ---@return AD.Code
  function (s, i, min, eol_n)
    return i, {
      id      = CODE,
      min     = min,
      max     = eol_n - 1,
    }
  end
)

---@class AD.Break
---@field public id   string  @ id of the annotation, one of the constants above

local annotation_break_p = Cmt(
    S(" \t\n")^0
  * P("\n"),
  ---@return integer
  ---@return AD.Break
  function (s, i)
    return i, {
      id = BREAK,
    }
  end
)

-- Link id's

---@class AD.Range              @ a range of indices
---@field public min    integer @ minimum of the range
---@field public after  integer @ just after the maximum of the range

---@class AD.Scope: AD.Range          @ A scope is a range with inner scopes
---@field public depth integer        @ the depth of this scope
---@field private _scopes AD.Range[]  @ inner scopes

AD.Scope = {}
AD.Scope.__index = AD.Scope

---Create a new scope instance.
---@param depth integer|nil @ defaults to `self.depth` or 0
---@param min   integer|nil @ defaults to `self.min` or 1
---@param after integer|nil @ defaults to `self.after` or 1
---@return AD.Scope
function AD.Scope:new(depth, min, after)
  return setmetatable({
    depth   = depth or self.depth or 0,
    min     = min   or self.min   or 1,
    max     = after or self.after or self.min or 1,
    _scopes = {}
  }, AD.Scope)
end

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
  if self.min <= i and i < self.after then
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

---Initialize the parser with the given path.
---Read the file at the given path,
---prepare and store its contents.
---@param path string
function AD.Parser:init(path)
  -- read the file contents
  local fh = open(path, "r")
  local s = fh:read("a")
  fh:close()
  -- normalize newline characters
  s = s
    :gsub("\r\n", "\n")
    :gsub("\n\r", "\n")
    :gsub("\r", "\n")
  self.contents = s
end

---Get the root.
---Lazy intializer.
---@return AD.Link
function AD.Parser:get_root()
  if self._root then
    return self._root
  end
  -- In order to properly find string literals,
  -- duplicate the source and remove quote escape sequences
  -- To keep the same length, we replace by exactly 2 characters
  -- because the source is not interpreted.
  local s = self.contents
    :gsub([[\\]], "XX")
  -- unescape escape quotes
    :gsub([[\']], "XX")
    :gsub([[\"]], "XX")
  -- unescape escape quotes
    :gsub([[\<]], "XX")   -- for table<??,??>
    :gsub([[\>]], "XX")
    :gsub([[\(]], "XX")  -- for fun(??)
    :gsub([[\)]], "XX")
end

---Return the contents, with string literals and comments replaced by "*" characters.
---Lazy initializer.
---The return string has exactly the same line length (and global length) as the original.
---The only difference is that literal strings and comment have been replaced
---by the character "*".
---it is easier to find blocks.
---@return string
function AD.Parser:get_pure_code()
  if self._pure_code then
    return self._pure_code
  end
  -- Remove all the literal content from the CODE
  -- turn the contents into a list of characters
  local t = Ct(C(1)^0):match(self.contents)
  -- Replace any character not in a CODE chunk by an "*"
  -- Keep the "\n" for display convenience
  self:foreach(function (link)
    if link.id ~= CODE then
      for i = link.min, link.after - 1 do
        if t[i] ~= "\n" then
          t[i] = "*"
        end
      end
    end
  end)
  self._pure_code = concat(t)
  return self._pure_code
end

---Get the top scope
---Lazy initializer.
---Once all the chunk info are found,
---it is easier to find blocks.
---@return AD.Scope
function AD.Parser:get_top_scope()
  if self._top_scope then
    return self._top_scope
  end
  local pure_code = self:get_pure_code()
  ---@type AD.Scope
  self._top_scope = AD.Scope:new(0, 1, #pure_code)
  -- Any string literal and comment is masked out in `pure_code`
  -- Now find the true top level scope. Scopes are delimited by
  -- * function ... end
  -- * do ... end
  -- * then ... elseif|else|end
  -- * repeat ... until
  -- We want to use the "%b()" lua pattern but we need
  -- delimiters that are not in the source.
  local left, right
  for i = 0, 31 do
    local c = char(i)
    if not pure_code:find(c, nil, true) then
      left = c
      for j = i + 1, 31 do
        c = char(j)
        if not pure_code:find(c, nil, true) then
          right = c
        end
      end
    end
  end
  assert(left and right, "Error: the source contains too many control characters")
  local scope_pattern = "%b".. left .. right
  local function to_word(s)
    return "%f[%w_]".. s .."%f[^%w_]"
  end
  local s = pure_code
    :gsub(to_word("function"),        "functio".. left)
    :gsub(to_word("do"),              "d"..       left)
    :gsub(to_word("then"),            "the"..     left)
    :gsub(to_word("elseif"),  right .."lseif")
    :gsub(to_word("else"),    right .."ls"..      left)
    :gsub(to_word("end"),     right .."nd")
    :gsub(to_word("until"),   right .."ntil")
  -- Then complete each scope starting from the top
  -- Feed a todo list
  ---@type AD.Scope[]
  local todo = {
    self._top_scope
  }
  local done = 0 -- index of the last item done in the todo list
  while done < #todo do
    done = done + 1
    ---@type AD.Scope
    local scope = todo[done]
    local init  = scope.min
    repeat
      local min, max = s:find(scope_pattern, init)
      if not min or min >= scope.after then
        break -- no more inner scope
      end
      ---@type AD.Scope
      local found = AD.Scope:new(
        scope.depth + 1,
        min + 1,
        max
      )
      scope:append_scope(found)
      append(todo, found)
      init = max + 1
    until false
  end
  --[[
  local function print_scope(scope)
    local prefix = ("  "):rep(scope.depth)
    if not scope:is_empty() then
      print(prefix .."{ ".. scope.min ..":...")
      for scp in scope:scopes() do
        print_scope(scp)
      end
      print(prefix .."} ...:".. scope.max)
    else
      print(prefix .. scope.min ..":".. scope.max)
    end
  end
  print_scope(self.top_scope)
  os.exit()
  --]]
  return self._top_scope
end

---Complete the chunk infos with the proper scope
---Associate the proper scope to each chunk.
function AD.Parser:resolve_scopes()
  ---@type AD.Scope
  local scope = self:get_top_scope()
  self:foreach(function (link)
    link.scope = scope:get_scope_at(link.min)
  end)
end

---Get the balanced pattern for the given patterns.
---See http://www.inf.puc-rio.br/~roberto/lpeg/#ex
---@param del string @ pair or delimiters
local function get_balanced_p(del)
  return P({
      del:sub(1, 1)
    * ((1 - S(del)) + V(1))^0
    * del:sub(2, 2)
  })
end

local type_table_p =
    "table"
  * white_p^0
  * get_balanced_p("<>")

---Parse inline documentation of a lua source file
---@param path string @ The path of the file to parse
---@return table @ A private structure
function AD.Parser:parse(path)
  self:init(path)
  self:resolve_scopes()
  self:simplify()
  self:foreach(function (link)
    print(
      link.id:sub(1,4),
      link.scope.depth,
      link.scope.min,
      link.min,
      link.max,
      link.scope.max
    )
  end)
  os.exit(421)
  self:resolve_annotations()
  self:gather()
  self:foreach(function (link)
    print(
      link.id:sub(1,4),
      link.annotation and link.annotation.id:sub(1,4),
      link.scope.depth,
      link.scope.min,
      link.min,
      link.max,
      link.scope.max
    )
  end)
  os.exit(0)
  self.item = {}
  local docs = {}
  local doc
end

---@class l3b_AD.t
---@field parse fun(p: string): table
AD.Parser:parse(arg[1])

