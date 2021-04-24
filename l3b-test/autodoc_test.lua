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

local expect  = require("l3b-test/expect").expect
local LU      = require("l3b-test/luaunit")

local AD = require("l3b-autodoc")

local DB = require("l3b-test/autodoc_db")

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
    return setmetatable(d or {}, self)
  end,
})

-- All the tests are objects with next `Test` as metatable
local Test = {
  verbose = 0,
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

---comment
---@param base table @ for example DB.BASE
---@param contains boolean @ expect `contains` when true, `equals` otherwise.
function Test:do_test_base(base, contains)
  local t = self.Class()
  if contains then
    expect(t).contains(self.Class(base))
  else
    expect(t).equals(self.Class(base))
  end
end

function Test:do_setup(Class)
  self.Class = Class
  self.p = Class:get_capture_p()
end

---comment
---@param key string @ Database key
---@param contains boolean @ expect `contains` when true, `equals` otherwise.
function Test:do_test_DB_x(key, contains)
  if self.verbose > 0 then
    print("TEST", key)
  end
  for _, TD in ipairs(DB[key]) do
    if self.verbose > 1 then
      print("#" .. _, TD.s)
    end
    local actual = self.p:match(TD.s)
    local expected = TD:x() -- `x` here
    expected.foo = 421
    expected = TD:x()
    expect(expected.foo).NOT(421)
    if type(expected) == "table" then
      expected = self.Class(expected)
    end
    if self.verbose > 2 then
      print("actual:")
      _G.pretty_print(actual)
      print("expected:")
      _G.pretty_print(expected)
    end
    if contains then
      expect(actual).contains(expected)
    else
      expect(actual).equals(expected)
    end
  end
end

---comment
---@param key string @ Database key
---@param contains boolean @ expect `contains` when true, `equals` otherwise.
function Test:do_test_DB_m(key, contains)
  for _, TD in ipairs(DB[key]) do
    local actual = self.p:match(TD.s)
    local expected = TD:m() -- `m` here
    if type(expected) == "table" then
      expected = self.Class(expected)
    end
    if contains then
      expect(actual).contains(expected)
    else
      expect(actual).equals(expected)
    end
  end
end

function Test:add_strip(k)
  LU.STRIP_EXTRA_ENTRIES_IN_STACK_TRACE =
    LU.STRIP_EXTRA_ENTRIES_IN_STACK_TRACE + k
end

function Test:p_test(target, expected, where)
  self:add_strip(1)
  expect(self.p:match(target, where)).is(expected)
  self:add_strip(-1)
end

return Test
