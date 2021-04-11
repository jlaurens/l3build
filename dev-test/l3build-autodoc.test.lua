#!/usr/bin/env texlua

local write   = io.write

local function pretty_print(tt, indent, done)
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
          pretty_print(v, indent + w + 7, done)
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

local lpeg    = require("lpeg")

do
  local p_one = lpeg.Cg(lpeg.P(1), "one")
  local p_two = lpeg.Cg(lpeg.P(1), "two")
  local t = lpeg.Ct(p_one*p_two):match("12")
  expect(t.one).is("1")
  expect(t.two).is("2")
end

do
  -- print("POC min <- max + 1")
  local p1 =
      lpeg.Cg(lpeg.Cc(421), "min")
    * lpeg.Cg(lpeg.Cc(123), "max")
  local m = lpeg.Ct(p1):match("")
  expect(m.min).is(421)
  expect(m.max).is(123)
  local p2 = p1 * lpeg.Cg(
    lpeg.Cb("min") / function (min) return min + 1 end,
    "max"
  )
  m = lpeg.Ct(p2):match("")
  expect(m.min).is(421)
  expect(m.max).is(422)
end


-- All the tests are object with next `MT` as metatable
local MT = {}
MT.__index = MT
function MT:new(d)
  return setmetatable(d or {}, self)
end

_G.test_Info = function ()
  expect(AD.Info).is.NOT(nil)
  expect(AD.Info.__Class).is(AD.Info)
end

function MT:add_strip(k)
  LU.STRIP_EXTRA_ENTRIES_IN_STACK_TRACE =
    LU.STRIP_EXTRA_ENTRIES_IN_STACK_TRACE + k
end

function MT:p_test(target, expected, where)
  self:add_strip(1)
  expect(self.p:match(target, where)).is(expected)
  self:add_strip(-1)
end

