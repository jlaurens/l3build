#!/usr/bin/env texlua

--[[

File l3b-test/autodoc_db.lua Copyright (C) 2018-2020 The LaTeX Project

It may be distributed and/or modified under the conditions of the
LaTeX Project Public License (LPPL), either version 1.3c of this
license or (at your option) any later version.  The latest version
of this license is in the file

   http://www.latex-project.org/lppl.txt

This file is part of the "l3build development bundle" (The Work in LPPL)
which can be found at

   https://github.com/latex3/l3build

--]]

-- This file is required

local append = table.insert

---@type utlib_t
local utlib = require("l3b-utillib")
local deep_copy = utlib.deep_copy

local DB = {
  BASE = function ()
    return {}
  end,
  BASE_content  = function ()
    return {
      content_min = 1,
      content_max = 0,
    }
  end,
  BASE_short =  function ()
    return {
      min         = 1,
      content_min = 1,
      content_max = 0,
      max         = 0,
      level       = 0,
    }
  end,
  BASE_long =  function ()
    return {
      min         = 1,
      content_min = 1,
      content_max = 0,
      max         = 0,
      level       = 0,
    }
  end,
  __storage = {},
}

setmetatable(DB, {
  __index = function (self, k)
    return self.__storage[k]
  end,
})

---comment
---@param category string @ "line_doc", "line_comment", "param"...
---@vararg string|nil @ when nil, remaining arguments are ignored
function DB:fill(category, ...)
  local storage = self.__storage[category]
  local scope = function (p)
    return function ()
      return deep_copy(p)
    end
  end
  if not storage then
    storage = {}
    self.__storage[category] = storage
  end
  local params = { ... }
  ---@vararg any
  local i = 1
  local p = params[i]
  local t --  the data collecting test material
  repeat
    if type(p) == "string" then
      if t then
        append(storage, t)
      end
      t = {
        s = p
      }
      i = i + 1; p = params[i]
      if type(p) == "string" then
        t.c = p
        i = i + 1; p = params[i]
      end
      t.x = type(p) == "function"
          and p
          or  scope(p)
      i = i + 1; p = params[i]
      if type(p) ~= "string" then
        t.d = p
        i = i + 1; p = params[i]
      end
    else
      break
    end
  until false
  append(storage, t)
end

