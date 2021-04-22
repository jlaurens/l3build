#!/usr/bin/env texlua

--[[

File l3b-test/autodoc_data.lua Copyright (C) 2018-2020 The LaTeX Project

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

local Object = Object
local AD = AD
local expect = expect
local LU = LU

---@class AD.TestData
---@field public s string   @ target
---@field public m AD.Info  @ match result
---@field public c string   @ comment

---@type AD.TestData
local TestData = {
  s = "UNKNOWN STRING",
  m = { "UNKNOWN MATCH" },
  -- c = "ERROR: NOT AVAILABLE",
}
TestData.__index = TestData
setmetatable(TestData, {
  __call = function (self, d)
    d = d or {}
    return setmetatable(d, self)
  end,
})


-- All the tests are object with next `Test` as metatable
local Test = {
  get_LINE_DOC = function ()
    return TestData({
----5----0----5----0----5----0
      s = [[
--- LINE DOC WITH 3 SPACES   
]],
      x = function (self, min)
        min = min or 1
        return {
          min         = min,
          content_min = min + 4,
          content_max = min + 25,
          max         = min + 29,
        }
      end,
      m = function (self, min)
        return AD.LineDoc(self:x(min))
      end,
    })
  end,
  get_LONG_DOC = function ()
    return TestData({
----5----0----5----0----5----0
      s = [[
--[===[VEEEEEEEEERY
LOOOOOOOOOOOOOOOONG
DOOOOOOOOOOOOOOOOOC
              ]===]
]],
      x = function (self, min)
        min = min or 1
        return {
          min         = min,
          content_min = min + 7,
          content_max = min + 59,
          max         = min + 79,
        }
      end,
      m = function (self, min)
        return AD.LongDoc(self:x(min))
      end,
    })
  end,
  get_AUTHOR = function()
    return TestData({
----5----0----5----0----5----0----5----0----5
      s = [[
--- @author  pseudo
]],
      x = function (self, min, offset)
        min = min or 1
        offset = offset or 0
        return {
          min         = min,
          content_min = min + offset + 13,
          content_max = min + offset + 18,
          max         = min + offset + 19,
        }
      end,
      m = function (self, min, offset)
        return AD.At.Author(self:x(min, offset))
      end,
    })
  end,
  get_FIELD = function ()
    return TestData({
----5----0----5----0----5----0----5----0----5
      s = [[
--- @field public NAME TYPE @ COMMENT39
]],
      c = "COMMENT39",
      x = function (self, min, offset) -- get the FIELD match
        min = min or 1
        offset = offset or 0
        return {
          min         = min,
          content_min = min + offset + 30,
          content_max = min + offset + 38,
          max         = min + offset + 39,
          visibility  = "public",
          name        = "NAME",
          types       = { "TYPE" },
        }
      end,
      m = function (self, min, offset) -- get the FIELD match
        return AD.At.Field(self:x(min, offset))
      end,
    })
  end,
  get_SEE = function()
    return TestData({
----5----0----5----0----5----0----5----0----5
      s = [[
--- @see  reference
]],
      x = function (self, min, offset)
        min = min or 1
        offset = offset or 0
        return {
          min         = min,
          content_min = min + offset + 10,
          content_max = min + offset + 18,
          max         = min + offset + 19,
        }
      end,
      m = function (self, min, offset)
        return AD.At.See(self:x(min, offset))
      end,
    })
  end,
  get_CLASS = function ()
    return TestData({
----5----0----5----0----5----0----5----0----5
      s = [[
---@class NAME: PARENT @         COMMENT
]],
      c = "COMMENT",
      x = function (self, min, offset)
        min = min or 1
        offset = offset or 0
        return {
          min         = min,
          content_min = min + offset + 33,
          content_max = min + offset + 39,
          max         = min + offset + 40,
        }
      end,
      m = function (self, min, offset)
        return AD.At.Class(self:x(min, offset))
      end,
    })
  end,
  get_CLASS_COMPLETE = function ()
    return TestData({
----5----0----5----0----5----0----5----0----5----0----5
      s = [[
---CLASS:   SHORT DESCRIPTION
---CLASS:   LONG  DESCRIPTION
---@class NAME: PARENT @ CLASS: COMMENT
---FIELD_1: SHORT DESCRIPTION
---FIELD_1: LONG  DESCRIPTION
---@field protected FIELD_1 TYPE_1 @ FIELD_1: CMT
---FIELD_2: SHORT DESCRIPTION
---FIELD_2: LONG  DESCRIPTION
---@field protected FIELD_2 TYPE_2 @ FIELD_2: CMT
---AUTHOR:  SHORT DESCRIPTION
---AUTHOR:  LONG  DESCRIPTION
---@author  PSEUDO IDENTIFIER
---SEE:     SHORT DESCRIPTION
---SEE:     LONG  DESCRIPTION
---@see    VARIOUS REFERENCES
]],
    m = function (self, min, offset)
      return AD.At.Class({
        description = AD.Description({
          min     = 1,
          max     = 60,
          short   = AD.LineDoc({
            min         = 1,
            content_min = 4,
            content_max = 29,
            max         = 30,
          }),
          long    = {
            AD.LineDoc({
              min         = 31,
              content_min = 34,
              content_max = 59,
              max         = 60,
            }),
          },
          ignores = {},
        }),
        min         = 61,
        content_min = 86,
        content_max = 99,
        max         = 500,
        name        = "NAME",
        fields      = {
          AD.At.Field({
            description = AD.Description({
              min     = 101,
              max     = 160,
              short   = AD.LineDoc({
                min         = 101,
                content_min = 104,
                content_max = 129,
                max         = 130,
              }),
              long    = {
                AD.LineDoc({
                  min         = 131,
                  content_min = 134,
                  content_max = 159,
                  max         = 160,
                }),
              },
              ignores = {},
            }),
            min         = 161,
            content_min = 198,
            content_max = 209,
            max         = 210,
            name        = "FIELD_1",
            visibility  = "protected",
            types       = { "TYPE_1" },
          }),
          AD.At.Field({
            description = AD.Description({
              min     = 211,
              max     = 270,
              short   = AD.LineDoc({
                min         = 211,
                content_min = 214,
                content_max = 239,
                max         = 240,
              }),
              long    = {
                AD.LineDoc({
                  min         = 241,
                  content_min = 244,
                  content_max = 269,
                  max         = 270,
                }),
              },
              ignores = {},
            }),
            min         = 271,
            content_min = 308,
            content_max = 319,
            max         = 320,
            name        = "FIELD_2",
            visibility  = "protected",
            types       = { "TYPE_2" },
          }),
        },
        author      = AD.At.Author({
          description = AD.Description({
            min     = 321,
            max     = 380,
            short   = AD.LineDoc({
              min         = 321,
              content_min = 324,
              content_max = 349,
              max         = 350,
            }),
            long    = {
              AD.LineDoc({
                min         = 351,
                content_min = 354,
                content_max = 379,
                max         = 380,
              }),
            },
            ignores = {},
          }),
          min         = 381,
          content_min = 393,
          content_max = 409,
          max         = 410,
        }),
        see         = AD.At.See({
          description = AD.Description({
            min     = 411,
            max     = 470,
            short   = AD.LineDoc({
              min         = 411,
              content_min = 414,
              content_max = 439,
              max         = 440,
            }),
            long    = {
              AD.LineDoc({
                min         = 441,
                content_min = 444,
                content_max = 469,
                max         = 470,
              }),
            },
            ignores = {},
          }),
          min         = 471,
          content_min = 482,
          content_max = 499,
          max         = 500,
        }),
      })
    end,
  })
  end,
  get_TYPE = function ()
    return TestData({
----5----0----5----0----5----0----5----0----5
      s = [[
---@type  TYPE | OTHER_TYPE @ COM  MENT
]],
      c = "COM  MENT",
      x = function (self, min, offset)
        min = min or 1
        offset = offset or 0
        return {
          min         = min,
          content_min = min + offset + 30,
          content_max = min + offset + 38,
          max         = min + offset + 39,
        }
      end,
      m = function (self, min, offset)
        return AD.At.Type(self:x(min, offset))
      end,
    })
  end,
  get_MODULE = function ()
    return TestData({
----5----0----5----0----5----0----5----0----5
      s = [[
---   @module name_ @ COMMENT
]],
      c = "COMMENT",
      x = function (self, min, offset)
        min = min or 1
        offset = offset or 0
        return {
          min         = min,
          content_min = min + offset + 22,
          content_max = min + offset + 28,
          max         = min + offset + 29,
        }
      end,
      m = function (self, min, offset)
        return AD.At.Module(self:x(min, offset))
      end,
    })
  end,
  get_ALIAS = function ()
    return TestData({
----5----0----5----0----5----0----5----0----5---0----5
      s = [=====[
---   @alias  NAME TYPE@ SOME   COMMENT         
]=====],
      c = "SOME   COMMENT",
      m = function (self, min, offset)
        min = min or 1
        offset = offset or 0
        return {
          min         = min,
          content_min = min + offset + 25,
          content_max = min + offset + 38,
          max         = min + offset + 48,
        }
      end,
      x = function (self, min, offset)
        return AD.At.Alias(self:x(min, offset))
      end,
    })
  end,
  get_PARAM = function ()
    return TestData({
----5----0----5----0----5----0----5----0----5---0----5
      s = [[
---   @param NAME TYPE  |  OTHER@ COM    MENT
]],
      c = "COM    MENT",
      x = function (self, min, offset)
        min = min or 1
        offset = offset or 0
        return {
          min         = min,
          content_min = min + offset + 34,
          content_max = min + offset + 44,
          max         = min + offset + 45,
          name        = "NAME",
          types       = { "TYPE", "OTHER", },
        }
      end,
      m = function (self, min, offset)
        return AD.At.Param(self:x(min, offset))
      end,
    })
  end,
  get_GENERIC = function ()
    return TestData({
----5----0----5----0----5----0----5----0----5----0----5
      s = [[
---  @generic  T1 : P1, T2 : P2 @  COM    MENT
]],
      c = "COM    MENT",
      x = function (self, min, offset)
        min = min or 1
        offset = offset or 0
        return {
          min         = min,
          content_min = min + offset + 35,
          content_max = min + offset + 45,
          max         = min + offset + 46,
          type_1      = "T1",
          parent_1    = "P1",
          type_2      = "T2",
          parent_2    = "P2",
        }
      end,
      m = function (self, min, offset)
        return AD.At.Generic(self:x(min, offset))
      end,
    })
  end,
  get_VARARG = function ()
    return TestData({
----5----0----5----0----5----0----5----0----5----0----5
      s = [[
---@vararg    TYPE_|TYPE@CMT_
]],
      c = "CMT_",
      x = function (self, min, offset)
        min = min or 1
        offset = offset or 0
        return {
          min         = min,
          content_min = min + offset + 25,
          content_max = min + offset + 28,
          max         = min + offset + 29,
          types       = { "TYPE_", "TYPE" },
        }
      end,
      m = function (self, min, offset)
        return AD.At.Vararg(self:x(min, offset))
      end,
    })
  end,
  get_RETURN = function ()
    return TestData({
----5----0----5----0----5----0----5----0----5----0----5
      s = [[
---   @return TYPE   |  OTHER @ COMMENT
]],
      c = "COMMENT",
      x = function (self, min, offset)
        min = min or 1
        offset = offset or 0
        return {
          min         = min,
          content_min = min + offset + 32,
          content_max = min + offset + 38,
          max         = min + offset + 39,
          types       = { "TYPE", "OTHER" },
        }
      end,
      m = function (self, min, offset)
        return AD.At.Return(self:x(min, offset))
      end,
    })
  end,
  get_FUNCTION = function ()
    return TestData({
----5----0----5----0----5----0----5---0----5----0
      s = [[
---  @function  NAME  @ COMMENT        
]],
      c = "COMMENT",
      x = function (self, min, offset)
        min = min or 1
        offset = offset or 0
        return {
          min         = min,
          content_min = min + offset + 24,
          content_max = min + offset + 30,
          max         = min + offset + 39,
          name        = "NAME",
        }
      end,
      m = function (self, min, offset)
        return AD.At.Function(self:x(min, offset))
      end,
    })
  end,
  get_FUNCTION_COMPLETE = function ()
    return TestData({
----5----0----5----0----5----0----5----0----5----0----5
      s = [[
---FUNCTION: SHORT DESCRIPT2N
---FUNCTION: LONG DESCRIPTION
---@function NAME @ FUNCTION:   COMMENT
---PARAM_1: SHORT DESCRIPTION
---PARAM_1: LONG  DESCRIPTION
---@param PARAM_1 string @ PARAM_1: CMT
---PARAM_2: SHORT DESCRIPTION
---PARAM_2: LONG  DESCRIPTION
---@param PARAM_2 string @ PARAM_2: CMT
---VARARG:  SHORT DESCRIPTION
---VARARG:  LONG  DESCRIPTION
---@vararg string @ VARARG:     COMMENT
---RETURN_1: SHORT DESCRIPT2N
---RETURN_1: LONG DESCRIPTION
---@return string  @ RETURN_1:  COMMENT
---RETURN_2: SHORT DESCRIPT2N
---RETURN_2: LONG DESCRIPTION
---@return boolean @ RETURN_2:  COMMENT
]],
    m = function (self, min, offset)
      return AD.At.Function({
        description = AD.Description({
          min     = 1,
          max     = 60,
          short   = AD.LineDoc({
            min         = 1,
            content_min = 4,
            content_max = 29,
            max         = 30,
          }),
          long    = {
            AD.LineDoc({
              min         = 31,
              content_min = 34,
              content_max = 59,
              max         = 60,
            }),
          },
          ignores = {},
        }),
        min         = 61,
        content_min = 81,
        content_max = 99,
        max         = 600,
        name        = "NAME",
        params      = {
          AD.At.Param({
            description = AD.Description({
              min     = 101,
              max     = 160,
              short   = AD.LineDoc({
                min         = 101,
                content_min = 104,
                content_max = 129,
                max         = 130,
              }),
              long    = {
                AD.LineDoc({
                  min         = 131,
                  content_min = 134,
                  content_max = 159,
                  max         = 160,
                }),
              },
              ignores = {},
            }),
            min         = 161,
            content_min = 188,
            content_max = 199,
            max         = 200,
            name        = "PARAM_1",
            optional    = false,
            types       = { "string" },
          }),
          AD.At.Param({
            description = AD.Description({
              min     = 201,
              max     = 260,
              short   = AD.LineDoc({
                min         = 201,
                content_min = 204,
                content_max = 229,
                max         = 230,
              }),
              long    = {
                AD.LineDoc({
                  min         = 231,
                  content_min = 234,
                  content_max = 259,
                  max         = 260,
                }),
              },
              ignores = {},
            }),
            min         = 261,
            content_min = 288,
            content_max = 299,
            max         = 300,
            name        = "PARAM_2",
            optional    = false,
            types       = { "string" },
          }),
        },
        vararg      = AD.At.Vararg({
          description = AD.Description({
            min     = 301,
            max     = 360,
            short   = AD.LineDoc({
              min         = 301,
              content_min = 304,
              content_max = 329,
              max         = 330,
            }),
            long    = {
              AD.LineDoc({
                min         = 331,
                content_min = 334,
                content_max = 359,
                max         = 360,
              }),
            },
            ignores = {},
          }),
          min         = 361,
          content_min = 381,
          content_max = 399,
          max         = 400,
          types       = { "string" },
        }),
        returns     = {
          AD.At.Return({
            description = AD.Description({
              min     = 401,
              max     = 460,
              short   = AD.LineDoc({
                min         = 401,
                content_min = 404,
                content_max = 429,
                max         = 430,
              }),
              long    = {
                AD.LineDoc({
                  min         = 431,
                  content_min = 434,
                  content_max = 459,
                  max         = 460,
                }),
              },
              ignores = {},
            }),
            min         = 461,
            content_min = 482,
            content_max = 499,
            max         = 500,
            types       = { "string" },
            optional    = false,
          }),
          AD.At.Return({
            description = AD.Description({
              min     = 501,
              max     = 560,
              short   = AD.LineDoc({
                min         = 501,
                content_min = 504,
                content_max = 529,
                max         = 530,
              }),
              long    = {
                AD.LineDoc({
                  min         = 531,
                  content_min = 534,
                  content_max = 559,
                  max         = 560,
                }),
              },
              ignores = {},
            }),
            min         = 561,
            content_min = 582,
            content_max = 599,
            max         = 600,
            types       = { "boolean" },
            optional    = false,
          }),
        },
      })
    end,
  })
  end,
  get_GLOBAL = function ()
    return TestData({
----5----0----5----0----5----0----5----0----5----0----5
      s = [[
---  @global  NAME @ COMMENT
]],
      c = "COMMENT",
      x = function (self, min, offset)
        min = min or 1
        offset = offset or 0
        return {
          min         = min,
          content_min = min + offset + 21,
          content_max = min + offset + 27,
          max         = min + offset + 28,
          name        = "NAME",
        }
      end,
      m = function (self, min, offset)
        return AD.At.Global(self:x(min, offset))
      end,
    })
  end,
  get_GLOBAL_COMPLETE = function ()
    return TestData({
----5----0----5----0----5---30
      s = [[
---GLOBAL:  SHORT DESCRIPTION
---GLOBAL:  LONG  DESCRIPTION
---@global NAME @ GLOBAL: CMT
---TYPE:    SHORT DESCRIPTION
-- TYPE:    IGNORED DESCR5N 1
---TYPE:    LONG  DESCRIPTION
-- TYPE:    IGNORED DESCR5N 2
---@type TYPE @ TYPE: COMMENT
-- TYPE:    IGNORED COMMENT 1
-- TYPE:    IGNORED COMMENT 2
]],
      m = function (self, min, offset)
        return AD.At.Global({
          description = AD.Description({
            min     = 1,
            max     = 60,
            short   = AD.LineDoc({
              min         = 1,
              content_min = 4,
              content_max = 29,
              max         = 30,
            }),
            long    = {
              AD.LineDoc({
                min         = 31,
                content_min = 34,
                content_max = 59,
                max         = 60,
              }),
            },
            ignores = {},
          }),
          min         = 61,
          content_min = 79,
          content_max = 89,
          max         = 300,
          name        = "NAME",
          type        = AD.At.Type({
            description = AD.Description({
              min     = 91,
              max     = 210,
              short   = AD.LineDoc({
                min         = 91,
                content_min = 94,
                content_max = 119,
                max         = 120,
              }),
              long    = {
                AD.LineDoc({
                  min         = 151,
                  content_min = 154,
                  content_max = 179,
                  max         = 180,
                }),
              },
              ignores = {
                AD.LineComment({
                  min         = 121,
                  content_min = 124,
                  content_max = 149,
                  max         = 150,
                }),
                AD.LineComment({
                  min         = 181,
                  content_min = 184,
                  content_max = 209,
                  max         = 210,
                })
              },
            }),
            min         = 211,
            content_min = 227,
            content_max = 239,
            max         = 240,
            types       = { "TYPE" },
            ignores = {
              AD.LineComment({
                min         = 241,
                content_min = 244,
                content_max = 269,
                max         = 270,
              }),
              AD.LineComment({
                min         = 271,
                content_min = 274,
                content_max = 299,
                max         = 300,
              })
            },
          })
        })
      end,
    })
  end,
  do_test_TD = function (self, Key)
    local KEY = Key:upper()
    local TD = self["get_".. KEY]()
    local t = self.p:match(TD.s)
    expect(t).contains(TD:m())
    if TD.c then
      expect(t:get_comment(TD.s)).is(TD.c)
    end
  end,
  do_test_complete = function (self, Key)
    local Class = AD.At[Key]
    local TYPE = Class.TYPE
    local KEY = Key:upper()
    local TD = self["get_".. KEY]()
    local p = AD.At[Key]:get_capture_p()
    local s = TD.s
    local t = p:match(s)
    expect(t.TYPE).is(TYPE)
    expect(t).contains(TD:m())

    p = AD.At[Key]:get_complete_p()
    t = p:match(s)
    local TD_LINE_DOC = self.get_LINE_DOC()
    s = TD_LINE_DOC.s .. TD.s
    t = p:match(s)
    -- print("t")
    -- pretty_print(t)
    expect(t.TYPE).is(TYPE)
    local LINE_DOC_m = TD_LINE_DOC.m()
    -- print("LINE_DOC_m")
    -- pretty_print(LINE_DOC_m)
    expect(t).contains(TD:m(1 + LINE_DOC_m.max))
    expect(t.description.short).contains(LINE_DOC_m)

    s = TD_LINE_DOC.s .. TD_LINE_DOC.s .. TD.s
    t = p:match(s)
    expect(t.TYPE).is(TYPE)
    expect(t).contains(TD:m(1 + 2 * LINE_DOC_m.max))
    expect(t.description.short).contains(LINE_DOC_m)
    
    -- pretty_print(t.description.long[1])
    -- pretty_print(self:get_LINE_DOC_m(LINE_DOC_m.max + 1))
    
    expect(t.description.long[1]).contains(TD_LINE_DOC.m(LINE_DOC_m.max + 1))
    
    s = TD_LINE_DOC.s .. TD_LINE_DOC.s .. TD_LINE_DOC.s .. TD.s
    t = p:match(s)
    expect(t.TYPE).is(TYPE)
    expect(t).contains(TD:m(1 + 3 * LINE_DOC_m.max))
    expect(t.description.short).contains(LINE_DOC_m)
    expect(t.description.long[2]).contains(TD_LINE_DOC.m(1 + 2 * LINE_DOC_m.max))

    local TD_LONG_DOC = self.get_LONG_DOC()
    s = TD_LINE_DOC.s .. TD_LONG_DOC.s .. TD.s
    t = p:match(s)
    expect(t.TYPE).is(TYPE)
    local LONG_DOC_m = TD_LONG_DOC.m(LINE_DOC_m.max)

    expect(t).contains(TD:m(1 + 1 + LONG_DOC_m.max))
    expect(t.description.short).contains(LINE_DOC_m)
    expect(t.description.long[1]).contains(TD_LONG_DOC.m(LINE_DOC_m.max + 1))
  end,
}
Test.__index = Test
setmetatable(Test, {
  __call = function (self, d)
    return setmetatable(d or {}, self)
  end
})

function Test:add_strip(k)
  LU.STRIP_EXTRA_ENTRIES_IN_STACK_TRACE =
    LU.STRIP_EXTRA_ENTRIES_IN_STACK_TRACE + k
end

function Test:p_test(target, expected, where)
  self:add_strip(1)
  expect(self.p:match(target, where)).is(expected)
  self:add_strip(-1)
end

--ANCHOR: DB

local DB = {}

---comment
---@param category string @ "line_doc", "line_comment", "param"...
---@vararg string|nil @ when nil, remaining arguments are ignored
local function fill_DB(category, ...)
  local storage = DB[category]
  if not storage then
    storage = {}
    DB[category] = storage
  end
  local function wrapper(a)
    return function (self)
      return a
    end
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
      t.x = type(p) == "function" and p or wrapper(p)
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

fill_DB(
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

fill_DB(
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

fill_DB(
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

fill_DB(
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

fill_DB(
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

fill_DB(
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
    min         = 1,
    content_min = 4,
    content_max = 9,
    max         = 10,
  },
  11,
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
  21
)

fill_DB(
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

fill_DB(
  "core_author",
  -----5----0----5----0----5----0----5----0----5
  "1hat do you want of 22  ",
  {
    value = "1hat do you want of 22",
  }
)

fill_DB(
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

fill_DB(
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

fill_DB(
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

fill_DB(
  "core_see",
  -----5----0----5----0----5----0----5
  "9hat do you want of 22  ",
  {
    value = "9hat do you want of 22",
  }
)

fill_DB(
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

fill_DB(
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

fill_DB(
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

fill_DB(
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

fill_DB(
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

fill_DB(
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

fill_DB(
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

fill_DB(
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

fill_DB(
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

fill_DB(
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

fill_DB(
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

fill_DB(
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

fill_DB(
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

fill_DB(
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

fill_DB(
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

fill_DB(
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

fill_DB(
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

fill_DB(
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

fill_DB(
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

fill_DB(
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

fill_DB(
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

fill_DB(
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

fill_DB(
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

fill_DB(
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

fill_DB(
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

fill_DB(
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

fill_DB(
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

fill_DB(
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

fill_DB(
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

fill_DB(
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
  "fun():foo, bar", 15
)

fill_DB(
  "named_types",
  "foo", { types = { "foo" } },
  "foo|chi", { types = { "foo", "chi" } },
  "foo|chi|mee", { types = { "foo", "chi" , "mee" } },
  "foo | chi | mee", { types = { "foo", "chi" , "mee" } }
)

fill_DB(
  "named_optional",
  "", { optional = false },
  "?", { optional = true },
  "  ?  ", { optional = true }
)

fill_DB(
  "at_match",
  "", nil, { name = "NAME" },
  "---@NAME", 9, { name = "NAME" },
  "---@NAMEX", nil, { name = "NAME" }
)

fill_DB(
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

return {
  Test = Test,
  DB = DB,
}