_G.test_white_p = MT:new({
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

_G.test_black_p = MT:new({
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

_G.test_eol_p = MT:new({
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


local P       = lpeg.P


local t, p, f, s

_G.test_variable_p = MT:new({
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

_G.test_identifier_p = MT:new({
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

_G.test_special_begin_p = MT:new({
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

_G.test_colon_p = MT:new({
  setup = function (self)
    self.p = __.colon_p
  end,
  test = function (self)
    expect(self.p).is.NOT(nil)
    self:p_test("abc", nil)
    self:p_test(" : abc", 4)
  end
})

_G.test_comma_p = MT:new({
  setup = function (self)
    self.p = __.comma_p
  end,
  test = function (self)
    expect(self.p).is.NOT(nil)
  end
})

p = P({
  "type",
  type = lpeg.V("table") + P("abc"),
  table =
    P("table")   -- table<foo,bar>
  * P( __.get_spaced_p("<")
    * lpeg.V("type")
    * __.comma_p
    * lpeg.V("type")
    * __.get_spaced_p(">")
  )^-1,
})
expect((p * lpeg.Cp()):match("table<abc,abc>")).is(15)

_G.test_lua_type_p = MT:new({
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

_G.test_named_types_p = MT:new({
  setup = function (self)
    self.p = lpeg.Ct(__.named_types_p)
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

_G.test_comment_p = MT:new({
  setup = function (self)
    self.p = lpeg.Ct(__.capture_comment_p)
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

_G.test_comment_p_2 = MT:new({
  setup = function (self)
    self.p = lpeg.Ct(
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

function MT:ad_test(target, expected, content, index)
  self:add_strip(1)
  local m = self.p:match(target, index)
  expect(m).contains(expected)
  expect(m:get_content(target)).is(content)
  self:add_strip(-1)
end

_G.test_ShortLiteral = MT:new({
  test_base = function ()
    local t = AD.ShortLiteral()
    expect(t.__Class).is(AD.ShortLiteral)
    expect(t.min).is(1)
    expect(t.max).is(0)
    expect(t.content_min).is(1)
    expect(t.content_max).is(0)
  end,
  setup = function (self)
    self.p = __.chunk_init_p
      * AD.ShortLiteral:get_capture_p()
  end,
  test = function (self)
    local s, t
    expect(self.p).is.NOT(nil)
    s = '"234"  \n  '
    ---@type AD.ShortLiteral
    local t = self.p:match(s)
    expect(t.__Class).is(AD.ShortLiteral)
    expect(t).equals({
      min = 1,
      max = 8,
      content_min = 2,
      content_max = 4,
      code_before = {
        max = 0,
        min = 1,
      },
    })

    s = "'234'  \n  "
    local t = self.p:match(s)
    expect(t.__Class).is(AD.ShortLiteral)
    expect(t).contains({
      min         = 1,
      max         = 8,
      content_min = 2,
      content_max = 4,
    })
  end
})

_G.test_LongLiteral = MT:new({
  test_base = function ()
    local t = AD.LongLiteral()
    expect(t.__Class).is(AD.LongLiteral)
    expect(t).contains({
      min         = 1,
      max         = 0,
      content_min = 1,
      content_max = 0,
      level       = 0,
    })
  end,
  setup = function (self)
    self.p = __.chunk_init_p
      * AD.LongLiteral:get_capture_p()
  end,
  test = function (self)
    local s, t
    s = '[[345]]  \n  '
    local t = self.p:match(s)
    expect(t.__Class).is(AD.LongLiteral)
    expect(t).contains({
      min         = 1,
      max         = 10,
      content_min = 3,
      content_max = 5,
      level       = 0,
    })

    local t = self.p:match('[===[678]===]  \n  ')
    expect(t.__Class).is(AD.LongLiteral)
    expect(t).contains({
      min         = 1,
      max         = 16,
      content_min = 6,
      content_max = 8,
      level       = 3,
    })
  end
})

_G.test_LineComment = MT:new({
  test_base = function ()
    local t = AD.LineComment()
    expect(t.__Class).is(AD.LineComment)
    expect(t).contains({
      min         = 1,
      max         = 0,
      content_min = 1,
      content_max = 0,
    })
  end,
  setup = function (self)
    self.p = __.chunk_init_p
      * AD.LineComment:get_capture_p()
  end,
  test = function (self)
    local s, t
    ---@type AD.LineComment
    local t = self.p:match('-  \n  ')
    expect(t).is(nil)
    local t = self.p:match('---  \n  ')
    expect(t).is(nil)
    local t = self.p:match('---  \n  ', 2)
    expect(t).is(nil)

    local t = self.p:match('--  ')
    expect(t.__Class).is(AD.LineComment)
    expect(t).contains({
      min         = 1,
      max         = 4,
      content_min = 5,
      content_max = 4,
    })

    local t = self.p:match('--  \n  ')
    expect(t.__Class).is(AD.LineComment)
    expect(t).contains({
      min         = 1,
      max         = 5,
      content_min = 5,
      content_max = 4,
    })

    local t = self.p:match('----------')
    expect(t.__Class).is(AD.LineComment)
    expect(t.min).is(1)
    expect(t.max).is(10)
    expect(t.content_min).is(11)
    expect(t.content_max).is(10)

    local t = self.p:match('-- 456 89A \n  ')
    expect(t.__Class).is(AD.LineComment)
    expect(t.min).is(1)
    expect(t.max).is(12)
    expect(t.content_min).is(4)
    expect(t.content_max).is(10)
  end
})

_G.test_LongComment = MT:new({
  test_base = function ()
    local t = AD.LongComment()
    expect(t.__Class).is(AD.LongComment)
    expect(t).contains({
      min         = 1,
      max         = 0,
      content_min = 1,
      content_max = 0,
      level       = 0,
    })
  end,
  setup = function (self)
    self.p = __.chunk_init_p
      * AD.LongComment:get_capture_p()
  end,
  test = function (self)
    local s, t
    ---@type AD.LongComment
    local t = self.p:match('--  \n  ')
    expect(t).is(nil)

    local t = self.p:match('--[[56 89A]]')
    expect(t.__Class).is(AD.LongComment)
    expect(t).contains({
      min         = 1,
      max         = 12,
      content_min = 5,
      content_max = 10,
      level       = 0,
    })

    local t = self.p:match('--[[\n6 89A]]')
    expect(t.__Class).is(AD.LongComment)
    expect(t).contains({
      min         = 1,
      max         = 12,
      content_min = 6,
      content_max = 10,
      level       = 0,
    })

    local t = self.p:match('--[[\n  8\nA  ]]')
    expect(t.__Class).is(AD.LongComment)
    expect(t).contains({
      min         = 1,
      max         = 14,
      content_min = 6,
      content_max = 10,
      level       = 0,
    })

    local t = self.p:match('--[==[78]=] \n ]==] ')
    expect(t.__Class).is(AD.LongComment)
    expect(t).contains({
      min         = 1,
      max         = 19,
      content_min = 7,
      content_max = 13,
      level       = 2,
    })
  end
})

_G.test_LineDoc = MT:new({
  test_base = function ()
    local t = AD.LineDoc()
    expect(t.__Class).is(AD.LineDoc)
    expect(t).contains({
      min         = 1,
      max         = 0,
      content_min = 1,
      content_max = 0,
    })
  end,
  setup = function (self)
    self.p = __.chunk_init_p
      * AD.LineDoc:get_capture_p()
  end,
  test = function (self)
    local s, t
    local t = self.p:match('-- ')
    expect(t).is(nil)
    local t = self.p:match('---- ')
    expect(t).is(nil)
    local t = self.p:match('---- ', 1)
    expect(t).is(nil)

    local t = self.p:match('---')
    expect(t.__Class).is(AD.LineDoc)
    expect(t.min).is(1)
    expect(t.max).is(3)
    expect(t.content_min).is(4)
    expect(t.content_max).is(3)

    local t = self.p:match('---456789A')
    expect(t.__Class).is(AD.LineDoc)
    expect(t.min).is(1)
    expect(t.max).is(10)
    expect(t.content_min).is(4)
    expect(t.content_max).is(10)

    local t = self.p:match('--- 56 89 ')
    expect(t.__Class).is(AD.LineDoc)
    expect(t.min).is(1)
    expect(t.max).is(10)
    expect(t.content_min).is(5)
    expect(t.content_max).is(9)

    local t = self.p:match('--- 56 89 \n')
    expect(t.__Class).is(AD.LineDoc)
    expect(t.min).is(1)
    expect(t.max).is(11)
    expect(t.content_min).is(5)
    expect(t.content_max).is(9)

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
  end
})

_G.test_Description = MT:new({
  test_base = function ()
    local t = AD.Description()
    expect(t.__Class).is(AD.Description)
  end,
  setup = function (self)
    self.p = __.chunk_init_p
      * AD.Description:get_capture_p()
  end,
  test = function (self)
    local s, t
    local t = self.p:match("--")
    expect(t).is(nil)

    expect(self.p:match("---")).is.NOT(nil)
    expect(self.p:match("---\n---")).is.NOT(nil)
    expect(self.p:match("---\n--[===[]===]")).is.NOT(nil)

    ---@type AD.Description
    local t = self.p:match("---")
    expect(t.__Class).is(AD.Description)
    expect(t.short.__Class).is(AD.LineDoc)
    expect(#t.long).is(0)
    expect(t.min).is(1)
    expect(t.max).is(3)

    local t = self.p:match("---\n")
    expect(t.max).is(4)

    local t = self.p:match("---\ns")
    expect(t.max).is(4)

    local t = self.p:match("---\n\n")
    expect(t.max).is(4)

    local t = self.p:match("-- \n---")
    expect(t).is(nil)

    local t = self.p:match("---\n---")

    expect(t.__Class).is(AD.Description)
    expect(t.short.__Class).is(AD.LineDoc)
    expect(#t.long).is(1)
    expect(t.long[1].__Class).is(AD.LineDoc)
    expect(t.long[1].max).is(7)
    expect(t.max).is(7)

    s = [=====[
---
--[[]]
]=====]
    local t = self.p:match(s)
    expect(t.__Class).is(AD.Description)
    expect(t.short.__Class).is(AD.LineDoc)
    expect(#t.long).is(0)
    expect(t.max).is(11)

    s = [=====[
---
--[===[]===]
]=====]
    local t = self.p:match(s)
    expect(t.__Class).is(AD.Description)
    expect(t.short.__Class).is(AD.LineDoc)
    expect(#t.long).is(1)
    expect(t.long[1].__Class).is(AD.LongDoc)
    expect(t.min).is(1)
    expect(t.max).is(17)

    s = [=====[
---
--[===[]===]
--
---
s   s
]=====]
    local t = self.p:match(s)
    expect(t.__Class).is(AD.Description)
    expect(t.short.__Class).is(AD.LineDoc)
    expect(#t.long).is(2)
    expect(t.long[1].__Class).is(AD.LongDoc)
    expect(t.long[2].__Class).is(AD.LineDoc)
    expect(t.max).is(24)
  end
})

_G.test_Field = MT:new({
  test_base = function ()
    local t = AD.At.Field()
    expect(t.__Class).is(AD.At.Field)
    expect(t).contains({
      min         = 1,
      max         = 0,
      content_min = 1,
      content_max = 0,
    })
  end,
  setup = function (self)
    self.p = __.chunk_init_p
      * AD.At.Field:get_capture_p()
  end,
  test = function (self)
    local s, t
    expect(function () self.p:match("--- @field public foo") end).error()

    expect(function () self.p:match("--- @field public foo \n bar") end).error()

    ---@type AD.At.Field
    t = self.p:match("--- @field public f21 b25")

    expect(lpeg.Ct(__.named_types_p):match("--- @field public f21 b25", 23)).equals({
      types = { "b25" },
    })

    expect(t.__Class).is(AD.At.Field)
    expect(t).contains({
      min         = 1,
      max         = 25,
      visibility  = "public",
      name        = "f21",
      types       = { "b25" },
    })

    t = self.p:match("--- @field private f22 b26\n   ")
    expect(t.__Class).is(AD.At.Field)
    expect(t).contains({
      min         = 1,
      max         = 27,
      visibility  = "private",
      name        = "f22",
      types       = { "b26" },
    })

    ----5----0   ----5----0----5----0----5----0----5----0----5
    local t = self.p:match("--- @field private f22 b26 @ commentai40   ")
    expect(t.__Class).is(AD.At.Field)
    expect(t).contains({
      min         = 1,
      max         = 43,
      content_min = 30,
      content_max = 40,
      visibility  = "private",
      name        = "f22",
      types       = { "b26" },
    })

    local t = self.p:match("--- @field private f22 b26\n   ")
    expect(t.__Class).is(AD.At.Field)
    expect(t).contains({
      min         = 1,
      max         = 27,
      content_min = 1,
      content_max = 0,
      visibility  = "private",
      name        = "f22",
      types       = { "b26" },
    })

    local t = self.p:match("123456789--- @field private f22 b26\n   ", 10)
    expect(t.__Class).is(AD.At.Field)
    expect(t).contains({
      min         = 10,
      max         = 36,
      content_min = 1,
      content_max = 0,
      visibility  = "private",
      name        = "f22",
      types       = { "b26" },
    })
  end
})

_G.test_See = MT:new({
  test_base = function ()
    local t = AD.At.See()
    expect(t.__Class).is(AD.At.See)
    expect(t).contains({
      min         = 1,
      max         = 0,
      content_min = 1,
      content_max = 0,
    })
  end,
  setup = function (self)
    self.p = __.chunk_init_p
      * AD.At.See:get_capture_p()
  end,
  test = function (self)
    local s, t
    s = "---@see 9hat do you want of 30  "
    ---@type AD.At.See
    local t = self.p:match(s)
    expect(t.__Class).is(AD.At.See)
    expect(t.min).is(1)
    expect(t.max).is(32)
    expect(t.content_min).is(9)
    expect(t.content_max).is(30)
    expect(t:get_content(s)).is("9hat do you want of 30")
  end
})

-- @class MY_TYPE[:PARENT_TYPE] [@comment]
_G.test_Class = MT:new({
  test_base = function (self)
    local t = AD.At.Class()
    expect(t.__Class).is(AD.At.Class)
    expect(t).contains({
      min         = 1,
      max         = 0,
      content_min = 1,
      content_max = 0,
    })
  end,
  setup = function (self)
    self.p = __.chunk_init_p
      * AD.At.Class:get_capture_p()
  end,
  test = function (self)
    local s, t
    ---@type AD.At.Class
    t = self.p:match("---@class MY_TY17")

    expect(t.__Class).is(AD.At.Class)
    expect(t).contains({
      min         = 1,
      max         = 17,
      content_min = 1,
      content_max = 0,
    })
    expect(t.parent).is(nil)
    
    ---@type AD.At.Class
    t = self.p:match("---@class AY_TYPE: PARENT_TY30")
    expect(t.__Class).is(AD.At.Class)
    expect(t).contains({
      min         = 1,
      max         = 30,
      content_min = 1,
      content_max = 0,
      name        = "AY_TYPE",
      parent      = "PARENT_TY30",
    })
----5----0----5----0----5----0----5----0----5----|
    s = [[
---@class TYPE: PARENT @         COMMENT]]

    ---@type AD.At.Class
    t = self.p:match(s)
    expect(t).contains({
      min         = 1,
      max         = 40,
      content_min = 34,
      content_max = 40,
      name        = "TYPE",
      parent      = "PARENT",
    })
    expect(t:get_comment(s)).is("COMMENT")

  end
})

-- @class MY_TYPE[:PARENT_TYPE] [@comment]
_G.test_Class2 = MT:new({
  setup = function (self)
    self.p = __.chunk_init_p
      * AD.At.Class:get_complete_p()
  end,
  test_base = function (self)
----5----0----5----0----5----0----5----0----5----
    s = [[
---@class TYPE: PARENT @        COMMENT
---@field protected NAME TYPE @   OTHER]]
    ---@type AD.At.Class
    t = self.p:match(s)
    expect(t.__Class).is(AD.At.Class)
    expect(t).contains({
      min         = 1,
      max         = 80,
      content_min = 33,
      content_max = 39,
      name        = "TYPE",
      parent      = "PARENT",
    })
    expect(t:get_comment(s)).is("COMMENT")
    ---@type AD.At.Class
    t = self.p:match(s)
    expect(t.__Class).is(AD.At.Class)
    expect(t).contains({
      min         = 1,
      max         = 80,
      content_min = 33,
      content_max = 39,
      name        = "TYPE",
      parent      = "PARENT",
    })
    expect(t:get_comment(s)).is("COMMENT")

    expect(#t.fields).is(1)
    local f = t.fields[1]
    expect(f.name).is("NAME")
    expect(f.types).equal({ "TYPE" })
    expect(f:get_comment(s)).is("OTHER")

    expect(t.see).is(nil)

    ---@type AD.At.Class
          ----5----0----5----0----5----0----5----0----5----
    s = [[---@class MY_TYPE: PARENT_TYPE @ COMMENT
---SHORT DOC
---@field public NAME TYPE @ OTHER COMMENT]]
    t = self.p:match(s)
    expect(t.__Class).is(AD.At.Class)
    expect(t).contains({
      min         = 1,
      max         = 97,
      content_min = 34,
      content_max = 40,
      name        = "MY_TYPE",
      parent      = "PARENT_TYPE",
    })
    expect(t:get_comment(s)).is("COMMENT")

    expect(#t.fields).is(1)
    local f = t.fields[1]
    expect(f.name).is("NAME")
    expect(f.types).equal({ "TYPE" })
    expect(f:get_comment(s)).is("OTHER COMMENT")

    expect(t.see).is(nil)

    expect(f.description).is.NOT(nil)
    expect(f:get_short_description(s)).is("SHORT DOC")
    expect(f:get_long_description(s)).is("")

----5----0----5----0----5----0----5----0----5----
    s = [=====[
---@class MY_TYPE: PARENT_TYPE @ COMMENT
---@field public NAME TYPE @ OTHER COMMENT
---SEE SHORT DESCRIPTION
--[===[SEE LONG DESCRIPTION]===]
---@see SEE
  foo bar]=====]
    ---@type AD.At.Class
    t = self.p:match(s)
    expect(t.__Class).is(AD.At.Class)
    expect(t).contains({
      min         = 1,
      max         = 155,
      content_min = 34,
      content_max = 40,
      name        = "MY_TYPE",
      parent      = "PARENT_TYPE",
    })
    expect(t:get_comment(s)).is("COMMENT")

    expect(#t.fields).is(1)
    local f = t.fields[1]
    expect(f.name).is("NAME")
    expect(f.types).equal({ "TYPE" })
    expect(f:get_content(s)).is("OTHER COMMENT")

    expect(t.see:get_short_description(s)).is("SEE SHORT DESCRIPTION")
    expect(t.see:get_long_description(s)).is("SEE LONG DESCRIPTION")

    ---@type AD.At.Field
    t = (__.chunk_init_p * AD.At.Field:get_capture_p()):match(s, 42)
    expect(t.__Class).is(AD.At.Field)
    expect(t).contains({
      min         = 42,
      max         = 84,
      content_min = 71,
      content_max = 83,
      visibility  = "public",
      name        = "NAME",
      types       = { "TYPE" },
    })
    expect(t:get_comment(s)).is("OTHER COMMENT")
  end
})

_G.test_Type = MT:new({
  test_base = function ()
    local t = AD.At.Type()
    expect(t.__Class).is(AD.At.Type)
    expect(t).contains({
      min         = 1,
      max         = 0,
      content_min = 1,
      content_max = 0,
    })
  end,
  setup = function (self)
    self.p = __.chunk_init_p
      * AD.At.Type:get_capture_p()
  end,
  test = function (self)
    local s, t
    s = [=====[
---@type MY_TYPE]=====]
    t = self.p:match(s)
    expect(t).is.NOT(nil)
    expect(t.types).equal({ "MY_TYPE" })

    s = [=====[
---@type MY_TYPE|OTHER_TYPE]=====]
    t = self.p:match(s)
    expect(t).is.NOT(nil)
    expect(t.types).equal({ "MY_TYPE", "OTHER_TYPE" })

    s = [=====[
---@type MY_TYPE|OTHER_TYPE @ COMMENT ]=====]
    t = self.p:match(s)
    expect(t).is.NOT(nil)
    expect(t:get_content(s)).is("COMMENT")

  end
})

_G.test_Type2 = MT:new({
  test_base = function ()
    local t = AD.At.Type()
    expect(t.__Class).is(AD.At.Type)
    expect(t).contains({
      min         = 1,
      max         = 0,
      content_min = 1,
      content_max = 0,
    })
  end,
  setup = function (self)
    self.p = __.chunk_init_p
      * AD.At.Type:get_complete_p()
  end,
  test = function (self)
    local s, t
    s = [=====[
---SHORT DESCRIPTION
---@type MY_TYPE|OTHER_TYPE]=====]
    t = self.p:match(s)
    expect(t).is.NOT(nil)
    expect(t:get_short_description(s)).is("SHORT DESCRIPTION")
    expect(t:get_long_description(s)).is("")

    s = [=====[
---SHORT DESCRIPTION
--[===[LONG DESCRIPTION]===]
---@type MY_TYPE|OTHER_TYPE]=====]
    t = self.p:match(s)
    expect(t).is.NOT(nil)
    expect(t:get_short_description(s)).is("SHORT DESCRIPTION")
    expect(t:get_long_description(s)).is("LONG DESCRIPTION")
  end
})

_G.test_Alias = MT:new({
  test_base = function ()
    local t = AD.At.Alias()
    expect(t.__Class).is(AD.At.Alias)
    expect(t).contains({
      min         = 1,
      max         = 0,
      content_min = 1,
      content_max = 0,
    })
  end,
  setup = function (self)
    self.p = __.chunk_init_p
      * AD.At.Alias:get_capture_p()
  end,
  test = function (self)
    local s, t
    s = [=====[
---@alias NEW_NAME TYPE ]=====]
    ---@type AD.At.Alias
    t = self.p:match(s)
    expect(t).contains({
      min         = 1,
      max         = 24,
      content_min = 1,
      content_max = 0,
      name        = "NEW_NAME",
      types       = { "TYPE" },
    })

    s = [=====[
---@alias NEW_NAME TYPE | OTHER_TYPE ]=====]
    t = self.p:match(s)
    expect(t).contains({
      min         = 1,
      max         = 37,
      content_min = 1,
      content_max = 0,
      name        = "NEW_NAME",
      types       = { "TYPE", "OTHER_TYPE" },
    })

    ----5----0----5----0----5----0----5----0----5----|
    s = [=====[
---@alias     NAME TYPE @ SOME   COMMENT]=====]
    t = self.p:match(s)
    expect(t).contains({
      min         = 1,
      max         = 40,
      content_min = 27,
      content_max = 40,
      name        = "NAME",
      types       = { "TYPE" },
    })
    expect(t:get_comment(s)).is("SOME   COMMENT")

--[[
  at_match_p(self.KEY) * (
  Ct(
      chunk_begin_p
    * Cg(identifier_p, "name")
    * white_p^1
    * named_types_p
    * capture_comment_p
    * chunk_end_p
  )
  / function (at)
      return self(at)
    end
  + error_annotation_p
)
    


]]
----5----0----5----0----5----0----5----0----5----|
    s = [=====[
---@alias     NAME TYPE @ SOME   COMMENT         
    SUITE                                        ]=====]
    t = self.p:match(s)
    expect(t).contains({
      min         = 1,
      max         = 50,
      content_min = 27,
      content_max = 40,
      name        = "NAME",
      types       = { "TYPE" },
    })
    expect(t:get_comment(s)).is("SOME   COMMENT")
  end
})

_G.test_Param = MT:new({
  test_base = function ()
    local t = AD.At.Param()
    expect(t.__Class).is(AD.At.Param)
    expect(t).contains({
      min         = 1,
      max         = 0,
      content_min = 1,
      content_max = 0,
    })
  end,
  setup = function (self)
    self.p = __.chunk_init_p
      * AD.At.Param:get_capture_p()
  end,
  test = function (self)
    local s, t
    ----5----0----5----0----5----0----5----0----5----|
    s = [=====[
---@param NAME TYPE]=====]
    t = self.p:match(s)
    expect(t).contains({
      min         = 1,
      max         = 19,
      content_min = 1,
      content_max = 0,
      name        = "NAME",
      types       = { "TYPE" },
    })
    expect(t:get_comment(s)).is("")

    ----5----0----5----0----5----0----5----0----5----|
    s = [=====[
---@param NAME TYPE
]=====]
    t = self.p:match(s)
    expect(t).contains({
      min         = 1,
      max         = 20,
      content_min = 1,
      content_max = 0,
      name        = "NAME",
      types       = { "TYPE" },
    })
    expect(t:get_comment(s)).is("")

    ----5----0----5----0----5----0----5----0----5----|
    s = [=====[
---@param NAME TYPE  |  OTHER
]=====]
    t = self.p:match(s)
    expect(t).contains({
      min         = 1,
      max         = 30,
      content_min = 1,
      content_max = 0,
      name        = "NAME",
      types       = { "TYPE", "OTHER" },
    })
    expect(t:get_comment(s)).is("")

    ----5----0----5----0----5----0----5----0----5----|
    s = [=====[
---@param NAME TYPE  |  OTHER@  COMMENT
]=====]
    t = self.p:match(s)
    expect(t).contains({
      min         = 1,
      max         = 40,
      content_min = 33,
      content_max = 39,
      name        = "NAME",
      types       = { "TYPE", "OTHER" },
    })
    expect(t:get_comment(s)).is("COMMENT")
  end
})

_G.test_Return = MT:new({
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
  end
})

_G.test_Generic = MT:new({
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
  end
})

_G.test_Vararg = MT:new({
  test_base = function ()
    local t = AD.At.Vararg()
    expect(t.__Class).is(AD.At.Vararg)
    expect(t).contains({
      min         = 1,
      max         = 0,
      content_min = 1,
      content_max = 0,
    })
  end,
  setup = function (self)
    self.p = __.chunk_init_p
      * AD.At.Vararg:get_capture_p()
  end,
  test = function (self)
    local s, t
    ----5----0----5----0----5----0----5----0----5----0----5----|
    s = [=====[
---@vararg    TYPE_
]=====]
    t = self.p:match(s)
    expect(t).contains({
      min         = 1,
      max         = 20,
      content_min = 1,
      content_max = 0,
      types       = { "TYPE_" },
    })
    expect(t:get_comment(s)).is("")

----5----0----5----0----5----0----5----0----5----0----5----|
    s = [=====[
---@vararg    TYPE_|TYPE
]=====]
    t = self.p:match(s)
    expect(t).contains({
      min         = 1,
      max         = 25,
      content_min = 1,
      content_max = 0,
      types       = { "TYPE_", "TYPE" },
    })
    expect(t:get_comment(s)).is("")

----5----0----5----0----5----0----5----0----5----0----5----|
    s = [=====[
---@vararg    TYPE_|TYPE@CMT_
]=====]
    t = self.p:match(s)
    expect(t).contains({
      min         = 1,
      max         = 30,
      content_min = 26,
      content_max = 29,
      types       = { "TYPE_", "TYPE" },
    })
    expect(t:get_content(s)).is("CMT_")
  end
})

_G.test_Module = MT:new({
  test_base = function ()
    local t = AD.At.Module()
    expect(t.__Class).is(AD.At.Module)
    expect(t).contains({
      min         = 1,
      max         = 0,
      content_min = 1,
      content_max = 0,
    })
  end,
  setup = function (self)
    self.p = __.chunk_init_p
      * AD.At.Module:get_capture_p()
  end,
  test = function (self)
    local s, t
----5----0----5----0----5----0----5----0----5----0----5----|
    s = [=====[
---   @module name_
]=====]
    ---@type AD.At.Module
    t = self.p:match(s)
    expect(t).contains({
      min         = 1,
      max         = 20,
      content_min = 1,
      content_max = 0,
      name        = "name_",
    })
    expect(t:get_comment(s)).is("")

----5----0----5----0----5----0----5----0----5----0----5----|
    s = [=====[
---   @module name_ @ COMMENT
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
  end
})

_G.test_Function = {
  setup = function (self)
    self.p =
        __.chunk_init_p
      * AD.At.Function:get_capture_p()
  end,
  test = function (self)
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
}

_G.test_Break = MT:new({
  setup = function (self)
    self.p =
        __.chunk_init_p
      * AD.Break:get_capture_p()
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

_G.test_Global = MT:new({
  setup = function (self)
    self.p =
        __.chunk_init_p
      * AD.At.Global:get_capture_p()
  end,
  test = function (self)
---5----0----5----0----5----0----5----0----5----0----5----
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
})

os.exit( LU.LuaUnit.run() )