DB:fill(
  "line_doc",
  [[
--- LINE DOC WITH 3 SPACES   
]],
  function (self, min)
    min = min or 1
    return {
      min         = min,
      content_min = min + 4,
      content_max = min + 25,
      max         = min + 29,
    }
  end,
  "--- ",
  {
    min = 1,
    content_min = 5,
    content_max = 4,
    max = 4,
  },
  "--- 5678",
  {
    min = 1,
    content_min = 5,
    content_max = 8,
    max = 8,
  },
  "--- 5678\n",
  {
    min = 1,
    content_min = 5,
    content_max = 8,
    max = 9,
  },
  "--- 5678\nabc",
  {
    min = 1,
    content_min = 5,
    content_max = 8,
    max = 9,
  }
)
DB:fill(
  "short_literal",
  '"234"  \n  ',
  {
    min = 1,
    content_min = 2,
    content_max = 4,
    max = 8,
  },
  "'234'  \n  ",
  {
    min         = 1,
    content_min = 2,
    content_max = 4,
    max         = 8,
  },
  "'234'",
  {
    min = 1,
    content_min = 2,
    content_max = 4,
    max = 5,
  },
  '"234"',
  {
    min = 1,
    content_min = 2,
    content_max = 4,
    max = 5,
  },
  [["2'4"]],
  {
    min = 1,
    content_min = 2,
    content_max = 4,
    max = 5,
  },
  [['2"4']],
  {
    min = 1,
    content_min = 2,
    content_max = 4,
    max = 5,
  },
  [['2"4'abcd''"]],
  {
    min = 1,
    content_min = 2,
    content_max = 4,
    max = 5,
  }
)
DB:fill(
  "long_literal",
  '[[345]]  \n  ',
  {
    min         = 1,
    content_min = 3,
    content_max = 5,
    max         = 10,
    level       = 0,
  },
  '[===[678]===]  \n  ',
  {
    min         = 1,
    content_min = 6,
    content_max = 8,
    max         = 16,
    level       = 3,
  },
  [=====[
[[34567]]etc]=====],
  {
    min = 1,
    content_min = 3,
    content_max = 7,
    max = 9,
    level = 0,
  },
  [=====[
[==[5]==]etc]=====],
  {
    min = 1,
    content_min = 5,
    content_max = 5,
    max = 9,
    level = 2,
  },
  [=====[
[==[[[]]]==]  etc]=====],
  {
    min = 1,
    content_min = 5,
    content_max = 8,
    max = 14,
    level = 2,
  }
)
DB:fill(
  "line_comment",
  '-  \n  ',
  nil,
  '---  \n  ',
  nil,
  2,
  '--  ',
  {
    min         = 1,
    content_min = 5,
    content_max = 4,
    max         = 4,
  },
  '--  \n  ',
  {
    min         = 1,
    content_min = 5,
    content_max = 4,
    max         = 5,
  },
  '----------',
{
    min         = 1,
    content_min = 11,
    content_max = 10,
    max         = 10,
  },
  '-- 456 89A \n  ',
  {
    min         = 1,
    content_min = 4,
    content_max = 10,
    max         = 12,
  },
  "--",
  {
    min = 1,
    content_min = 3,
    content_max = 2,
    max = 2,
  },
  "-- 45678",
  {
    min = 1,
    content_min = 4,
    content_max = 8,
    max = 8,
  },
  "-- 45678\n",
  {
    min = 1,
    content_min = 4,
    content_max = 8,
    max = 9,
  },
  "-- 45678\nabcd",
  {
    min = 1,
    content_min = 4,
    content_max = 8,
    max = 9,
  }
)
DB:fill(
  'long_comment',
  '--  \n  ',
  nil,
  '--[[56 89A]]',
  {
    min         = 1,
    content_min = 5,
    content_max = 10,
    max         = 12,
    level       = 0,
  },
  '--[[\n6 89A]]',
  {
    min         = 1,
    content_min = 6,
    content_max = 10,
    max         = 12,
    level       = 0,
  },
  '--[[\n  8\nA  ]]',
  {
    min         = 1,
    content_min = 6,
    content_max = 10,
    max         = 14,
    level       = 0,
  },
  '--[==[78]=] \n ]==] ',
  {
    min         = 1,
    content_min = 7,
    content_max = 13,
    max         = 19,
    level       = 2,
  },
  [=====[
--[[5
7
9]]etc]=====],
  {
    min = 1,
    content_min = 5,
    content_max = 9,
    max = 11,
    level = 0,
  },
  [=====[
--[=[6]==]B]=]etc]=====],
  {
    min = 1,
    content_min = 6,
    content_max = 11,
    max = 14,
    level = 1,
  },
  [=====[
--[===[89]===]      etc]=====],
  nil
)
DB:fill(
  "line_doc",
  '-- ',
  nil,
  '---- ',
  nil,
  '---- ',
  nil,
  1,
  '---',
  {
    min         = 1,
    content_min = 4,
    content_max = 3,
    max         = 3,
  },
  '---456789A',
  {
    min         = 1,
    content_min = 4,
    content_max = 10,
    max         = 10,
  },
  '--- 56 89 ',
  {
    min         = 1,
    content_min = 5,
    content_max = 9,
    max         = 10,
  },
  '--- 56 89 \n',
  {
    min         = 1,
    content_min = 5,
    content_max = 9,
    max         = 11,
  },
  [=====[
---456789
---456789
---456789
]=====],
  {
    min         = 1,
    content_min = 4,
    content_max = 9,
    max         = 10,
  },
  [=====[
---456789
---456789
---456789
]=====],
  {
    min         = 11,
    content_min = 14,
    content_max = 19,
    max         = 20,
  },
  11,
  [=====[
---456789
---456789
---456789
]=====],
  {
    min         = 21,
    content_min = 24,
    content_max = 29,
    max         = 30,
  },
  21
)
DB:fill(
  "long_doc",
  '-- ',
  nil,
  '--- ',
  nil,
  '--[===[]===]',
  {
    min         = 1,
    content_min = 8,
    content_max = 7,
    max         = 12,
  },
  '--[===[89AB]===]',
  {
    min         = 1,
    content_min = 8,
    content_max = 11,
    max         = 16,
  },
  '--[===[89 B]===]',
  {
    min         = 1,
    content_min = 8,
    content_max = 11,
    max         = 16,
  },
  '--[===[89 B]===]\n',
{
    min         = 1,
    content_min = 8,
    content_max = 11,
    max         = 17,
  },
  [=====[
--[[5
7
9]]etc]=====],
  nil,
[=====[
--[=[6]==]B]=]etc]=====],
  nil,
