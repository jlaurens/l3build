#!/usr/bin/env texlua
local write   = io.write

function _G.pretty_print(tt, indent, done)
  done = done or {}
  indent = indent or 0
  if type(tt) == "table" then
    local w = 0
    for k, _ in pairs(tt) do
      local l = #tostring(k)
      if l > w then
        w = l
      end
    end
    for k, v in pairs(tt) do
      local filler = (" "):rep(w - #tostring(k))
      write((" "):rep(indent)) -- indent it
      if type(v) == "table" and not done[v] then
        done[v] = true
        if next(v) then
          write(('["%s"]%s = {\n'):format(tostring(k), filler))
          _G.pretty_print(v, indent + w + 7, done)
          write((" "):rep( indent + w + 5)) -- indent it
          write("}\n")
        else
          write(('["%s"]%s = {}\n'):format(tostring(k), filler))
        end
      elseif type(v) == "string" then
        write(('["%s"]%s = "%s"\n'):format(
            tostring(k), filler, tostring(v)))
      else
        write(('["%s"]%s = %s\n'):format(
            tostring(k), filler, tostring(v)))
      end
    end
  else
    write(tostring(tt) .."\n")
  end
end

local __ = setmetatable({
  during_unit_testing = true,
}, {
  __index = _G
})

local AD = loadfile(
  "../l3build-autodoc.lua",
  "t",
  __
)()

local Xpct, LU  = dofile("./l3b-expect.lua")

local expect = Xpct.expect

local re      = require("re")

local lpeg    = require("lpeg")
local P       = lpeg.P
local B       = lpeg.B
local Cg      = lpeg.Cg
local Ct      = lpeg.Ct
local Cc      = lpeg.Cc
local Cb      = lpeg.Cb
local V       = lpeg.V
local Cp      = lpeg.Cp
local Cmt     = lpeg.Cmt

---@class TestData
---@field public s string   @ target
---@field public m AD.Info  @ match result
---@field public c string   @ comment

---@type TestData
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
      m = function (min)
        min = min or 1
        return AD.LineDoc({
          min         = min,
          content_min = min + 4,
          content_max = min + 25,
          max         = min + 29,
        })
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
      m = function (min) -- get the FIELD match
        min = min or 1
        return AD.LongDoc({
          min         = min,
          content_min = min + 7,
          content_max = min + 59,
          max         = min + 79,
        })
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
      m = function (min, offset) -- get the FIELD match
        min = min or 1
        offset = offset or 0
        return AD.At.Field({
          min         = min,
          content_min = min + offset + 30,
          content_max = min + offset + 38,
          max         = min + offset + 39,
          visibility  = "public",
          name        = "NAME",
          types       = { "TYPE" },
        })
      end,
    })
  end,
  get_SEE = function()
    return TestData({
----5----0----5----0----5----0----5----0----5
      s = [[
--- @see  reference
]],
      m = function (min, offset)
        min = min or 1
        offset = offset or 0
        return AD.At.See({
          min         = min,
          content_min = min + offset + 10,
          content_max = min + offset + 18,
          max         = min + offset + 19,
        })
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
      m = function (min, offset)
        min = min or 1
        offset = offset or 0
        return AD.At.Class({
          min         = min,
          content_min = min + offset + 33,
          content_max = min + offset + 39,
          max         = min + offset + 40,
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
      m = function (min, offset)
        min = min or 1
        offset = offset or 0
        return AD.At.Type({
          min         = min,
          content_min = min + offset + 30,
          content_max = min + offset + 38,
          max         = min + offset + 39,
        })
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
      m = function (min, offset)
        min = min or 1
        offset = offset or 0
        return AD.At.Module({
          min         = min,
          content_min = min + offset + 22,
          content_max = min + offset + 28,
          max         = min + offset + 29,
        })
      end,
    })
  end,
  get_ALIAS = function ()
    return TestData({
----5----0----5----0----5----0----5----0----5---|0----5
      s = [=====[
---   @alias  NAME TYPE@ SOME   COMMENT         
]=====],
      c = "SOME   COMMENT",
      m = function (min, offset)
        min = min or 1
        offset = offset or 0
        return AD.At.Alias({
          min         = min,
          content_min = min + offset + 25,
          content_max = min + offset + 38,
          max         = min + offset + 48,
        })
      end,
    })
  end,
  get_PARAM = function ()
    return TestData({
----5----0----5----0----5----0----5----0----5---|0----5
      s = [[
---   @param NAME TYPE  |  OTHER@ COM    MENT
]],
      c = "COM    MENT",
      m = function (min, offset)
        min = min or 1
        offset = offset or 0
        return AD.At.Param({
          min         = min,
          content_min = min + offset + 34,
          content_max = min + offset + 44,
          max         = min + offset + 45,
          name        = "NAME",
          types       = { "TYPE", "OTHER", },
        })
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
      m = function (min, offset)
        min = min or 1
        offset = offset or 0
        return AD.At.Generic({
          min         = min,
          content_min = min + offset + 35,
          content_max = min + offset + 45,
          max         = min + offset + 46,
          type_1      = "T1",
          parent_1    = "P1",
          type_2      = "T2",
          parent_2    = "P2",
        })
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
      m = function (min, offset)
        min = min or 1
        offset = offset or 0
        return AD.At.Vararg({
          min         = min,
          content_min = min + offset + 25,
          content_max = min + offset + 28,
          max         = min + offset + 29,
          types       = { "TYPE_", "TYPE" },
        })
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
      m = function (min, offset)
        min = min or 1
        offset = offset or 0
        return AD.At.Return({
          min         = min,
          content_min = min + offset + 32,
          content_max = min + offset + 38,
          max         = min + offset + 39,
          types       = { "TYPE", "OTHER" },
        })
      end,
    })
  end,
  get_FUNCTION = function ()
    return TestData({
----5----0----5----0----5----0----5---|0----5----0
      s = [[
---  @function  NAME  @ COMMENT        
]],
      c = "COMMENT",
      m = function (min, offset)
        min = min or 1
        offset = offset or 0
        return AD.At.Function({
          min         = min,
          content_min = min + offset + 24,
          content_max = min + offset + 30,
          max         = min + offset + 39,
          name        = "NAME",
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
      m = function (min, offset)
        min = min or 1
        offset = offset or 0
        return AD.At.Global({
          min         = min,
          content_min = min + offset + 21,
          content_max = min + offset + 27,
          max         = min + offset + 28,
          name        = "NAME",
        })
      end,
    })
  end,
  do_test_TD = function (self, Key)
    local KEY = Key:upper()
    local TD = self["get_".. KEY]()
    local t = self.p:match(TD.s)
    expect(t).contains(TD.m())
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
    expect(t).contains(TD.m())

    p = AD.At[Key]:get_complete_p()
    t = p:match(s)
    local TD_LINE_DOC = self.get_LINE_DOC()
    s = TD_LINE_DOC.s .. TD.s
    t = p:match(s)
    -- print("t")
    -- _G.pretty_print(t)
    expect(t.TYPE).is(TYPE)
    local LINE_DOC_m = TD_LINE_DOC.m()
    -- print("LINE_DOC_m")
    -- _G.pretty_print(LINE_DOC_m)
    expect(t).contains(TD.m(1 + LINE_DOC_m.max))
    expect(t.description.short).contains(LINE_DOC_m)

    s = TD_LINE_DOC.s .. TD_LINE_DOC.s .. TD.s
    t = p:match(s)
    expect(t.TYPE).is(TYPE)
    expect(t).contains(TD.m(1 + 2 * LINE_DOC_m.max))
    expect(t.description.short).contains(LINE_DOC_m)
    
    -- _G.pretty_print(t.description.long[1])
    -- _G.pretty_print(self:get_LINE_DOC_m(LINE_DOC_m.max + 1))
    
    expect(t.description.long[1]).contains(TD_LINE_DOC.m(LINE_DOC_m.max + 1))
    
    s = TD_LINE_DOC.s .. TD_LINE_DOC.s .. TD_LINE_DOC.s .. TD.s
    t = p:match(s)
    expect(t.TYPE).is(TYPE)
    expect(t).contains(TD.m(1 + 3 * LINE_DOC_m.max))
    expect(t.description.short).contains(LINE_DOC_m)
    expect(t.description.long[2]).contains(TD_LINE_DOC.m(1 + 2 * LINE_DOC_m.max))

    local TD_LONG_DOC = self.get_LONG_DOC()
    s = TD_LINE_DOC.s .. TD_LONG_DOC.s .. TD.s
    t = p:match(s)
    expect(t.TYPE).is(TYPE)
    local LONG_DOC_m = TD_LONG_DOC.m(LINE_DOC_m.max)

    expect(t).contains(TD.m(1 + 1 + LONG_DOC_m.max))
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

_G.test_POC = Test({
  test_Ct = function ()
    local p_one = Cg(P(1), "one")
    local p_two = Cg(P(1), "two")
    local t = Ct(p_one*p_two):match("12")
    expect(t.one).is("1")
    expect(t.two).is("2")
  end,
  test_min_max = function(self)
    -- print("POC min <- max + 1")
    local p1 =
        Cg(Cc(421), "min")
      * Cg(Cc(123), "max")
    local m = Ct(p1):match("")
    expect(m.min).is(421)
    expect(m.max).is(123)
    local p2 = p1 * Cg(
      Cb("min") / function (min) return min + 1 end,
      "max"
    )
    m = Ct(p2):match("")
    expect(m.min).is(421)
    expect(m.max).is(422)
  end,
  test_table = function (self)
    local p = P({
      "type",
      type = V("table") + P("abc"),
      table =
        P("table")   -- table<foo,bar>
      * P( __.get_spaced_p("<")
        * V("type")
        * __.comma_p
        * V("type")
        * __.get_spaced_p(">")
      )^-1,
    })
    expect((p * Cp()):match("table<abc,abc>")).is(15)
  end
})

_G.test_Info = function ()
  expect(AD.Info).is.NOT(nil)
  expect(AD.Info.__Class).is(AD.Info)
end

_G.test_white_p = Test({
  setup = function (self)
    self.p = __.white_p
  end,
  test = function (self)
    expect(self.p).is.NOT(nil)
    self:p_test("",     nil)
    self:p_test(" ",    2)
    self:p_test("\t",   2)
    self:p_test("\n",   nil)
    self:p_test("a",    nil)
    self:p_test("X",    nil,  2)
    self:p_test("X ",   3,    2)
    self:p_test("X\t",  3,    2)
    self:p_test("X\n",  nil,  2)
    self:p_test("Xa",   nil,  2)
  end
})

_G.test_black_p = Test({
  setup = function (self)
    self.p = __.black_p
  end,
  test = function (self)
    expect(self.p).is.NOT(nil)
    self:p_test("", nil)
    self:p_test(" ", nil)
    self:p_test("\t", nil)
    self:p_test("\n", nil)
    self:p_test("a", 2)
  end
})

_G.test_eol_p = Test({
  setup = function (self)
    self.p = __.eol_p
  end,
  test = function (self)
    expect(self.p).is.NOT(nil)
    self:p_test("",      1)
    self:p_test("\n",    2)
    self:p_test(" \n  ", 1)
    self:p_test("    ",  2, 2)
    self:p_test(" \n  ", 3, 2)
    self:p_test("\n   ", 2)  
  end
})

_G.test_variable_p = Test({
  setup = function (self)
    self.p = __.variable_p
  end,
  test = function (self)
    expect(self.p).is.NOT(nil)
    self:p_test(" ", nil)
    self:p_test("abc", 4)
    self:p_test("2bc", nil)
  end
})

_G.test_identifier_p = Test({
  setup = function (self)
    self.p = __.identifier_p
  end,
  test = function (self)
    expect(self.p).is.NOT(nil)
    self:p_test(" ", nil)
    self:p_test("abc", 4)
    self:p_test("2bc", nil)
    self:p_test("abc.", 4)
    self:p_test("abc._", 6)
  end
})

_G.test_special_begin_p = Test({
  setup = function (self)
    self.p = __.special_begin_p
  end,
  test = function (self)
    expect(self.p).is.NOT(nil)
    self:p_test("-", nil)
    self:p_test("--", nil)
    self:p_test("---", 4)
    self:p_test("----", nil)
    self:p_test("  -", nil)
    self:p_test("  --", nil)
    self:p_test("  ---", 6)
    self:p_test("  ---  ", 8)
  end
})

_G.test_colon_p = Test({
  setup = function (self)
    self.p = __.colon_p
  end,
  test = function (self)
    expect(self.p).is.NOT(nil)
    self:p_test("abc", nil)
    self:p_test(" : abc", 4)
  end
})

_G.test_comma_p = Test({
  setup = function (self)
    self.p = __.comma_p
  end,
  test = function (self)
    expect(self.p).is.NOT(nil)
  end
})

_G.test_lua_type_p = Test({
  setup = function (self)
    self.p = __.lua_type_p
  end,
  test = function (self)
    expect(self.p).is.NOT(nil)
    self:p_test("abc", 4)
    self:p_test("abc<", 4)
    self:p_test("foo", 4)
    self:p_test("bar", 4)
    self:p_test("bar[]", 6)
    --0----5----0----5----0----5----0----5----0----5----
    self:p_test("table<k, v>", 12)
    self:p_test("table<k, v>[]", 14)
    self:p_test("fun", 4)
    self:p_test("fun()", 6)
    self:p_test("fun(... : string[])", 20)
    self:p_test("fun(... : bar)", 15)
    self:p_test("fun(foo : bar)", 15)
    self:p_test("fun(foo : bar, ...: bar)", 25)
    self:p_test("fun(foo : bar, foo: bar, ...: bar)", 35)
    self:p_test("fun():foo", 10)
    self:p_test("fun():foo, bar", 15)
  end
})

_G.test_named_types_p = Test({
  setup = function (self)
    self.p = Ct(__.named_types_p)
  end,
  test = function (self)
    expect(self.p).is.NOT(nil)
    expect(self.p:match("foo").types)
      .equals({ "foo" })
    expect(self.p:match("foo|chi").types)
      .equals({ "foo", "chi" })
    expect(self.p:match("foo|chi|mee").types)
      .equals({ "foo", "chi" , "mee" })
    expect(self.p:match("foo | chi | mee").types)
      .equals({ "foo", "chi" , "mee" })
  end,
})

_G.test_comment_p = Test({
  setup = function (self)
    self.p = Ct(__.capture_comment_p)
  end,
  test = function (self)
    local t, s
    s = ""
    t = self.p:match(s)
    expect(t).is.NOT(nil)
    s = "@ FOO \n BAR"
    t = self.p:match(s)
    expect(t).contains({
      content_min = 3,
      content_max = 5,
    })
  end
})

_G.test_comment_p_2 = Test({
  setup = function (self)
    self.p = Ct(
        __.chunk_init_p
      * __.capture_comment_p
      * __.chunk_end_p
  )
  end,
  test = function (self)
    local t, s
    s = ""
    t = self.p:match(s)
    expect(t).is.NOT(nil)
    s = "@ FOO \n BAR"
    t = self.p:match(s)
    expect(t).contains({
      min = 1,
      max = 7,
      content_min = 3,
      content_max = 5,
    })
  end
})

-- unused yet
function Test:ad_test(target, expected, content, index)
  self:add_strip(1)
  local m = self.p:match(target, index)
  expect(m).contains(expected)
  expect(m:get_content(target)).is(content)
  self:add_strip(-1)
end

_G.test_ShortLiteral = Test({
  test_base = function ()
    local t = AD.ShortLiteral()
    expect(t).contains(AD.ShortLiteral({
      min         = 1,
      content_min = 1,
      content_max = 0,
      max         = 0,
    }))
  end,
  setup = function (self)
    self.p = AD.ShortLiteral:get_capture_p()
  end,
  test = function (self)
    local s, t
    expect(self.p).is.NOT(nil)
    s = '"234"  \n  '
    ---@type AD.ShortLiteral
    t = self.p:match(s)
    expect(t).contains(AD.ShortLiteral({
      min = 1,
      content_min = 2,
      content_max = 4,
      max = 8,
    }))

    s = "'234'  \n  "
    t = self.p:match(s)
    expect(t).contains(AD.ShortLiteral({
      min         = 1,
      content_min = 2,
      content_max = 4,
      max         = 8,
    }))
  end
})

_G.test_LongLiteral = Test({
  test_base = function ()
    local t = AD.LongLiteral()
    expect(t).contains(AD.LongLiteral({
      min         = 1,
      content_min = 1,
      content_max = 0,
      max         = 0,
      level       = 0,
    }))
  end,
  setup = function (self)
    self.p = AD.LongLiteral:get_capture_p()
  end,
  test = function (self)
    local s, t
    s = '[[345]]  \n  '
    t = self.p:match(s)
    expect(t).contains(AD.LongLiteral({
      min         = 1,
      content_min = 3,
      content_max = 5,
      max         = 10,
      level       = 0,
    }))

    t = self.p:match('[===[678]===]  \n  ')
    expect(t).contains(AD.LongLiteral({
      min         = 1,
      content_min = 6,
      content_max = 8,
      max         = 16,
      level       = 3,
    }))
  end
})

_G.test_LineComment = Test({
  test_base = function ()
    local t = AD.LineComment()
    expect(t).contains(AD.LineComment({
      min         = 1,
      content_min = 1,
      content_max = 0,
      max         = 0,
    }))
  end,
  setup = function (self)
    self.p = AD.LineComment:get_capture_p()
  end,
  test = function (self)
    local t
    ---@type AD.LineComment
    t = self.p:match('-  \n  ')
    expect(t).is(nil)
    t = self.p:match('---  \n  ')
    expect(t).is(nil)
    t = self.p:match('---  \n  ', 2)
    expect(t).is(nil)

    t = self.p:match('--  ')
    expect(t).contains(AD.LineComment({
      min         = 1,
      content_min = 5,
      content_max = 4,
      max         = 4,
    }))

    t = self.p:match('--  \n  ')
    expect(t).contains(AD.LineComment({
      min         = 1,
      content_min = 5,
      content_max = 4,
      max         = 5,
    }))

    t = self.p:match('----------')
    expect(t).contains(AD.LineComment({
      min         = 1,
      content_min = 11,
      content_max = 10,
      max         = 10,
    }))

    t = self.p:match('-- 456 89A \n  ')
    expect(t).contains(AD.LineComment({
      min         = 1,
      content_min = 4,
      content_max = 10,
      max         = 12,
    }))
  end
})

_G.test_LongComment = Test({
  test_base = function ()
    local t = AD.LongComment()
    expect(t).contains(AD.LongComment({
      min         = 1,
      content_min = 1,
      content_max = 0,
      max         = 0,
      level       = 0,
    }))
  end,
  setup = function (self)
    self.p = AD.LongComment:get_capture_p()
  end,
  test = function (self)
    local s, t
    ---@type AD.LongComment
    t = self.p:match('--  \n  ')
    expect(t).is(nil)

    t = self.p:match('--[[56 89A]]')
    expect(t).contains(AD.LongComment({
      min         = 1,
      content_min = 5,
      content_max = 10,
      max         = 12,
      level       = 0,
    }))

    t = self.p:match('--[[\n6 89A]]')
    expect(t).contains(AD.LongComment({
      min         = 1,
      content_min = 6,
      content_max = 10,
      max         = 12,
      level       = 0,
    }))

    t = self.p:match('--[[\n  8\nA  ]]')
    expect(t).contains(AD.LongComment({
      min         = 1,
      content_min = 6,
      content_max = 10,
      max         = 14,
      level       = 0,
    }))

    t = self.p:match('--[==[78]=] \n ]==] ')
    expect(t).contains(AD.LongComment({
      min         = 1,
      content_min = 7,
      content_max = 13,
      max         = 19,
      level       = 2,
    }))
  end
})

_G.test_LineDoc = Test({
  test_base = function ()
    local t = AD.LineDoc()
    expect(t).contains(AD.LineDoc({
      min         = 1,
      content_min = 1,
      content_max = 0,
      max         = 0,
    }))
  end,
  setup = function (self)
    self.p = AD.LineDoc:get_capture_p()
  end,
  test = function (self)
    local s, t
    t = self.p:match('-- ')
    expect(t).is(nil)
    t = self.p:match('---- ')
    expect(t).is(nil)
    t = self.p:match('---- ', 1)
    expect(t).is(nil)

    t = self.p:match('---')
    expect(t).contains(AD.LineDoc({
      min         = 1,
      content_min = 4,
      content_max = 3,
      max         = 3,
    }))

    t = self.p:match('---456789A')
    expect(t).contains(AD.LineDoc({
      min         = 1,
      content_min = 4,
      content_max = 10,
      max         = 10,
    }))

    t = self.p:match('--- 56 89 ')
    expect(t).contains(AD.LineDoc({
      min         = 1,
      content_min = 5,
      content_max = 9,
      max         = 10,
    }))

    t = self.p:match('--- 56 89 \n')
    expect(t).contains(AD.LineDoc({
      min         = 1,
      content_min = 5,
      content_max = 9,
      max         = 11,
    }))

    s = [=====[
---456789
---456789
---456789
]=====]
    expect(self.p:match(s,  1).max).is(10)
    expect(self.p:match(s, 11).max).is(20)
    expect(self.p:match(s, 21).max).is(30)
    expect((self.p^2):match(s, 1)).is.NOT(nil)
    expect((self.p^2):match(s, 11)).is.NOT(nil)

    local TD = self.get_LINE_DOC()
    t = self.p:match(TD.s)
    expect(t).contains(TD.m())
  end
})

_G.test_LongDoc = Test({
  test_base = function ()
    local t = AD.LongDoc()
    expect(t).contains(AD.LongDoc({
      min         = 1,
      content_min = 1,
      content_max = 0,
      max         = 0,
    }))
  end,
  setup = function (self)
    self.p = AD.LongDoc:get_capture_p()
  end,
  test = function (self)
    local s, t
    t = self.p:match('-- ')
    expect(t).is(nil)
    t = self.p:match('--- ')
    expect(t).is(nil)
    t = self.p:match('--- ', 1)
    expect(t).is(nil)

    t = self.p:match('--[===[]===]')
    expect(t).contains(AD.LongDoc({
      min         = 1,
      content_min = 8,
      content_max = 7,
      max         = 12,
    }))

    t = self.p:match('--[===[89AB]===]')
    expect(t).contains(AD.LongDoc({
      min         = 1,
      content_min = 8,
      content_max = 11,
      max         = 16,
    }))

    t = self.p:match('--[===[09 B]===]')
    expect(t).contains(AD.LongDoc({
      min         = 1,
      content_min = 8,
      content_max = 11,
      max         = 16,
    }))

    t = self.p:match('--[===[09 B]===]\n')
    expect(t).contains(AD.LongDoc({
      min         = 1,
      content_min = 8,
      content_max = 11,
      max         = 17,
    }))

    local TD = self.get_LONG_DOC()
    t = self.p:match(TD.s)
    expect(t).contains(TD.m())
  end
})

_G.test_Description = Test({
  test_base = function ()
    local t = AD.Description()
    expect(t.__Class).is(AD.Description)
  end,
  setup = function (self)
    self.p = AD.Description:get_capture_p()
  end,
  test = function (self)
    local s, t
    t = self.p:match("--")
    expect(t).is(nil)

    expect(self.p:match("---\n--[===[]===]")).is.NOT(nil)

    ---@type AD.Description
    t = self.p:match("---")
    expect(t).contains(AD.Description({
      min   = 1,
      max   = 3,
      long  = {},
      short = AD.LineDoc({
        min   = 1,
        max   = 3,
      }),
    }))

    t = self.p:match("---\n")
    expect(t).contains(AD.Description({
      min   = 1,
      max   = 4,
      long  = {},
    }))

    t = self.p:match("---\ns")
    expect(t).contains(AD.Description({
      min   = 1,
      max   = 4,
      long  = {},
    }))


    t = self.p:match("---\n\n")
    expect(t).contains(AD.Description({
      min   = 1,
      max   = 4,
      long  = {},
    }))

    t = self.p:match("-- \n---")
    expect(t).is(nil)

    s = "---\n---"
    t = self.p:match(s)
    expect(t).contains(AD.Description({
      min   = 1,
      max   = 7,
      short = AD.LineDoc({
        min         = 1,
        content_min = 4,
        content_max = 3,
        max         = 4,
      }),
      long  = { AD.LineDoc({
        min         = 5,
        content_min = 8,
        content_max = 7,
        max         = 7,
      }) },
    }))

----5----0----5----0----5----0----5----0----5
    s = [=====[
---
--[[]]
]=====]
    t = self.p:match(s)
    expect(t).contains(AD.Description({
      min   = 1,
      max   = 11,
      short = AD.LineDoc({
        min         = 1,
        content_min = 4,
        content_max = 3,
        max         = 4,
      }),
      long  = {},
    }))

----5----0----5----0----5----0----5----0----5
s = [=====[
---
--[===[]===]
]=====]
    t = self.p:match(s)
    expect(t).contains(AD.Description({
      min   = 1,
      max   = 17,
      short = AD.LineDoc({
        min         = 1,
        content_min = 4,
        content_max = 3,
        max         = 4,
      }),
      long  = { AD.LongDoc({
        min         = 5,
        content_min = 12,
        content_max = 11,
        max         = 17,
      }) }
    }))

----5----0----5----0----5----0----5----0----5
s = [=====[
---
--[===[]===]
--
---
s   s
]=====]
    t = self.p:match(s)
    expect(t).contains(AD.Description({
      min   = 1,
      max   = 24,
      short = AD.LineDoc({
        min   = 1,
        content_min = 4,
        content_max = 3,
        max   = 4,
      }),
      long  = {
        AD.LongDoc({
          min   = 5,
          content_min = 12,
          content_max = 11,
          max   = 17,
        }),
        AD.LineDoc({
          min   = 21,
          content_min = 24,
          content_max = 23,
          max   = 24,
        })
      },
    }))
  end
})

_G.test_Field = Test({
  test_base = function ()
    local t = AD.At.Field()
    expect(t).contains(AD.At.Field({
      min         = 1,
      content_min = 1,
      content_max = 0,
      max         = 0,
    }))
  end,
  setup = function (self)
    self.p = AD.At.Field:get_capture_p()
  end,
  test = function (self)
    local s, t
    expect(
      function ()
        self.p:match("--- @field public foo")
      end
    ).error()

    expect(
      function ()
        self.p:match("--- @field public foo \n bar")
      end
    ).error()

    --   ----5----0----5----0----5----0
    s = "--- @field public f21 b25"
    ---@type AD.At.Field
    t = self.p:match(s)
    expect(t).contains(AD.At.Field({
      min         = 1,
      content_min = 26,
      content_max = 25,
      max         = 25,
      visibility  = "public",
      name        = "f21",
      types       = { "b25" },
    }))

    --   ----5----0----5----0----5----0----5
    s = "--- @field private f22 b26\n   "
    ---@type AD.At.Field
    t = self.p:match(s)
    expect(t).contains( AD.At.Field({
      min         = 1,
      content_min = 27,
      content_max = 26,
      max         = 27,
      visibility  = "private",
      name        = "f22",
      types       = { "b26" },
    }) )

    --   ----5----0----5----0----5----0----5----0----5
    s = "--- @field private f22 b26 @ commentai40   "
    t = self.p:match(s)
    expect(t).contains( AD.At.Field({
      min         = 1,
      content_min = 30,
      content_max = 40,
      max         = 43,
      visibility  = "private",
      name        = "f22",
      types       = { "b26" },
    }) )

    --   ----5----0----5----0----5----0----5----0----5
    s = "--- @field private f22 b26\n   "
    t = self.p:match(s)
    expect(t).contains( AD.At.Field({
      min         = 1,
      content_min = 27,
      content_max = 26,
      max         = 27,
      visibility  = "private",
      name        = "f22",
      types       = { "b26" },
    }) )

    --   ----5----0----5----0----5----0----5----0----5
    s = "123456789--- @field private f22 b26\n   "
    t = self.p:match(s, 10)
    expect(t).contains( AD.At.Field({
      min         = 10,
      content_min = 36,
      content_max = 35,
      max         = 36,
      visibility  = "private",
      name        = "f22",
      types       = { "b26" },
    }) )
  end,
  test_complete = function (self)
    self:do_test_complete("Field")
  end
})

_G.test_See = Test({
  test_base = function ()
    local t = AD.At.See()
    expect(t).contains( AD.At.See({
      min         = 1,
      content_min = 1,
      content_max = 0,
      max         = 0,
    }) )
  end,
  setup = function (self)
    self.p = AD.At.See:get_capture_p()
  end,
  test = function (self)
    local s, t
    --   ----5----0----5----0----5----0----5----0----5
    s = "---@see 9hat do you want of 30  "
    ---@type AD.At.See
    t = self.p:match(s)
    expect(t).contains( AD.At.See({
      min         = 1,
      content_min = 9,
      content_max = 30,
      max         = 32,
    }) )
    expect(t:get_content(s)).is("9hat do you want of 30")
  end,
  test_complete = function (self)
    self:do_test_complete("See")
  end
})

-- @class MY_TYPE[:PARENT_TYPE] [@comment]
_G.test_Class = Test({
  test_base = function (self)
    local t = AD.At.Class()
    expect(t).contains( AD.At.Class({
      min         = 1,
      content_min = 1,
      content_max = 0,
      max         = 0,
    }) )
  end,
  setup = function (self)
    self.p = AD.At.Class:get_capture_p()
  end,
  test = function (self)
    local s, t
    --   ----5----0----5----0----5----0----5----0----5
    s = "---@class MY_TY17"
    ---@type AD.At.Class
    t = self.p:match(s)

    expect(t.__Class).is(AD.At.Class)
    expect(t).contains( AD.At.Class({
      min         = 1,
      content_min = 18,
      content_max = 17,
      max         = 17,
    }) )
    expect(t.parent).is(nil)

    --   ----5----0----5----0----5----0----5----0----5
    s = "---@class AY_TYPE: PARENT_TY30"
    ---@type AD.At.Class
    t = self.p:match(s)
    expect(t).contains( AD.At.Class({
      min         = 1,
      content_min = 31,
      content_max = 30,
      max         = 30,
      name        = "AY_TYPE",
      parent      = "PARENT_TY30",
    }) )

    local TD = self.get_CLASS()
    ---@type AD.At.Class
    t = self.p:match(TD.s)
    expect(t).contains(TD.m())
    expect(t:get_comment(TD.s)).is(TD.c)
  end,
  test_complete = function (self)
    self:do_test_complete("Class")

    local p = AD.At.Class:get_complete_p()
    local TD_CLASS = self:get_CLASS()
    local TD_FIELD = self:get_FIELD()
    local s = TD_CLASS.s .. TD_FIELD.s
    local t = p:match(s)
    local CLASS_m = TD_CLASS.m()
    local FIELD_m = TD_FIELD.m(1 + CLASS_m.max)
    CLASS_m.max = FIELD_m.max
    CLASS_m.fields = { FIELD_m }
  end,

})

_G.test_Type = Test({
  test_base = function ()
    local t = AD.At.Type()
    expect(t).contains( AD.At.Type({
      min         = 1,
      content_min = 1,
      content_max = 0,
      max         = 0,
    }) )
  end,
  setup = function (self)
    self.p = AD.At.Type:get_capture_p()
  end,
  test = function (self)
    local s, t
----5----0----5----0----5----0----5----0
    s = [=====[
---@type MY_TYPE]=====]
    ---@type AD.At.Type
    t = self.p:match(s)
    expect(t).contains( AD.At.Type({
      min = 1,
      content_min = 17,
      content_max = 16,
      max = 16,
      types = { "MY_TYPE" },
    }) )

----5----0----5----0----5----0----5----0
    s = [=====[
---@type MY_TYPE|OTHER_TYPE]=====]
    ---@type AD.At.Type
    t = self.p:match(s)
    expect(t).contains( AD.At.Type({
      min = 1,
      content_min = 28,
      content_max = 27,
      max = 27,
      types = { "MY_TYPE", "OTHER_TYPE" },
    }) )

----5----0----5----0----5----0----5----0
    s = [=====[
---@type MY_TYPE|OTHER_TYPE @ COMMENT ]=====]
    ---@type AD.At.Type
    t = self.p:match(s)
    expect(t).contains( AD.At.Type({
      min = 1,
      content_min = 31,
      content_max = 37,
      max = 38,
      types = { "MY_TYPE", "OTHER_TYPE" },
    }) )
    expect(t:get_content(s)).is("COMMENT")

    local TD = self.get_TYPE()
    ---@type AD.At.Type
    t = self.p:match(TD.s)
    expect(t).contains(TD.m())
    expect(t:get_comment(TD.s)).is(TD.c)
  end,
  test_complete = function (self)
    self:do_test_complete("Type")
  end,
})

_G.test_Alias = Test({
  test_base = function ()
    local t = AD.At.Alias()
    expect(t).contains( AD.At.Alias({
      min         = 1,
      content_min = 1,
      content_max = 0,
      max         = 0,
    }) )
  end,
  setup = function (self)
    self.p = AD.At.Alias:get_capture_p()
  end,
  test = function (self)
    local s, t
----5----0----5----0----5----0----5----0
s = [=====[
---@alias NEW_NAME TYPE ]=====]
    ---@type AD.At.Alias
    t = self.p:match(s)
    expect(t).contains( AD.At.Alias({
      min         = 1,
      content_min = 24,
      content_max = 23,
      max         = 24,
      name        = "NEW_NAME",
      types       = { "TYPE" },
    }) )

----5----0----5----0----5----0----5----0
    s = [=====[
---@alias NEW_NAME TYPE | OTHER_TYPE ]=====]
    t = self.p:match(s)
    expect(t).contains( AD.At.Alias({
      min         = 1,
      content_min = 37,
      content_max = 36,
      max         = 37,
      name        = "NEW_NAME",
      types       = { "TYPE", "OTHER_TYPE" },
    }) )

    ----5----0----5----0----5----0----5----0----5----|
    s = [=====[
---@alias     NAME TYPE @ SOME   COMMENT]=====]
    t = self.p:match(s)
    expect(t).contains( AD.At.Alias({
      min         = 1,
      content_min = 27,
      content_max = 40,
      max         = 40,
      name        = "NAME",
      types       = { "TYPE" },
    }) )
    expect(t:get_comment(s)).is("SOME   COMMENT")

----5----0----5----0----5----0----5----0----5----|
    s = [=====[
---@alias     NAME TYPE @ SOME   COMMENT         
    SUITE                                        ]=====]
    t = self.p:match(s)
    expect(t).contains( AD.At.Alias({
      min         = 1,
      content_min = 27,
      content_max = 40,
      max         = 50,
      name        = "NAME",
      types       = { "TYPE" },
    }) )
    expect(t:get_comment(s)).is("SOME   COMMENT")
  end,
  test_TD = function (self)
    self:do_test_TD("Alias")
  end,
  test_complete = function (self)
    self:do_test_complete("Alias")
  end,
})

_G.test_Param = Test({
  test_base = function ()
    local t = AD.At.Param()
    expect(t).contains( AD.At.Param({
      min         = 1,
      content_min = 1,
      content_max = 0,
      max         = 0,
    }) )
  end,
  setup = function (self)
    self.p = AD.At.Param:get_capture_p()
  end,
  test = function (self)
    local s, t
----5----0----5----0----5----0----5----0----5----|
    s = [=====[
---@param NAME TYPE]=====]
    ---@type AD.At.Param
    t = self.p:match(s)
    expect(t).contains( AD.At.Param({
      min         = 1,
      content_min = 20,
      content_max = 19,
      max         = 19,
      name        = "NAME",
      optional    = false,
      types       = { "TYPE" },
    }) )
    expect(t:get_comment(s)).is("")

----5----0----5----0----5----0----5----0----5----|
    s = [=====[
---@param NAME ? TYPE]=====]
    ---@type AD.At.Param
    t = self.p:match(s)
    expect(t).contains( AD.At.Param({
      min         = 1,
      content_min = 22,
      content_max = 21,
      max         = 21,
      name        = "NAME",
      optional    = true,
      types       = { "TYPE" },
    }) )
    expect(t:get_comment(s)).is("")

----5----0----5----0----5----0----5----0----5----|
    s = [=====[
---@param NAME TYPE
]=====]
    ---@type AD.At.Param
    t = self.p:match(s)
    expect(t).contains( AD.At.Param({
      min         = 1,
      content_min = 20,
      content_max = 19,
      max         = 20,
      name        = "NAME",
      optional    = false,
      types       = { "TYPE" },
    }) )
    expect(t:get_comment(s)).is("")

----5----0----5----0----5----0----5----0----5----|
s = [=====[
---@param NAME ? TYPE
]=====]
  ---@type AD.At.Param
  t = self.p:match(s)
  expect(t).contains( AD.At.Param({
    min         = 1,
    content_min = 22,
    content_max = 21,
    max         = 22,
    name        = "NAME",
    optional    = true,
    types       = { "TYPE" },
  }) )
  expect(t:get_comment(s)).is("")

----5----0----5----0----5----0----5----0----5----|
    s = [=====[
---@param NAME TYPE  |  OTHER
]=====]
    ---@type AD.At.Param
    t = self.p:match(s)
    expect(t).contains( AD.At.Param({
      min         = 1,
      content_min = 30,
      content_max = 29,
      max         = 30,
      name        = "NAME",
      optional    = false,
      types       = { "TYPE", "OTHER" },
    }) )
    expect(t:get_comment(s)).is("")

----5----0----5----0----5----0----5----0----5----|
    s = [=====[
---@param NAME TYPE  |  OTHER@  COMMENT
]=====]
    ---@type AD.At.Param
    t = self.p:match(s)
    expect(t).contains( AD.At.Param({
      min         = 1,
      content_min = 33,
      content_max = 39,
      max         = 40,
      name        = "NAME",
      optional    = false,
      types       = { "TYPE", "OTHER" },
    }) )
    expect(t:get_comment(s)).is("COMMENT")
  end,
  test_TD = function (self)
    self:do_test_TD("Param")
  end,
  test_complete = function (self)
    self:do_test_complete("Param")
  end,
})

_G.test_Return = Test({
  test_base = function ()
    local t = AD.At.Return()
    expect(t.__Class).is(AD.At.Return)
    expect(t).contains({
      min         = 1,
      max         = 0,
      content_min = 1,
      content_max = 0,
    })
  end,
  setup = function (self)
    self.p = __.chunk_init_p
      * AD.At.Return:get_capture_p()
  end,
  test = function (self)
    local s, t
----5----0----5----0----5----0----5----0----5----|
    s = [=====[
---   @return TYPE   |  OTHER @ COMMENT
]=====]
    t = self.p:match(s)
    expect(t).contains({
      min         = 1,
      max         = 40,
      content_min = 33,
      content_max = 39,
      types       = { "TYPE", "OTHER" },
    })
    expect(t:get_comment(s)).is("COMMENT")
----5----0----5----0----5----0----5----0----5----|
    s = [=====[
---   @return TYPE? @ COMMENT
]=====]
    t = self.p:match(s)
    expect(t).contains({
      min         = 1,
      max         = 30,
      content_min = 23,
      content_max = 29,
      types       = { "TYPE" },
      optional    = true,
    })
    expect(t:get_comment(s)).is("COMMENT")
    end,
  test_TD = function (self)
    self:do_test_TD("Return")
  end,
  test_complete = function (self)
    self:do_test_complete("Return")
  end,
})

_G.test_Generic = Test({
  test_base = function ()
    local t = AD.At.Generic()
    expect(t.__Class).is(AD.At.Generic)
    expect(t).contains({
      min         = 1,
      max         = 0,
      content_min = 1,
      content_max = 0,
    })
  end,
  setup = function (self)
    self.p = __.chunk_init_p
      * AD.At.Generic:get_capture_p()
  end,
  test = function (self)
    local s, t
    s = [=====[
---@generic T1
]=====]
    ---@type AD.At.Generic
    t = self.p:match(s)
    expect(t.type_1).is.equal.to("T1")
    expect(t.parent_1).is(nil)
    expect(t.type_2).is(nil)
    expect(t.parent_2).is(nil)

    s = [=====[
---@generic T1: PARENT_TYPE_1
]=====]
    t = self.p:match(s)
    expect(t.type_1).is.equal.to("T1")
    expect(t.parent_1).is.equal.to("PARENT_TYPE_1")

    s = [=====[
---@generic T1, T2
]=====]
    t = self.p:match(s)
    expect(t.type_1).is.equal.to("T1")
    expect(t.parent_1).is(nil)
    expect(t.type_2).is.equal.to("T2")
    expect(t.parent_2).is(nil)

    s = [=====[
---@generic T1 : PARENT_TYPE, T2
]=====]
    t = self.p:match(s)
    expect(t.type_1).is.equal.to("T1")
    expect(t.parent_1).is("PARENT_TYPE")
    expect(t.type_2).is.equal.to("T2")
    expect(t.parent_2).is(nil)

    s = [=====[
---@generic T1, T2 : PARENT_TYPE
]=====]
    t = self.p:match(s)
    expect(t.type_1).is.equal.to("T1")
    expect(t.parent_1).is(nil)
    expect(t.type_2).is.equal.to("T2")
    expect(t.parent_2).is("PARENT_TYPE")

    s = [=====[
---@generic T1 : PARENT_TYPE, T2 : PARENT_TYPE
]=====]
    t = self.p:match(s)
    expect(t.type_1).is.equal.to("T1")
    expect(t.parent_1).is("PARENT_TYPE")
    expect(t.type_2).is.equal.to("T2")
    expect(t.parent_2).is("PARENT_TYPE")

    ----5----0----5----0----5----0----5----0----5----0----5----|
    s = [=====[
---@generic   T1 : PARENT_TYPE, T2 : PARENT_TYPE @  COMMENT
]=====]
    t = self.p:match(s)
    expect(t.type_1).is.equal.to("T1")
    expect(t.parent_1).is("PARENT_TYPE")
    expect(t.type_2).is.equal.to("T2")
    expect(t.parent_2).is("PARENT_TYPE")
    expect(t:get_content(s)).is("COMMENT")
    expect(t.min).is(1)
    expect(t.max).is(60)
  end,
  test_TD = function (self)
    self:do_test_TD("Generic")
  end,
  test_complete = function (self)
    self:do_test_complete("Generic")
  end,
})

_G.test_Vararg = Test({
  test_base = function ()
    local t = AD.At.Vararg()
    expect(t).contains( AD.At.Vararg({
      min         = 1,
      content_min = 1,
      content_max = 0,
      max         = 0,
    }) )
  end,
  setup = function (self)
    self.p = AD.At.Vararg:get_capture_p()
  end,
  test = function (self)
    local s, t
----5----0----5----0----5----0----5----0----5----0----5----|
    s = [=====[
---@vararg    TYPE_
]=====]
    ---@type AD.At.Vararg
    t = self.p:match(s)
    expect(t).contains( AD.At.Vararg({
      min         = 1,
      content_min = 20,
      content_max = 19,
      max         = 20,
      types       = { "TYPE_" },
    }) )
    expect(t:get_comment(s)).is("")

----5----0----5----0----5----0----5----0----5----0----5----|
    s = [=====[
---@vararg    TYPE_|TYPE
]=====]
    ---@type AD.At.Vararg
    t = self.p:match(s)
    expect(t).contains( AD.At.Vararg({
      min         = 1,
      content_min = 25,
      content_max = 24,
      max         = 25,
      types       = { "TYPE_", "TYPE" },
    }) )
    expect(t:get_comment(s)).is("")

----5----0----5----0----5----0----5----0----5----0----5----|
    s = [=====[
---@vararg    TYPE_|TYPE@CMT_
]=====]
    ---@ype AD.At.Vararg
    t = self.p:match(s)
    expect(t).contains( AD.At.Vararg({
      min         = 1,
      content_min = 26,
      content_max = 29,
      max         = 30,
      types       = { "TYPE_", "TYPE" },
    }) )
    expect(t:get_content(s)).is("CMT_")
  end,
  test_TD = function (self)
    self:do_test_TD("Vararg")
  end,
  test_complete = function (self)
    self:do_test_complete("Vararg")
  end,
})

_G.test_Module = Test({
  test_base = function ()
    local t = AD.At.Module()
    expect(t).contains( AD.At.Module({
      min         = 1,
      content_min = 1,
      content_max = 0,
      max         = 0,
    }) )
  end,
  setup = function (self)
    self.p = AD.At.Module:get_capture_p()
  end,
  test = function (self)
    local s, t
----5----0----5----0----5----0----5----0----5----0----5----|
    s = [=====[
---   @module name_
]=====]
    ---@type AD.At.Module
    t = self.p:match(s)
    expect(t).contains( AD.At.Module({
      min         = 1,
      content_min = 20,
      content_max = 19,
      max         = 20,
      name        = "name_",
    }) )
    expect(t:get_comment(s)).is("")

----5----0----5----0----5----0----5----0----5----0----5----|
    s = [=====[
---   @module name_ @ COMMENT
]=====]
    t = self.p:match(s)
    expect(t).contains( AD.At.Module({
      min         = 1,
      content_min = 23,
      content_max = 29,
      max         = 30,
      name        = "name_",
    }) )
    expect(t:get_comment(s)).is("COMMENT")
  end,
  test_TD = function (self)
    self:do_test_TD("Module")
  end,
  test_complete = function (self)
    self:do_test_complete("Module")
  end,
})

_G.test_Function = Test({
  test_base = function ()
    local t = AD.At.Function()
    expect(t).contains( AD.At.Function({
      min         = 1,
      content_min = 1,
      content_max = 0,
      max         = 0,
    }) )
  end,
  setup = function (self)
    self.p = AD.At.Function:get_capture_p()
  end,
  test = function (self)
    local s, t
---5----0----5----0----5----0----5----0----5----0----5----
    s = [=====[
---@function  name_
]=====]
    t = self.p:match(s)
    expect(t).contains({
      min = 1,
      max = 20,
      name = "name_",
    })
---5----0----5----0----5----0----5----0----5----0----5----
    s = [=====[
---@function  name_ @ COMMENT
]=====]
    t = self.p:match(s)
    expect(t).contains({
      min         = 1,
      max         = 30,
      content_min = 23,
      content_max = 29,
      name        = "name_",
    })
    expect(t:get_comment(s)).is("COMMENT")
  end,
  test_TD = function (self)
    self:do_test_TD("Function")
  end,
  test_complete = function (self)
    self:do_test_complete("Function")

    local p = AD.At.Function:get_complete_p()

    local TD = self.get_PARAM()
    expect(p:match(TD.s)).contains({
      ID          = AD.At.Function.ID,
      max         = 46,
      description = {
        ID      = AD.Description.ID,
        long    = {},
        ignores = {},
      },
      params      = {
        {
          ID          = AD.At.Param.ID,
          min         = 1,
          content_min = 35,
          content_max = 45,
          max         = 46,
          description = {
            ID      = AD.Description.ID,
            long    = {},
            ignores = {},
          },
          name        = "NAME",
          optional    = false,
          types       = {
            "TYPE",
            "OTHER",
          },
        }
      },
    })
  end,
})

_G.test_Break = Test({
  test_base = function ()
    local t = AD.Break()
    expect(t).contains( AD.Break({
      min         = 1,
      max         = 0,
    }) )
  end,
  setup = function (self)
    self.p = AD.Break:get_capture_p()
  end,
  test = function (self)
    ---@type AD.Break
    local t = self.p:match("\n")
    self:p_test("", nil)
    expect(t).contains({
      min = 1,
      max = 1,
    })
    t = self.p:match(" \n ")
    expect(t).contains({
      min = 1,
      max = 3,
    })
    t = self.p:match(" \n \n")
    expect(t).contains({
      min = 1,
      max = 4,
    })
  end,
})

_G.test_Global = Test({
  test_base = function ()
    local t = AD.At.Global()
    expect(t).contains( AD.At.Global({
      min         = 1,
      content_min = 1,
      content_max = 0,
      max         = 0,
    }) )
  end,
  setup = function (self)
    self.p =
        __.chunk_init_p
      * AD.At.Global:get_capture_p()
  end,
  test = function (self)
----5----0----5----0----5----0----5----0----5----0----5----
    local s, t
    s = [=====[
---  @global  name_
]=====]
    ---@type AD.At.Global
    t = self.p:match(s)
    expect(t).contains({
      min = 1,
      max = 20,
      name = "name_",
    })

---5----0----5----0----5----0----5----0----5----0----5----|
    s = [=====[
---  @global  name_ @ COMMENT
]=====]
    t = self.p:match(s)
    expect(t).contains({
      min = 1,
      max = 30,
      name = "name_",
    })
    expect(t:get_comment(s)).is("COMMENT")
  end,
  test_TD = function (self)
    self:do_test_TD("Global")
  end,
  test_complete = function (self)
    self:do_test_complete("Global")
  end,
})

Test.STANDARD_ITEMS = {
  "LINE_DOC",
  "LONG_DOC",
  "FIELD",
  "SEE",
  "CLASS",
  "TYPE",
  "MODULE",
  "ALIAS",
  -- "PARAM",
  -- "GENERIC",
  -- "VARARG",
  -- "RETURN",
  "FUNCTION",
  "GLOBAL",
}
Test.FUNCTION_ITEMS = {
  PARAM = true,
  GENERIC = false,
  VARARG = false,
  RETURN = true,
}
_G.test_loop_p = Test({
  setup = function (self)
    self.p = __.loop_p
  end,
  no_test_items = function (self)
    expect(self.p).is.NOT(nil)
    local p = AD.LineDoc:get_capture_p()
    local f = self["get_".. "LINE_DOC"]
    local TD = f(self)
    print("TD.s", TD.s)
    _G.pretty_print(p:match(TD.s))
    expect(p:match(TD.s)).contains(TD.m())
  end,
  test_standard_items = function (self)
    for _, KEY in ipairs(self.STANDARD_ITEMS) do
      local f = self["get_".. KEY]
      local TD = f(self)
      local m = self.p:match(TD.s)
      expect(m).contains(TD.m())
      if TD.c and m.get_content then
        expect(m:get_content(TD.s)).is(TD.c)
      end
    end
  end,
  test_function_items = function (self)
    -- to one attributes
    for KEY, multi in pairs(self.FUNCTION_ITEMS) do
      local f = self["get_".. KEY]
      local TD = f(self)
      local m = self.p:match(TD.s)
      local key = multi
        and KEY:lower() .."s"
        or  KEY:lower()
      expect(m).contains({
        ID          = AD.At.Function.ID,
        max         = TD.m().max,
        description = AD.Description(),
        [key]       = multi and { TD.m() } or TD.m(),
      })
    end
  end,
})

_G.test_Source = Test({
  test_base = function ()
    local t = AD.Source()
    expect(t).contains( AD.Source() )
  end,
  setup = function (self)
    self.p = AD.Source:get_capture_p()
  end,
  test_standard_items = function (self)
    for _, KEY in ipairs(self.STANDARD_ITEMS) do
      local f = self["get_".. KEY]
      local TD = f(self)
      local m = self.p:match(TD.s)
      expect(m).contains({
        ID = AD.Source.ID,
        infos = { TD.m() },
      })
    end
  end,
  test_function_items = function (self)
    for KEY, multi in pairs(self.FUNCTION_ITEMS) do
      local f = self["get_".. KEY]
      local TD = f(self)
      local m = self.p:match(TD.s)
      local key = multi
        and KEY:lower() .."s"
        or  KEY:lower()
      expect(m).contains({
        ID = AD.Source.ID,
        infos = { {
          ID          = AD.At.Function.ID,
          max         = TD.m().max,
          description = AD.Description(),
          [key]       = multi and { TD.m() } or TD.m(),
        } },
      })
    end
  end,
  test_two_items = function (self)
    for _, KEY_1 in ipairs(self.STANDARD_ITEMS) do
      local f_1 = self["get_".. KEY_1]
      local TD_1 = f_1(self)
      for _, KEY_2 in ipairs(self.STANDARD_ITEMS) do
        local f_2 = self["get_".. KEY_2]
        local TD_2 = f_2(self)
        local m = self.p:match(TD_1.s .. TD_2.s)
        -- do not test when items are combined
        if #m.infos == 2 then
          expect(m).contains({
            ID = AD.Source.ID,
            infos = {
              TD_1.m(),
              TD_2.m(1 + TD_1.m().max)
            },
          })
        end
      end
    end
  end,
})

_G.test_autodoc = Test({
  setup = function (self)
    self.p = AD.Source:get_capture_p()
  end,
  test = function (self)
    local fh =  io.open("../l3build-autodoc.lua")
    local s = fh:read("a")
    fh:close()
    local m = self.p:match(s)
    expect(#m.infos>0).is(true)
  end,
})

_G.test_Parser = Test({
  setup = function (self)
    self.parser = AD.Parser("../l3build-autodoc.lua")
    self.parser:parse()
  end,
  test_parse = function (self)
    expect(#self.parser._infos > 0).is(true)
  end,
  test_function_name = function (self)
    for info in self.parser.infos do
      if info:is_instance_of(AD.At.Function) then
        expect(info.name).is.NOT(AD.At.Function.name)
      end
    end
  end,
})

os.exit( LU.LuaUnit.run() )
