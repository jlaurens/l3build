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

local Object = require("l3b-object")

local get_object_Super = get_object_Super

-- Module namespace

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

--]]

---Get the line number for the given string
---Should cache intermediate results.
---Should be defined globally.
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

local PTRN = require("l3b-autodoc_pattern")

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

AD.Info = Object:make_subclass("AD.Info", {
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
AD.Content = AD.Info:make_subclass("AD.Content", {
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
   return PTRN.content
end

-- One line inline comments

---@class AD.LineComment: AD.Content

---@type AD.LineComment
AD.LineComment = AD.Content:make_subclass("AD.LineComment", {
  get_capture_p = function (self)
    return
        PTRN.line_comment
      / function (t)
          return AD.LineComment(t)
        end
    end,
})

-- --- blah blah blah
---@class AD.LineDoc: AD.Content

---@type AD.LineDoc
AD.LineDoc = AD.Content:make_subclass("AD.LineDoc", {
  get_capture_p = function (self)
    return
        PTRN.line_doc
      / function (t)
          return AD.LineDoc(t)
        end
    end,
})

---@class AD.ShortLiteral: AD.Content

---@type AD.ShortLiteral
AD.ShortLiteral = AD.Content:make_subclass("AD.ShortLiteral", {
  get_capture_p = function (self)
    return
        PTRN.short_literal
      / function (t)
          return AD.ShortLiteral(t)
        end
  end
})

---@class AD.LongLiteral: AD.Content
---@field public level integer

---@type AD.LongLiteral
AD.LongLiteral = AD.Content:make_subclass("AD.LongLiteral", {
  level = 0,
  get_capture_p = function (self)
    return
        PTRN.long_literal
      / function (t)
          return AD.LongLiteral(t)
        end
  end,
})

---@class AD.LongComment: AD.Content
---@field public level integer @ level 3 is for long doc

---@type AD.LongComment
AD.LongComment = AD.Content:make_subclass("AD.LongComment", {
  level = 0,
  get_capture_p = function (self)
    return
        PTRN.long_comment
      / function (t)
          return AD.LongComment(t)
        end
  end,
})

---@class AD.LongDoc: AD.Content

---@type AD.LongDoc
AD.LongDoc = AD.Content:make_subclass("AD.LongDoc", {
  level = 0,
  get_capture_p = function (self)
    return
          PTRN.long_doc
        / function (t)
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
  AD.Description = AD.Info:make_subclass("AD.Description", {
    short = AD.LineDoc(),
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

---@type AD.At
AD.At = AD.Content:make_subclass("AD.At", {
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
      PTRN.get_annotation(self.KEY, self:get_core_p())
    / function (at)
        return self(at)
      end
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
AD.At.Author = AD.At:make_subclass("AD.At.Author", {
  KEY         = "author",
})

---@class AD.At.Field: AD.At
---@field public visibility string | "public" | "protected" | "private"
---@field public name       string
---@field public types      string[]

---@type AD.At.Field
AD.At.Field = AD.At:make_subclass("AD.At.Field", {
  KEY         = "field",
  visibility  = "public",
  name        = "UNKNOWN NAME",
  __initialize  = function (self)
    self.types = self.types or {}
  end,
  -- @field [public|protected|private] field_name FIELD_TYPE[|OTHER_TYPE] [@comment]
  get_core_p = function (self)
    return PTRN.core_field
  end,
})

-- @see references
---@class AD.At.See: AD.At

---@type AD.At.See
AD.At.See = AD.At:make_subclass("AD.At.See", {
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
  AD.At.Class = AD.At:make_subclass("AD.At.Class", {
    KEY   = "class",
    name  = "UNKNOWN CLASS NAME",
    __initialize = function (self)
      self.fields = self.fields  or {}
    end,
    get_core_p = function (_self)
      return PTRN.core_class
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
AD.At.Type = AD.At:make_subclass("AD.At.Type", {
  KEY   = "type",
  types = { "UNKNOWN TYPE NAME" },
  is_global = false,
  get_core_p = function (self)
    return PTRN.core_type
  end,
})

-- @alias NEW_TYPE TYPE [@ comment]
---@class AD.At.Alias: AD.At
---@field public name   string    @ the name of the alias
---@field public types  string[]  @ the target types

---@type AD.At.Alias
AD.At.Alias = AD.At:make_subclass("AD.At.Alias", {
  KEY   = "alias",
  name  = "UNKNOWN ALIAS NAME",
  types = { "UNKNOWN TYPE NAME" },
  get_core_p = function (self)
    return PTRN.core_alias
  end,
})

-- @return MY_TYPE[|OTHER_TYPE] [?] [@comment]
---@class AD.At.Return: AD.At
---@field public types  string[]  @ List of types

---@type AD.At.Return
AD.At.Return = AD.At:make_subclass("AD.At.Return", {
  KEY   = "return",
  types = { "UNKNOWN TYPE NAME" },
  get_core_p = function (self)
    return PTRN.core_return
  end,
})

-- @generic T1 [: PARENT_TYPE] [, T2 [: PARENT_TYPE]] [ @ comment ]
---@class AD.At.Generic: AD.At
---@field public type_1   string      @ First type of generic annotations
---@field public parent_1 string|nil  @ First type of generic annotations
---@field public type_2   string|nil  @ Second type of generic annotations
---@field public parent_2 string|nil  @ Second type of generic annotations

---@type AD.At.Generic
AD.At.Generic = AD.At:make_subclass("AD.At.Generic", {
  KEY     = "generic",
  type_1  = "UNKNOWN TYPE NAME",
  get_core_p = function (self)
    return PTRN.core_generic
  end,
})

-- @param param_name MY_TYPE[|other_type] [@comment]
---@class AD.At.Param: AD.At
---@field public name     string      @ the name of the alias
---@field public optional boolean     @ whether this param is optional, defaults to false
---@field public types    string[]    @ List of types

---@type AD.At.Param
AD.At.Param = AD.At:make_subclass("AD.At.Param", {
  KEY       = "param",
  name      = "UNKNOWN PARAM NAME",
  optional  = false,
  types     = { "UNKNOWN TYPE NAME" },
  get_core_p = function ()
    return PTRN.core_param
  end,
})

-- @vararg TYPE[|OTHER_TYPE] [ @ comment ]
---@class AD.At.Vararg: AD.At
---@field public types  string[]  @ the types of the variadic arguments

---@type AD.At.Vararg
AD.At.Vararg = AD.At:make_subclass("AD.At.Vararg", {
  KEY   = "vararg",
  types = { "UNKNOWN TYPE NAME" },
  get_core_p = function (self)
    return PTRN.core_vararg
  end,
})

-- @module name [@ comment]
---@class AD.At.Module: AD.At
---@field public    name   string     @ name of the module
---@field public    author AD.At.Author
---@field public    see    AD.At.See  @ reference

---@type AD.At.Module
AD.At.Module = AD.At:make_subclass("AD.At.Module", {
  KEY     = "module",
  name    = "UNKNOWN MODULE NAME",
  get_core_p = function(self)
    return PTRN.core_module
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
AD.At.Global = AD.At:make_subclass("AD.At.Global", {
  KEY   = "global",
  name  = "UNKNOWN GLOBALE NAME",
  get_core_p = function (self)
    return PTRN.core_global
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
  AD.At.Function = AD.At:make_subclass("AD.At.Function", {
    KEY   = "function",
    name  = "UNKNOWN FUNCTION NAME",
    __initialize = function (self)
      self.params   = self.params  or {}
      self.returns  = self.returns or {}
    end,
    get_core_p = function (self)
      return
          Cg(PTRN.identifier, "name")  -- capture the name
        * PTRN.capture_comment
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
    GUESS_p = PTRN.guess_function_name,
  }
)
end


---@class AD.Code: AD.Info

---@type AD.Code
AD.Code = AD.Info:make_subclass("AD.Code")

---@class AD.Break: AD.Info

---@type AD.Break
AD.Break = AD.Info:make_subclass("AD.Break", {
  get_capture_p = function (self)
    return
        PTRN.paragraph_break
      / function (t)
          return AD.Break(t)  -- 2) an instance with that table
        end
  end
})

---@class AD.Source: AD.Info @ The main source info.
---@field public infos AD.Info[]

do
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
    +   PTRN.consume_1_character
      * PTRN.white^0
      * PTRN.eol
  )
  * AD.Break:get_capture_p()^0
  * PTRN.named_pos("max")        -- advance "max" to the current position

  -- Export symbols to the _ENV for testing purposes
  if _ENV.during_unit_testing then
    _ENV.loop_p = loop_p
  end
  ---@type AD.Source
  AD.Source = AD.Info:make_subclass("AD.Source", {
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

AD.Scope = Object:make_subclass("AD.Scope", {
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

---@class AD.AtProxy: Object
---@field public    name     string
---@field public    source   string
---@field public    comment  string
---@field public    short_description     string
---@field public    long_description      string
---@field public    as_latex              string
---@field public    as_latex_environment  string
---@field private   _at AD.At @ "@" annotation info
---@field protected _module AD.Module

AD.AtProxy = Object:make_subclass("AD.AtProxy", {
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
  end,
})

---@class AD.Param: AD.AtProxy
---@field public  types string[]
---@field private _at   AD.At.Param

AD.Param = AD.AtProxy:make_subclass("AD.Param", {
  __AtClass = AD.At.Param,
})

---@class AD.Vararg: AD.AtProxy
---@field public  types string[]
---@field private _at   AD.At.Vararg

AD.Vararg = AD.AtProxy:make_subclass("AD.Vararg", {
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

AD.Return = AD.AtProxy:make_subclass("AD.Return", {
  __AtClass = AD.At.Return,
  __computed_index = function (self, k)
    if k == "types" then
      return self._at[k] and concat(self._at[k], "|")
    end
    return AD.Param.__Super.__computed_index(self, k)
  end
})

---@class AD.See: AD.AtProxy

AD.See = AD.AtProxy:make_subclass("AD.See", {
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
AD.Author = AD.AtProxy:make_subclass("AD.Author", {
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
---@field public  vararg          AD.Vararg
---@field private _at AD.At.Function
---@field private __params table<string, AD.Param>
---@field private __returns table<string, AD.Return>

AD.Function = AD.AtProxy:make_subclass("AD.Function", {
  __AtClass = AD.At.Function,
  __initialize = function (self, ...)
    ---@type AD.Param[]
    self.__params = {}
    ---@type AD.Return[]
    self.__returns = {}
  end,
  __computed_index = function (self, k)
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
    return AD.Function.__Super.__computed_index(self, k)
  end,
})

---Iterator of the parameter info names
---@function AD.Function.all_param_names
---@return fun(): string | nil
function AD.Function.__computed_table:all_param_names()
  local i = 0
  return function ()
    i = i + 1
    local param = self._at.params[i]
    return param and param.name
  end
end

---Get the paramater info with the given name
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

---Parameter info iterator
---@function AD.Function.all_params
---@return fun(): string | nil
function AD.Function.__computed_table:all_params()
  local iterator = self.all_param_names
  return function ()
    local name = iterator()
    return name and self:get_param(name)
  end
end

---Return info indices iterator
---@function AD.Function.all_return_indices
---@return fun(): integer | nil
function AD.Function.__computed_table:all_return_indices()
  local i = 0
  return function ()
    i = i + 1
    return i <= #self._at.returns and i or nil
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

---Return info iterator
---@function AD.Function.all_params
---@return fun(): AD.Return | nil
function AD.Function.__computed_table:all_returns()
  local iterator = self.all_return_indices
  return function ()
    local i = iterator()
    return i and self:get_return(i)
  end
end

---@class AD.Field: AD.AtProxy
---@field public visibility string

AD.Field = AD.AtProxy:make_subclass("AD.Field", {
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

AD.Method = AD.Function:make_subclass("AD.Method", {
  CLASS_BASE_p = Ct(
    Cg(
      C (
        ( PTRN.variable * P(".") )^0
        * PTRN.variable * P(":")
      + ( PTRN.variable * P(".") )^1
      )
      / function (c)
        return c:sub(1, -2)
      end,
      "class"
    )
    * Cg(
      PTRN.variable,
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

AD.Class = AD.AtProxy:make_subclass("AD.Class", {
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
        * C(PTRN.variable)
        * -PTRN.black
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

AD.Type = AD.AtProxy:make_subclass("AD.Type", {
  __AtClass = AD.At.Type,
  GLOBAL_p = PTRN.white^0 * P("_G.") * C(PTRN.identifier),
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

AD.Global = AD.AtProxy:make_subclass("AD.Global", {
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

---@class AD.Module: Object
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

AD.Module = Object:make_subclass("AD.Module", {
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

-- feed AD with more latex related stuff
loadfile(
  require("l3build").work_dir .."l3b/".. "l3b-autodoc+latex.lua",
  "t",
  setmetatable({
    AD = AD,
  }, {
    __index = _G
  })
)()

return AD