[=====[
--[===[89]===]      etc]=====],
  {
    min         = 1,
    content_min = 8,
    content_max = 9,
    max         = 20,
  }
)
DB:fill(
  "core_author",
  -----5----0----5----0----5----0----5----0----5
  "1hat do you want of 22  ",
  {
    value = "1hat do you want of 22",
  }
)
DB:fill(
  "author",
  -----5----0----5----0----5----0----5----0----5
  "---@author 9hat do you want of 30  ",
  "9hat do you want of 30", -- content
  {
    min         = 1,
    content_min = 12,
    content_max = 33,
    max         = 35,
  }
)
DB:fill(
  "core_field",
  -----5----0----5----0
  "public foo bar",
  {
    visibility  = "public",
    name        = "foo",
    types       = { "bar" },
    content_min = 15,
    content_max = 14,
  },
  -----5----0----5----0
  "private foo bar",
  {
    visibility  = "private",
    name        = "foo",
    types       = { "bar" },
    content_min = 16,
    content_max = 15,
  },
  -----5----0----5----0
  "protected foo bar",
  {
    visibility  = "protected",
    name        = "foo",
    types       = { "bar" },
    content_min = 18,
    content_max = 17,
  },
  -----5----0----5----0----5----0
  "public foo bar @ COMMENT",
  {
    visibility  = "public",
    name        = "foo",
    types       = { "bar" },
    content_min = 18,
    content_max = 24,
  }
)
DB:fill(
  "field",
  -----5----0----5----0----5----0
  "--- @field public f21 b25",
  {
    min         = 1,
    content_min = 26,
    content_max = 25,
    max         = 25,
    visibility  = "public",
    name        = "f21",
    types       = { "b25" },
  },
  -----5----0----5----0----5----0----5
  "--- @field private f22 b26\n   ",
  {
    min         = 1,
    content_min = 27,
    content_max = 26,
    max         = 27,
    visibility  = "private",
    name        = "f22",
    types       = { "b26" },
  },
  -----5----0----5----0----5----0----5----0----5
  "--- @field private f22 b26 @ commentai40   ",
  {
    min         = 1,
    content_min = 30,
    content_max = 40,
    max         = 43,
    visibility  = "private",
    name        = "f22",
    types       = { "b26" },
  },
  -----5----0----5----0----5----0----5----0----5
  "--- @field private f22 b26\n   ",
  {
    min         = 1,
    content_min = 27,
    content_max = 26,
    max         = 27,
    visibility  = "private",
    name        = "f22",
    types       = { "b26" },
  },
  -----5----0----5----0----5----0----5----0----5
  "123456789--- @field private f22 b26\n   ",
  {
    min         = 10,
    content_min = 36,
    content_max = 35,
    max         = 36,
    visibility  = "private",
    name        = "f22",
    types       = { "b26" },
  },
  10
)
DB:fill(
  "core_see",
  -----5----0----5----0----5----0----5
  "9hat do you want of 22  ",
  {
    value = "9hat do you want of 22",
  }
)
DB:fill(
  "see",
  -----5----0----5----0----5----0----5
  "---@see 9hat do you want of 30  ",
  "9hat do you want of 30",
  {
    min         = 1,
    content_min = 9,
    content_max = 30,
    max         = 32,
  }
)
DB:fill(
  "core_class",
  -----5----0----5----0----5----0----5
  "NAME",
  {
    name = "NAME",
    content_min = 5,
    content_max = 4,
  },
  -----5----0----5----0----5----0----5
  "NAME: PARENT",
  {
    name = "NAME",
    parent = "PARENT",
    content_min = 13,
    content_max = 12,
  },
  -----5----0----5----0----5----0----5
  "NAME @ COMMENT",
  {
    name = "NAME",
    content_min = 8,
    content_max = 14,
  },
  -----5----0----5----0----5----0----5
  "NAME: PARENT @ COMMENT",
  {
    name = "NAME",
    parent = "PARENT",
    content_min = 16,
    content_max = 22,
  }
)
DB:fill(
  "class",
  -----5----0----5----0----5----0----5----0----5
  "---@class MY_TY17",
  {
    min         = 1,
    content_min = 18,
    content_max = 17,
    max         = 17,
  },
  -----5----0----5----0----5----0----5----0----5
  "---@class AY_TYPE: PARENT_TY30",
  {
    min         = 1,
    content_min = 31,
    content_max = 30,
    max         = 30,
    name        = "AY_TYPE",
    parent      = "PARENT_TY30",
  }
)
DB:fill(
  "core_type",
  -----5----0----5----0----5----0----5----0
  "TYPE",
  {
    content_min = 5,
    content_max = 4,
    types = { "TYPE" },
  },
  -----5----0----5----0----5----0----5----0
  "TYPE | OTHER_TYPE",
  {
    content_min = 18,
    content_max = 17,
    types = { "TYPE", "OTHER_TYPE" },
  },
  -----5----0----5----0----5----0----5----0
  "TYPE @ COMMENT",
  {
    content_min = 8,
    content_max = 14,
    types = { "TYPE" },
  },
  -----5----0----5----0----5----0----5----0
  "TYPE | OTHER_TYPE @ COMMENT",
  {
    content_min = 21,
    content_max = 27,
    types = { "TYPE", "OTHER_TYPE" },
  }
)
DB:fill(
  "type",
----5----0----5----0----5----0----5----0
    [=====[
---@type MY_TYPE]=====],
  {
    min = 1,
    content_min = 17,
    content_max = 16,
    max = 16,
    types = { "MY_TYPE" },
  },
----5----0----5----0----5----0----5----0
    [=====[
---@type MY_TYPE|OTHER_TYPE]=====],
  {
    min = 1,
    content_min = 28,
    content_max = 27,
    max = 27,
    types = { "MY_TYPE", "OTHER_TYPE" },
  },
----5----0----5----0----5----0----5----0
    [=====[
---@type MY_TYPE|OTHER_TYPE @ COMMENT ]=====],
  "COMMENT",
  {
    min = 1,
    content_min = 31,
    content_max = 37,
    max = 38,
    types = { "MY_TYPE", "OTHER_TYPE" },
  }
)
DB:fill(
  "core_param",
  -----5----0----5----0----5----0----5----0----5----
  "NAME TYPE",
  {
    name        = "NAME",
    optional    = false,
    types       = { "TYPE" },
    content_min = 10,
    content_max = 9,
  },
  -----5----0----5----0----5----0----5----0----5----
  "NAME ? TYPE",
  {
    name        = "NAME",
    optional    = true,
    types       = { "TYPE" },
    content_min = 12,
    content_max = 11,
  },
  -----5----0----5----0----5----0----5----0----5----
  "NAME TYPE | OTHER",
  {
    name        = "NAME",
    optional    = false,
    types       = { "TYPE", "OTHER" },
    content_min = 18,
    content_max = 17,
  },
  -----5----0----5----0----5----0----5----0----5----
  "NAME ? TYPE | OTHER",
  {
    name        = "NAME",
    optional    = true,
    types       = { "TYPE", "OTHER" },
    content_min = 20,
    content_max = 19,
  },

  -----5----0----5----0----5----0----5----0----5----
  "NAME TYPE @ COMMENT",
  {
    name        = "NAME",
    optional    = false,
    types       = { "TYPE" },
    content_min = 13,
    content_max = 19,
  },
  -----5----0----5----0----5----0----5----0----5----
  "NAME ? TYPE @ COMMENT",
  {
    name        = "NAME",
    optional    = true,
    types       = { "TYPE" },
    content_min = 15,
    content_max = 21,
  },
  -----5----0----5----0----5----0----5----0----5----
  "NAME TYPE | OTHER @ COMMENT",
  {
    name        = "NAME",
    optional    = false,
    types       = { "TYPE", "OTHER" },
    content_min = 21,
    content_max = 27,
  },
  -----5----0----5----0----5----0----5----0----5----
  "NAME ? TYPE | OTHER @ COMMENT",
  {
    name        = "NAME",
    optional    = true,
    types       = { "TYPE", "OTHER" },
    content_min = 23,
    content_max = 29,
  }
)
DB:fill(
  "core_alias",
  -----5----0----5----0----5----0----5----0
  "NAME TYPE",
  {
    content_min = 10,
    content_max = 9,
    name        = "NAME",
    types       = { "TYPE" },
  },
  -----5----0----5----0----5----0----5----0
  "NAME TYPE @ COMMENT ",
  {
    content_min = 13,
    content_max = 19,
    name        = "NAME",
    types       = { "TYPE" },
  }
)
DB:fill(
  "alias",
----5----0----5----0----5----0----5----0
  [=====[
---@alias NEW_NAME TYPE ]=====],
  {
    min         = 1,
    content_min = 24,
    content_max = 23,
    max         = 24,
    name        = "NEW_NAME",
    types       = { "TYPE" },
  },
----5----0----5----0----5----0----5----0
    [=====[
---@alias NEW_NAME TYPE | OTHER_TYPE ]=====],
{
    min         = 1,
    content_min = 37,
    content_max = 36,
    max         = 37,
    name        = "NEW_NAME",
    types       = { "TYPE", "OTHER_TYPE" },
  },
----5----0----5----0----5----0----5----0----5----
    [=====[
---@alias     NAME TYPE @ SOME   COMMENT]=====],
  "SOME   COMMENT",
  {
    min         = 1,
    content_min = 27,
    content_max = 40,
    max         = 40,
    name        = "NAME",
    types       = { "TYPE" },
  },
----5----0----5----0----5----0----5----0----5----
  [=====[
---@alias     NAME TYPE @ SOME   COMMENT         
  SUITE                                        ]=====],
  "SOME   COMMENT",
  {
    min         = 1,
    content_min = 27,
    content_max = 40,
    max         = 50,
    name        = "NAME",
    types       = { "TYPE" },
    }
)
DB:fill(
  "param",
----5----0----5----0----5----0----5----0----5----
  [=====[
---@param NAME TYPE]=====],
  "",
  {
    min         = 1,
    content_min = 20,
    content_max = 19,
    max         = 19,
    name        = "NAME",
    optional    = false,
    types       = { "TYPE" },
  },
----5----0----5----0----5----0----5----0----5----
  [=====[
---@param NAME ? TYPE]=====],
  "",
  {
    min         = 1,
    content_min = 22,
    content_max = 21,
    max         = 21,
    name        = "NAME",
    optional    = true,
    types       = { "TYPE" },
  },
----5----0----5----0----5----0----5----0----5----
  [=====[
---@param NAME TYPE
]=====],
  "",
  {
    min         = 1,
    content_min = 20,
    content_max = 19,
    max         = 20,
    name        = "NAME",
    optional    = false,
    types       = { "TYPE" },
  },
----5----0----5----0----5----0----5----0----5----
  [=====[
---@param NAME ? TYPE
]=====],
  "",
  {
    min         = 1,
    content_min = 22,
    content_max = 21,
    max         = 22,
    name        = "NAME",
    optional    = true,
    types       = { "TYPE" },
  },
----5----0----5----0----5----0----5----0----5----
  [=====[
---@param NAME TYPE  |  OTHER
]=====],
  "",
  {
    min         = 1,
    content_min = 30,
    content_max = 29,
    max         = 30,
    name        = "NAME",
    optional    = false,
    types       = { "TYPE", "OTHER" },
  },
----5----0----5----0----5----0----5----0----5----
  [=====[
---@param NAME TYPE  |  OTHER@  COMMENT
]=====],
  "COMMENT",
  {
    min         = 1,
    content_min = 33,
    content_max = 39,
    max         = 40,
    name        = "NAME",
    optional    = false,
    types       = { "TYPE", "OTHER" },
  }
)
DB:fill(
  "core_return",
  -----5----0----5----0----5----0----5----0
  "TYPE",
  {
    content_min = 5,
    content_max = 4,
    types = { "TYPE" },
    optional = false,
  },
  -----5----0----5----0----5----0----5----0
  "TYPE | OTHER_TYPE",
  {
    content_min = 18,
    content_max = 17,
    types = { "TYPE", "OTHER_TYPE" },
    optional = false,
  },
  -----5----0----5----0----5----0----5----0
  "TYPE @ COMMENT",
  {
    content_min = 8,
    content_max = 14,
    types = { "TYPE" },
    optional = false,
  },
  -----5----0----5----0----5----0----5----0
  "TYPE | OTHER_TYPE @ COMMENT",
  {
    content_min = 21,
    content_max = 27,
    types = { "TYPE", "OTHER_TYPE" },
    optional = false,
  },
  "TYPE ?",
  {
    content_min = 7,
    content_max = 6,
    types = { "TYPE" },
    optional = true,
  },
  -----5----0----5----0----5----0----5----0
  "TYPE | OTHER_TYPE ?",
  {
    content_min = 20,
    content_max = 19,
    types = { "TYPE", "OTHER_TYPE" },
    optional = true,
  },
  -----5----0----5----0----5----0----5----0
  "TYPE ? @ COMMENT",
  {
    content_min = 10,
    content_max = 16,
    types = { "TYPE" },
    optional = true,
  },
  -----5----0----5----0----5----0----5----0
  "TYPE | OTHER_TYPE ? @ COMMENT",
  {
    content_min = 23,
    content_max = 29,
    types = { "TYPE", "OTHER_TYPE" },
    optional = true,
  }
)
DB:fill(
  "return",
----5----0----5----0----5----0----5----0----5----
  [=====[
---   @return TYPE   |  OTHER @ COMMENT
]=====],
  "COMMENT",
  {
    min         = 1,
    max         = 40,
    content_min = 33,
    content_max = 39,
    types       = { "TYPE", "OTHER" },
  },
----5----0----5----0----5----0----5----0----5----
  [=====[
---   @return TYPE? @ COMMENT
]=====],
  "COMMENT",
  {
    min         = 1,
    max         = 30,
    content_min = 23,
    content_max = 29,
    types       = { "TYPE" },
    optional    = true,
  }
)
DB:fill(
  "core_generic",
  -----5----0----5----0----5----0
  "T1",
  {
    type_1    = "T1",
    content_min = 3,
    content_max = 2,
  },
  -----5----0----5----0----5----0
  "T1: P1",
  {
    type_1    = "T1",
    parent_1  = "P1",
    content_min = 7,
    content_max = 6,
  },
  -----5----0----5----0----5----0
  "T1, T2",
  {
    type_1    = "T1",
    type_2    = "T2",
    content_min = 7,
    content_max = 6,
  },
  -----5----0----5----0----5----0
  "T1 : P1, T2",
  {
    type_1    = "T1",
    parent_1  = "P1",
    type_2    = "T2",
    content_min = 12,
    content_max = 11,
  },
  -----5----0----5----0----5----0
  "T1, T2 : P2",
  {
    type_1    = "T1",
    type_2    = "T2",
    parent_2  = "P2",
    content_min = 12,
    content_max = 11,
  },
  -----5----0----5----0----5----0
  "T1 : P1, T2 : P2",
  {
    type_1    = "T1",
    parent_1  = "P1",
    type_2    = "T2",
    parent_2  = "P2",
    content_min = 17,
    content_max = 16,
  },
  -----5----0----5----0----5----0
  "T1 : P1, T2 : P2 @  COMMENT",
  {
    type_1    = "T1",
    parent_1  = "P1",
    type_2    = "T2",
    parent_2  = "P2",
    content_min = 21,
    content_max = 27,
  }
)
DB:fill(
  "generic",
  [=====[
---@generic T1
]=====],
  {
    type_1    = "T1",
  },
  [=====[
---@generic T1: PARENT_TYPE_1
]=====],
  {
    type_1    = "T1",
    parent_1  = "PARENT_TYPE_1",
  },
  [=====[
---@generic T1, T2
]=====],
{
  type_1    = "T1",
  type_2    = "T2",
},
  [=====[
---@generic T1 : PARENT_TYPE_1, T2
]=====],
{
  type_1    = "T1",
  parent_1  = "PARENT_TYPE_1",
  type_2    = "T2",
},
  [=====[
---@generic T1, T2 : PARENT_TYPE_2
]=====],
{
  type_1    = "T1",
  type_2    = "T2",
  parent_2  = "PARENT_TYPE_2",
},
  [=====[
---@generic T1 : PARENT_TYPE_1, T2 : PARENT_TYPE_2
]=====],
{
  type_1    = "T1",
  parent_1  = "PARENT_TYPE_1",
  type_2    = "T2",
  parent_2  = "PARENT_TYPE_2",
},
----5----0----5----0----5----0----5----0----5----0----5----0----5
  [=====[
---@generic   T1 : PARENT_TYPE_1, T2 : PARENT_TYPE_2 @  COMMENT
]=====],
  "COMMENT",
  {
    min = 1,
    max = 64,
    type_1    = "T1",
    parent_1  = "PARENT_TYPE_1",
    type_2    = "T2",
    parent_2  = "PARENT_TYPE_2",
  }
)
DB:fill(
  "core_vararg",
  -----5----0----5----0----5----0----5----0----5----0----5----
  "TYPE",
  {
    types       = { "TYPE" },
    content_min = 5,
    content_max = 4,
  },
  -----5----0----5----0----5----0----5----0----5----0----5----
  "TYPE | OTHER",
  {
    types       = { "TYPE", "OTHER" },
    content_min = 13,
    content_max = 12,
  },
  -----5----0----5----0----5----0----5----0----5----0----5----
  "TYPE @ COMMENT",
  {
    types       = { "TYPE" },
    content_min = 8,
    content_max = 14,
  },
  -----5----0----5----0----5----0----5----0----5----0----5----
  "TYPE | OTHER @ COMMENT",
  {
    types       = { "TYPE", "OTHER" },
    content_min = 16,
    content_max = 22,
  }
)
DB:fill(
  "vararg",
----5----0----5----0----5----0----5----0----5----0----5----
  [=====[
---@vararg    TYPE_
]=====],
  "",
  {
    min         = 1,
    content_min = 20,
    content_max = 19,
    max         = 20,
    types       = { "TYPE_" },
  },
----5----0----5----0----5----0----5----0----5----0----5----
  [=====[
---@vararg    TYPE_|TYPE
]=====],
  "",
  {
    min         = 1,
    content_min = 25,
    content_max = 24,
    max         = 25,
    types       = { "TYPE_", "TYPE" },
  },
----5----0----5----0----5----0----5----0----5----0----5----
  [=====[
---@vararg    TYPE_|TYPE@CMT_
]=====],
  "CMT_",
  {
    min         = 1,
    content_min = 26,
    content_max = 29,
    max         = 30,
    types       = { "TYPE_", "TYPE" },
  }
)
DB:fill(
  "core_module",
  -----5----0----5----0----5----0----5----0----5----0----5----
  "name",
  {
    name        = "name",
    content_min = 5,
    content_max = 4,
  },
  -----5----0----5----0----5----0----5----0----5----0----5----
  "name @ COMMENT",
  {
    name        = "name",
    content_min = 8,
    content_max = 14,
  }
)
DB:fill(
  "module",
----5----0----5----0----5----0----5----0----5----0----5----
  [=====[
---   @module name_
]=====],
  "",
  {
    min         = 1,
    content_min = 20,
    content_max = 19,
    max         = 20,
    name        = "name_",
  },
----5----0----5----0----5----0----5----0----5----0----5----
  [=====[
---   @module name_ @ COMMENT
]=====],
  "COMMENT",
  {
    min         = 1,
    content_min = 23,
    content_max = 29,
    max         = 30,
    name        = "name_",
  }
)
DB:fill(
  "function",
----5----0----5----0----5----0----5----0----5----0----5----
  [=====[
---@function  name_
]=====],
  {
    min = 1,
    max = 20,
    name = "name_",
  },
---5----0----5----0----5----0----5----0----5----0----5----
  [=====[
---@function  name_ @ COMMENT
]=====],
  "COMMENT",
  {
    min         = 1,
    max         = 30,
    content_min = 23,
    content_max = 29,
    name        = "name_",
  }
)
DB:fill(
  "core_function",
  -----5----0----5----0----5----0----5----0----5----0----5----
  "NAME",
  {
    name = "NAME",
    content_min = 5,
    content_max = 4,
  },
  -----5----0----5----0----5----0----5----0----5----0----5----
  "NAME @ COMMENT",
  {
    name = "NAME",
    content_min = 8,
    content_max = 14,
  }
)
DB:fill(
  "break",
  "",
  {
    min = 1,
    max = 1,
  },
  " \n ",
  {
    min = 1,
    max = 3,
  },
  " \n \n",
  {
    min = 1,
    max = 4,
  }
)
DB:fill(
  "core_global",
  -----5----0----5----0----5----0----5----0----5----0----5----
  "NAME",
  {
    name = "NAME",
    types = {},
    content_min = 5,
    content_max = 4,
  },
  -----5----0----5----0----5----0----5----0----5----0----5----
  "NAME TYPE",
  {
    name = "NAME",
    types = { "TYPE" },
    content_min = 10,
    content_max = 9,
  },
  -----5----0----5----0----5----0----5----0----5----0----5----
  "NAME @ COMMENT",
  {
    name = "NAME",
    types = {},
    content_min = 8,
    content_max = 14,
  },
  -----5----0----5----0----5----0----5----0----5----0----5----
  "NAME TYPE @ COMMENT",
  {
    name = "NAME",
    types = { "TYPE" },
    content_min = 13,
    content_max = 19,
  }
)
DB:fill(
  "global",
----5----0----5----0----5----0----5----0----5----0----5----
  [=====[
---  @global  name_
]=====],
  {
    min = 1,
    max = 20,
    name = "name_",
  },
---5----0----5----0----5----0----5----0----5----0----5----
  [=====[
---  @global  name_ @ COMMENT
]=====],
  "COMMENT",
  {
    min = 1,
    max = 30,
    name = "name_",
  },
----5----0----5----0----5----0----5----0----5----0----5----
  [=====[
---   @global NAME TYPE @ CMT
]=====],
  "CMT",
  {
    min = 1,
    content_min = 27,
    content_max = 29,
    max = 30,
    name = "NAME",
    types = { "TYPE" }
  }
)
DB:fill(
  "guess_function_name",
  "local function NAME()",
  {
    is_local  = true,
    name      = "NAME"
  },
  "function NAME()",
  {
    is_local  = false,
    name      = "NAME"
  },
  "function CLASS.NAME()",
  {
    is_local  = false,
    name      = "CLASS.NAME"
  },
  "function CLASS:NAME()",
  {
    is_local  = false,
    name      = "CLASS:NAME"
  },
  "local NAME = function ()",
  {
    is_local  = true,
    name      = "NAME"
  },
  "NAME = function ()",
  {
    is_local  = false,
    name      = "NAME"
  },
  "CLASS.NAME = function ()",
  {
    is_local  = false,
    name      = "CLASS.NAME"
  },
  "xlocal NAME = function ()",
  {
    is_local  = false,
    name      = "NAME"
  }
)
DB:fill(
  "paragraph_break",
  "\n",
  {
    min = 1,
    max = 1,
  },
  " \n ",
  {
    min = 1,
    max = 3,
  },
  " \n \n",
  {
    min = 1,
    max = 4,
  }
)
DB:fill(
  "named_pos",
  "",
  {
    POSITION    = 1,
  },
  {
    before  = 0,
    shift   = 0,
    name    = "POSITION",
  },
  "1234567890",
  {
    POSITION    = 0,
  },
  {
    before  = 0,
    shift   = 1,
    name    = "POSITION",
  },
  "1234567890",
  {
    POSITION    = 6,
  },
  {
    before  = 5,
    shift   = 0,
    name    = "POSITION",
  },
  "1234567890",
  {
    POSITION    = 3,
  },
  {
    before  = 5,
    shift   = 3,
    name    = "POSITION",
  }
)
DB:fill(
  "chunk_stop",
  "",
  {
    max = 0,
  },
  "  ",
  {
    max = 2,
  },
  "  \n  ",
  {
    max = 3,
  }
)
DB:fill(
  "one_line_chunk_stop",
  "",
  {
    max = 0,
  },
  "  ",
  {
    max = 2,
  },
  "  \n  ",
  {
    max = 3,
  },
  "xx",
  {
    max = 2,
  },
  "xx\n  ",
  {
    max = 3,
  }
)
DB:fill(
  "special_begin",
  "",
  nil,
  "-",
  nil,
  "----",
  nil,
  "--",
  nil,
  "---",
  4,
  "  -",
  nil,
  "  --",
  nil,
  "  ---",
  6,
  "  ---  ",
  8
)
DB:fill(
  "capture_comment",
  "@",
  {
    content_min = 2,
    content_max = 1,
  },
  "  @ 567",
  {
    content_min = 5,
    content_max = 7,
  }
)
DB:fill(
  "lua_type",
  -----5----0----5----0----5----0----5----0----5----
  "abc", 4,
  "abc<", 4,
  "foo", 4,
  "bar", 4,
  "bar[]", 6,
  "table<k, v>", 12,
  "table<k, v>[]", 14,
  "fun", 4,
  "fun()", 6,
  "fun(...)", 9,
  "fun(foo : bar)", 15,
  "fun(foo : bar, ...)", 20,
  "fun(foo : bar, foo: bar, ...)", 30,
  "fun():foo", 10,
  "fun():foo, bar", 15,
  "fun():foo | bar", 16
)
DB:fill(
  "named_types",
  "foo", { types = { "foo" } },
  "foo|chi", { types = { "foo", "chi" } },
  "foo|chi|mee", { types = { "foo", "chi" , "mee" } },
  "foo | chi | mee", { types = { "foo", "chi" , "mee" } }
)
DB:fill(
  "named_optional",
  "", { optional = false },
  "?", { optional = true },
  "  ?  ", { optional = true }
)
DB:fill(
  "at_match",
  "", nil, { name = "NAME" },
  "---@NAME", 9, { name = "NAME" },
  "---@NAMEX", nil, { name = "NAME" }
)
DB:fill(
  "content",
  "", {
    content_min=1,
    content_max=0,
  },
  " 2 4 6 8 ", {
    content_min = 1,
    content_max = 8,
  }
)
DB:fill(
  "description"
)

return DB
