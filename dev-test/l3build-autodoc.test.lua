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

local expect  = dofile("./l3b-expect.lua")

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

local P       = lpeg.P

assert(AD.Info)
expect(AD.Info.__Class).is(AD.Info)

local t, p, f, s

p = __.white_p
expect(p).is.NOT(nil)

expect(p:match("")).is(nil)
expect(p:match(" ")).is(2)
expect(p:match("\t")).is(2)
expect(p:match("\n")).is(nil)
expect(p:match("a")).is(nil)

p = __.black_p
expect(p).is.NOT(nil)

expect(p:match("")).is(nil)
expect(p:match(" ")).is(nil)
expect(p:match("\t")).is(nil)
expect(p:match("\n")).is(nil)
expect(p:match("a")).is(2)

p = __.eol_p
expect(p).is.NOT(nil)

expect(p:match("")).is(1)
expect(p:match("\n")).is(2)
expect(p:match(" \n  ")).is(1)
expect(p:match("    ", 2)).is(2)
expect(p:match(" \n  ", 2)).is(3)
expect(p:match("\n   ")).is(2)

p = __.variable_p
expect(p).is.NOT(nil)

expect(p:match(" ")).is(nil)
expect(p:match("abc")).is(4)
expect(p:match("2bc")).is(nil)

p = __.identifier_p
expect(p).is.NOT(nil)

expect(p:match(" ")).is(nil)
expect(p:match("abc")).is(4)
expect(p:match("2bc")).is(nil)
expect(p:match("abc.")).is(4)
expect(p:match("abc._")).is(6)

p = __.special_begin_p
expect(p).is.NOT(nil)

expect(p:match("-")).is(nil)
expect(p:match("--")).is(nil)
expect(p:match("---")).is(4)
expect(p:match("----")).is(nil)
expect(p:match("  -")).is(nil)
expect(p:match("  --")).is(nil)
expect(p:match("  ---")).is(6)
expect(p:match("  ---  ")).is(8)

p = __.colon_p
expect(p).is.NOT(nil)
expect(p:match("abc")).is(nil)
expect(p:match(" : abc")).is(4)

p = __.comma_p
expect(p).is.NOT(nil)

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

p = __.lua_type_p
expect(p).is.NOT(nil)

expect(p:match("abc")).is(4)
expect(p:match("abc<")).is(4)
expect(p:match("foo")).is(4)
expect(p:match("bar")).is(4)
expect(p:match("bar[]")).is(6)

expect(p:match("table<k,v>")).is(11)
expect(p:match("table<k,v>[]")).is(13)
expect(p:match("fun")).is(4)
expect(p:match("fun()")).is(6)
expect(p:match("fun(... : string[])")).is(20)
expect(p:match("fun(... : bar)")).is(15)
expect(p:match("fun(foo : bar)")).is(15)
expect(p:match("fun(foo : bar, ...: bar)")).is(25)
expect(p:match("fun(foo : bar, foo: bar, ...: bar)")).is(35)
expect(p:match("fun():foo")).is(10)
expect(p:match("fun():foo, bar")).is(15)

p = __.named_types_p
expect(p).is.NOT(nil)

p = lpeg.Ct(p)
expect(p:match("foo").types[1]).is("foo")
expect(p:match("foo|chi").types[2]).is("chi")
expect(p:match("foo|chi|mee").types[3]).is("mee")

expect(lpeg.C("X"):match("X")).is("X")

---@type AD.ShortLiteral
t = AD.ShortLiteral()
expect(t.__Class).is(AD.ShortLiteral)
expect(t.min).is(1)
expect(t.max).is(0)
expect(t.content_min).is(1)
expect(t.content_max).is(0)

local tag_del = {}

p = lpeg.Ct(
    __.white_p^0
  * lpeg.Cg(lpeg.S([['"]]), tag_del)
  * __.named_pos_p("content_min")
  * __.chunk_begin_p
  * lpeg.Cg(lpeg.Cmt(
    lpeg.Cb(tag_del),
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
  -- * __.chunk_end_p
  -- * lpeg.Cg(P(0), tag_del)
) / function (t)
  return AD.ShortLiteral(t)
end

expect(lpeg.Ct(__.chunk_init_p):match("")).equals({
  min = 1,
  max = 0,
})

s = '"234"  \n  '
p = __.chunk_init_p
  * __.chunk_begin_p
  * P(1)
  * __.chunk_end_p

t = lpeg.Ct(p):match(s)

expect(t).equals({
  min = 1,
  max = 1,
  code_before = {
    min = 1,
    max = 0,
  }
})

p = AD.ShortLiteral:get_capture_p()
expect(p).is.NOT(nil)

p = __.chunk_init_p * p

s = '"234"  \n  '
---@type AD.ShortLiteral
t = p:match(s)
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

expect(t.__Class).is(AD.ShortLiteral)
expect(t.min).is(1)
expect(t.max).is(8)
expect(t.content_min).is(2)
expect(t.content_max).is(4)

s = "'234'  \n  "
t = p:match(s)
expect(t.__Class).is(AD.ShortLiteral)
expect(t.min).is(1)
expect(t.max).is(8)
expect(t.content_min).is(2)
expect(t.content_max).is(4)

p = AD.LongLiteral:get_capture_p()
expect(p).is.NOT(nil)

p = __.chunk_init_p * p
s = '[[345]]  \n  '
t = p:match(s)
expect(t.__Class).is(AD.LongLiteral)
expect(t.min).is(1)
expect(t.max).is(10)
expect(t.level).is(0)
expect(t.content_min).is(3)
expect(t.content_max).is(5)

t = p:match('[===[678]===]  \n  ')
expect(t.__Class).is(AD.LongLiteral)
expect(t.min).is(1)
expect(t.max).is(16)
expect(t.level).is(3)
expect(t.content_min).is(6)
expect(t.content_max).is(8)

assert(AD.LineComment)
p = AD.LineComment:get_capture_p()
expect(p).is.NOT(nil)

p = __.chunk_init_p * p

---@type AD.LineComment
t = p:match('-  \n  ')
expect(t).is(nil)
t = p:match('---  \n  ')
expect(t).is(nil)
t = p:match('---  \n  ', 2)
expect(t).is(nil)

t = p:match('--  ')
expect(t.__Class).is(AD.LineComment)
expect(t.min).is(1)
expect(t.max).is(4)
expect(t.content_min).is(5)
expect(t.content_max).is(4)

t = p:match('--  \n  ')
expect(t.__Class).is(AD.LineComment)
expect(t.min).is(1)
expect(t.max).is(5)
expect(t.content_min).is(5)
expect(t.content_max).is(4)

t = p:match('----------')
expect(t.__Class).is(AD.LineComment)
expect(t.min).is(1)
expect(t.max).is(10)
expect(t.content_min).is(11)
expect(t.content_max).is(10)

t = p:match('-- 456 89A \n  ')
expect(t.__Class).is(AD.LineComment)
expect(t.min).is(1)
expect(t.max).is(12)
expect(t.content_min).is(4)
expect(t.content_max).is(10)

assert(AD.LongComment)
p = AD.LongComment:get_capture_p()
expect(p).is.NOT(nil)

p = __.chunk_init_p * p

---@type AD.LongComment
t = p:match('--  \n  ')
expect(t).is(nil)

t = p:match('--[[56 89A]]')
expect(t.__Class).is(AD.LongComment)
expect(t.min).is(1)
expect(t.max).is(12)
expect(t.content_min).is(5)
expect(t.content_max).is(10)

t = p:match('--[[\n6 89A]]')
expect(t.__Class).is(AD.LongComment)
expect(t.min).is(1)
expect(t.max).is(12)
expect(t.content_min).is(6)
expect(t.content_max).is(10)

t = p:match('--[[\n  8\nA  ]]')
expect(t.__Class).is(AD.LongComment)
expect(t.min).is(1)
expect(t.max).is(14)
expect(t.content_min).is(6)
expect(t.content_max).is(10)

t = p:match('--[==[78]=] \n ]==] ')
expect(t.__Class).is(AD.LongComment)
expect(t.min).is(1)
expect(t.max).is(19)
expect(t.content_min).is(7)
expect(t.content_max).is(13)

p = AD.LineDoc:get_capture_p()
expect(p).is.NOT(nil)

p = __.chunk_init_p * p

t = p:match('-- ')
expect(t).is(nil)
t = p:match('---- ')
expect(t).is(nil)
t = p:match('---- ', 1)
expect(t).is(nil)

t = p:match('---')
expect(t.__Class).is(AD.LineDoc)
expect(t.min).is(1)
expect(t.max).is(3)
expect(t.content_min).is(4)
expect(t.content_max).is(3)

t = p:match('---456789A')
expect(t.__Class).is(AD.LineDoc)
expect(t.min).is(1)
expect(t.max).is(10)
expect(t.content_min).is(4)
expect(t.content_max).is(10)

t = p:match('--- 56 89 ')
expect(t.__Class).is(AD.LineDoc)
expect(t.min).is(1)
expect(t.max).is(10)
expect(t.content_min).is(5)
expect(t.content_max).is(9)

t = p:match('--- 56 89 \n')
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
expect(p:match(s,  1).max).is(10)
expect(p:match(s, 11).max).is(20)
expect(p:match(s, 21).max).is(30)
expect((p^2):match(s, 1)).is.NOT(nil)
expect((p^2):match(s, 11)).is.NOT(nil)

p = AD.Description:get_capture_p()
expect(p).is.NOT(nil)

p = __.chunk_init_p * p

t = p:match("--")
expect(t).is(nil)

---@type AD.Description
t = p:match("---")
expect(t.__Class).is(AD.Description)
expect(t.short.__Class).is(AD.LineDoc)
expect(#t.long).is(0)
expect(t.min).is(1)
expect(t.max).is(3)

t = p:match("---\n")
expect(t.max).is(4)

t = p:match("---\ns")
expect(t.max).is(4)

t = p:match("---\n\n")
expect(t.max).is(4)

t = p:match("-- \n---")
expect(t).is(nil)

t = p:match("---\n---")

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
t = p:match(s)
expect(t.__Class).is(AD.Description)
expect(t.short.__Class).is(AD.LineDoc)
expect(#t.long).is(0)
expect(t.max).is(11)

s = [=====[
---
--[===[]===]
]=====]
t = p:match(s)
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
t = p:match(s)
expect(t.__Class).is(AD.Description)
expect(t.short.__Class).is(AD.LineDoc)
expect(#t.long).is(2)
expect(t.long[1].__Class).is(AD.LongDoc)
expect(t.long[2].__Class).is(AD.LineDoc)
expect(t.max).is(24)

p = AD.Description:get_capture_p()
expect(p).is.NOT(nil)

p = __.chunk_init_p * p

expect(p:match("---")).is.NOT(nil)
expect(p:match("---\n---")).is.NOT(nil)
expect(p:match("---\n--[===[]===]")).is.NOT(nil)

p = AD.At.Field:get_capture_p()
expect(p).is.NOT(nil)

p = __.chunk_init_p * p

expect(function () p:match("--- @field public foo") end).error()

expect(function () p:match("--- @field public foo \n bar") end).error()

---@type AD.At.Field
t = p:match("--- @field public f21 b25")

expect(lpeg.Ct(__.named_types_p):match("--- @field public f21 b25", 23)).equals({
  types = { "b25" },
})

expect(t.__Class).is(AD.At.Field)
expect(t.min).is(1)
expect(t.max).is(25)
expect(t.visibility).is("public")
expect(t.name).is("f21")
expect(t.types[1]).is("b25")

t = p:match("--- @field private f22 b26\n   ")
expect(t.__Class).is(AD.At.Field)
expect(t.visibility).is("private")
expect(t.name).is("f22")
expect(t.types).equal({ "b26" })
expect(t.min).is(1)
expect(t.max).is(27)

----5----0   ----5----0----5----0----5----0----5----0----5
t = p:match("--- @field private f22 b26 @ commentai40   ")
expect(t.__Class).is(AD.At.Field)
expect(t.visibility).is("private")
expect(t.name).is("f22")
expect(t.types).equal({ "b26" })
expect(t.min).is(1)
expect(t.max).is(43)
expect(t.content_min).is(30)
expect(t.content_max).is(40)

t = p:match("--- @field private f22 b26\n   ")
expect(t.__Class).is(AD.At.Field)
expect(t.visibility).is("private")
expect(t.name).is("f22")
expect(t.types).equal({ "b26" })
expect(t.min).is(1)
expect(t.max).is(27)

t = p:match("--- @field private f22 b26\n   ")
expect(t.__Class).is(AD.At.Field)
expect(t.visibility).is("private")
expect(t.name).is("f22")
expect(t.types).equal({ "b26" })
expect(t.min).is(1)
expect(t.max).is(27)

t = p:match("123456789--- @field private f22 b26\n   ", 10)
expect(t.__Class).is(AD.At.Field)
expect(t.visibility).is("private")
expect(t.name).is("f22")
expect(t.types).equal({ "b26" })
expect(t.min).is(10)
expect(t.max).is(36)

p = AD.At.See:get_capture_p()
expect(p).is.NOT(nil)

p = __.chunk_init_p * p

---@type AD.At.See
s = "---@see 9hat do you want of 30  "
t = p:match(s)
expect(t.__Class).is(AD.At.See)
expect(t.min).is(1)
expect(t.max).is(32)
expect(t.content_min).is(9)
expect(t.content_max).is(30)
expect(t:get_content(s)).is("9hat do you want of 30")

-- @class MY_TYPE[:PARENT_TYPE] [@comment]

p = AD.At.Class:get_capture_p()
expect(p).is.NOT(nil)

p = __.chunk_init_p * p

---@type AD.At.Class
t = p:match("---@class MY_TY17")

expect(t.__Class).is(AD.At.Class)
expect(t.min).is(1)
expect(t.max).is(17)
expect(t.parent).is(nil)
expect(t.content_min).is(1)
expect(t.content_max).is(0)

---@type AD.At.Class
t = p:match("---@class AY_TYPE: PARENT_TY30")
expect(t.__Class).is(AD.At.Class)
expect(t.min).is(1)
expect(t.max).is(30)
expect(t.parent).is("PARENT_TY30")
expect(t.content_min).is(1)
expect(t.content_max).is(0)

local tag_at = {}

p = __.chunk_init_p * lpeg.Cg(
  lpeg.Cmt(
      ( AD.Description:get_capture_p()
      + lpeg.Cc(AD.Description())
    )
    -- capture a raw class annotation:
    -- create an AD.At.Class instance
    -- capture it with the tag `tag_at`
    * AD.At.Class:get_capture_p(),
    function (_, i, desc, at)
      at.description = desc
      return i, at
    end
  ),
  tag_at
)
* ( AD.At.Field:get_complete_p()
* lpeg.Cb(tag_at)
/ function (at_field, at)
  table.insert(at.fields, at_field)
end
+   AD.At.See:get_complete_p()
* lpeg.Cb(tag_at)
/ function (at_see, at)
    at.see = at_see
  end
+ ( AD.LineComment:get_capture_p() + AD.LongComment:get_capture_p() )
* lpeg.Cb(tag_at)
/ function (ignore, at)
    table.insert(at.ignores, ignore)
  end
)^0
* lpeg.Cp()
* lpeg.Cb(tag_at)
/ function (max, at)
    at.max = max
    return at -- captured
  end

p = AD.At.Class:get_complete_p()
expect(p).is.NOT(nil)

p = __.chunk_init_p * p

----5----0----5----0----5----0----5----0----5----|
s = [[
---@class TYPE: PARENT @        COMMENT]]

---@type AD.At.Class
t = p:match(s)

---5----0----5----0----5----0----5----0----5----|
s = [[
---@class TYPE: PARENT @        COMMENT
---@field protected NAME TYPE @   OTHER]]

---@type AD.At.Class
t = p:match(s)
expect(t.__Class).is(AD.At.Class)
expect(t.min).is(1)
expect(t.max).is(80)
expect(t.name).is("TYPE")
expect(t.parent).is("PARENT")
expect(t:get_content(s)).is("COMMENT")

---@type AD.At.Field
t = (__.chunk_init_p * AD.At.Field:get_capture_p()):match(s, 41)
expect(t.__Class).is(AD.At.Field)
expect(t.min).is(41)
expect(t.max).is(79)
expect(t.visibility).is("protected")
expect(t.name).is("NAME")
expect(t.types).equal({ "TYPE" })
expect(t:get_content(s)).is("OTHER")

---@type AD.At.Class
t = p:match(s)
expect(t.__Class).is(AD.At.Class)
expect(t.min).is(1)
expect(t.max).is(80)
expect(t.parent).is("PARENT")
expect(t:get_content(s)).is("COMMENT")
expect(#t.fields).is(1)
expect(t.see).is(nil)
f = t.fields[1]
expect(f.name).is("NAME")
expect(f.types).equal({ "TYPE" })
expect(f:get_content(s)).is("OTHER")

---@type AD.At.Class
s = [[---@class MY_TYPE: PARENT_TYPE @ COMMENT
---SHORT DOC
---@field public NAME TYPE @ OTHER COMMENT]]
t = p:match(s)
expect(t.__Class).is(AD.At.Class)
expect(t.min).is(1)
expect(t.max).is(97)
expect(t.name).is("MY_TYPE")
expect(t.parent).is("PARENT_TYPE")
expect(t:get_content(s)).is("COMMENT")
expect(#t.fields).is(1)
expect(t.see).is(nil)
f = t.fields[1]
expect(f.name).is("NAME")
expect(f.types).equal({ "TYPE" })
expect(f:get_content(s)).is("OTHER COMMENT")
expect(f.description).is.NOT(nil)
expect(f:get_short_description(s)).is("SHORT DOC")
expect(f:get_long_description(s)).is("")

s = [=====[
---@class MY_TYPE: PARENT_TYPE @ COMMENT
---@field public NAME TYPE @ OTHER COMMENT
---SEE SHORT DESCRIPTION
--[===[SEE LONG DESCRIPTION]===]
---@see SEE
   foo bar]=====]
---@type AD.At.Class
t = p:match(s)
expect(t.__Class).is(AD.At.Class)
expect(t.min).is(1)
expect(t.max).is(155)
expect(t.name).is("MY_TYPE")
expect(t.parent).is("PARENT_TYPE")
expect(t:get_content(s)).is("COMMENT")
expect(#t.fields).is(1)
expect(t.see:get_short_description(s)).is("SEE SHORT DESCRIPTION")
expect(t.see:get_long_description(s)).is("SEE LONG DESCRIPTION")
f = t.fields[1]
expect(f.name).is("NAME")
expect(f.types).equal({ "TYPE" })
expect(f:get_content(s)).is("OTHER COMMENT")

p = AD.At.Type:get_capture_p()
expect(p).is.NOT(nil)

p = __.chunk_init_p * p

s = [=====[
---@type MY_TYPE]=====]
t = p:match(s)
expect(t).is.NOT(nil)
expect(t.types).equal({ "MY_TYPE" })

s = [=====[
---@type MY_TYPE|OTHER_TYPE]=====]
t = p:match(s)
expect(t).is.NOT(nil)
expect(t.types).equal({ "MY_TYPE", "OTHER_TYPE" })

s = [=====[
---@type MY_TYPE|OTHER_TYPE @ COMMENT ]=====]
t = p:match(s)
expect(t).is.NOT(nil)
expect(t:get_content(s)).is("COMMENT")

p = AD.At.Type:get_complete_p()
expect(p).is.NOT(nil)

p = __.chunk_init_p * p

s = [=====[
---SHORT DESCRIPTION
---@type MY_TYPE|OTHER_TYPE]=====]
t = p:match(s)
expect(t).is.NOT(nil)
expect(t:get_short_description(s)).is("SHORT DESCRIPTION")
expect(t:get_long_description(s)).is("")

s = [=====[
---SHORT DESCRIPTION
--[===[LONG DESCRIPTION]===]
---@type MY_TYPE|OTHER_TYPE]=====]
t = p:match(s)
expect(t).is.NOT(nil)
expect(t:get_short_description(s)).is("SHORT DESCRIPTION")
expect(t:get_long_description(s)).is("LONG DESCRIPTION")

p = AD.At.Alias:get_capture_p()
expect(p).is.NOT(nil)

p = __.chunk_init_p * p

s = [=====[
---@alias NEW_NAME TYPE ]=====]
---@type AD.At.Alias
t = p:match(s)
expect(t).is.NOT(nil)
expect(t.name).is("NEW_NAME")
expect(t.types).equal({ "TYPE" })

s = [=====[
---@alias NEW_NAME TYPE | OTHER_TYPE ]=====]
t = p:match(s)
expect(t).is.NOT(nil)
expect(t.name).is("NEW_NAME")
expect(t.types).equal({ "TYPE", "OTHER_TYPE" })

----5----0----5----0----5----0----5----0----5----|
s = [=====[
---@alias     NAME TYPE @ SOME   COMMENT]=====]
t = p:match(s)
expect(t).is.NOT(nil)
expect(t.name).is("NAME")
expect(t.types).equal({ "TYPE" })
expect(t:get_content(s)).is("SOME   COMMENT")
expect(t.min).is(1)
expect(t.max).is(40)

----5----0----5----0----5----0----5----0----5----|
s = [=====[
---@alias     NAME TYPE @ SOME   COMMENT         
     SUITE                                        ]=====]
t = p:match(s)
expect(t).is.NOT(nil)
expect(t.name).is("NAME")
expect(t.types).equal({ "TYPE" })
expect(t:get_content(s)).is("SOME   COMMENT")
expect(t.min).is(1)
expect(t.max).is(50)

p = AD.At.Param:get_capture_p()
expect(p).is.NOT(nil)

p = __.chunk_init_p * p

----5----0----5----0----5----0----5----0----5----|
s = [=====[
---@param NAME TYPE]=====]
t = p:match(s)
expect(t.name).is("NAME")
expect(t.types).equal({ "TYPE" })
expect(t:get_content(s)).is("")
expect(t.min).is(1)
expect(t.max).is(19)

----5----0----5----0----5----0----5----0----5----|
s = [=====[
---@param NAME TYPE
]=====]
t = p:match(s)
expect(t.name).is("NAME")
expect(t.types).equal({ "TYPE" })
expect(t:get_content(s)).is("")
expect(t.min).is(1)
expect(t.max).is(20)

----5----0----5----0----5----0----5----0----5----|
s = [=====[
---@param NAME TYPE  |  OTHER
]=====]
t = p:match(s)
expect(t.name).is("NAME")
expect(t.types).equal({ "TYPE", "OTHER" })
expect(t:get_content(s)).is("")
expect(t.min).is(1)
expect(t.max).is(30)

----5----0----5----0----5----0----5----0----5----|
s = [=====[
---@param NAME TYPE  |  OTHER@  COMMENT
]=====]
t = p:match(s)
expect(t.name).is("NAME")
expect(t.types).equal({ "TYPE", "OTHER" })
expect(t:get_content(s)).is("COMMENT")
expect(t.min).is(1)
expect(t.max).is(40)

p = AD.At.Return:get_capture_p()
expect(p).is.NOT(nil)

p = __.chunk_init_p * p

----5----0----5----0----5----0----5----0----5----|
s = [=====[
---   @return TYPE   |  OTHER @ COMMENT
]=====]
t = p:match(s)
expect(t.types).equal({ "TYPE", "OTHER" })
expect(t:get_content(s)).is("COMMENT")
expect(t.min).is(1)
expect(t.max).is(40)

p = AD.At.Generic:get_capture_p()
expect(p).is.NOT(nil)

p = __.chunk_init_p * p

s = [=====[
-- @generic T1 [: PARENT_TYPE] [, T2 [: PARENT_TYPE]]
]=====]

s = [=====[
---@generic T1
]=====]
---@type AD.At.Generic
t = p:match(s)
expect(t.type_1).is.equal.to("T1")
expect(t.parent_1).is(nil)
expect(t.type_2).is(nil)
expect(t.parent_2).is(nil)

s = [=====[
---@generic T1: PARENT_TYPE_1
]=====]
t = p:match(s)
expect(t.type_1).is.equal.to("T1")
expect(t.parent_1).is.equal.to("PARENT_TYPE_1")

s = [=====[
---@generic T1, T2
]=====]
t = p:match(s)
expect(t.type_1).is.equal.to("T1")
expect(t.parent_1).is(nil)
expect(t.type_2).is.equal.to("T2")
expect(t.parent_2).is(nil)

s = [=====[
---@generic T1 : PARENT_TYPE, T2
]=====]
t = p:match(s)
expect(t.type_1).is.equal.to("T1")
expect(t.parent_1).is("PARENT_TYPE")
expect(t.type_2).is.equal.to("T2")
expect(t.parent_2).is(nil)

s = [=====[
---@generic T1, T2 : PARENT_TYPE
]=====]
t = p:match(s)
expect(t.type_1).is.equal.to("T1")
expect(t.parent_1).is(nil)
expect(t.type_2).is.equal.to("T2")
expect(t.parent_2).is("PARENT_TYPE")

s = [=====[
---@generic T1 : PARENT_TYPE, T2 : PARENT_TYPE
]=====]
t = p:match(s)
expect(t.type_1).is.equal.to("T1")
expect(t.parent_1).is("PARENT_TYPE")
expect(t.type_2).is.equal.to("T2")
expect(t.parent_2).is("PARENT_TYPE")

----5----0----5----0----5----0----5----0----5----0----5----|
s = [=====[
---@generic   T1 : PARENT_TYPE, T2 : PARENT_TYPE @  COMMENT
]=====]
t = p:match(s)
expect(t.type_1).is.equal.to("T1")
expect(t.parent_1).is("PARENT_TYPE")
expect(t.type_2).is.equal.to("T2")
expect(t.parent_2).is("PARENT_TYPE")
expect(t:get_content(s)).is("COMMENT")
expect(t.min).is(1)
expect(t.max).is(60)

p = AD.At.Vararg:get_capture_p()
expect(p).is.NOT(nil)

p = __.chunk_init_p * p

s = [=====[
-- @vararg TYPE[|OTHER_TYPE] [ @ comment ]
]=====]

----5----0----5----0----5----0----5----0----5----0----5----|
s = [=====[
---@vararg    TYPE_
]=====]
t = p:match(s)
expect(t.types).equals({ "TYPE_" })
expect(t:get_content(s)).is("")
expect(t.min).is(1)
expect(t.max).is(20)

----5----0----5----0----5----0----5----0----5----0----5----|
s = [=====[
---@vararg    TYPE_|TYPE
]=====]
t = p:match(s)
expect(t.types).equals({ "TYPE_", "TYPE" })
expect(t:get_content(s)).is("")
expect(t.min).is(1)
expect(t.max).is(25)

----5----0----5----0----5----0----5----0----5----0----5----|
s = [=====[
---@vararg    TYPE_|TYPE@CMT_
]=====]
t = p:match(s)
expect(t.types).equals({ "TYPE_", "TYPE" })
expect(t:get_content(s)).is("CMT_")
expect(t.min).is(1)
expect(t.max).is(30)

p = AD.At.Module.NAME_p
expect(p).is.NOT(nil)

assert(p:match("abc"))


p = AD.At.Module:get_capture_p()
expect(p).is.NOT(nil)

p = __.chunk_init_p * p

----5----0----5----0----5----0----5----0----5----0----5----|
s = [=====[
---   @module name_
]=====]
---@type AD.At.Module
t = p:match(s)
expect(t.name).equals("name_")
expect(t:get_content(s)).is("")
expect(t.min).is(1)
expect(t.max).is(20)

----5----0----5----0----5----0----5----0----5----0----5----|
s = [=====[
---   @module name_ @ COMMENT
]=====]
t = p:match(s)
expect(t.name).equals("name_")
expect(t:get_content(s)).is("COMMENT")
expect(t.min).is(1)
expect(t.max).is(30)

p = AD.At.Global:get_capture_p()
expect(p).is.NOT(nil)

p = __.chunk_init_p * p

----5----0----5----0----5----0----5----0----5----0----5----|
s = [=====[
---  @global  name_
]=====]
---@type AD.At.Global
t = p:match(s)
expect(t.name).equals("name_")
expect(t:get_content(s)).is("")
expect(t.min).is(1)
expect(t.max).is(20)

----5----0----5----0----5----0----5----0----5----0----5----|
s = [=====[
---  @global  name_ @ COMMENT
]=====]
---@type AD.At.Global
t = p:match(s)
expect(t.name).equals("name_")
expect(t:get_content(s)).is("COMMENT")
expect(t.min).is(1)
expect(t.max).is(30)

p = AD.Break:get_capture_p()
expect(p).is.NOT(nil)

p = __.chunk_init_p * p

expect(p:match("")).is(nil)
expect(p:match("\n").max).is(1)
expect(p:match(" \n ").max).is(3)
expect(p:match(" \n \n").max).is(4)


p = AD.At.Function:get_capture_p()
expect(p).is.NOT(nil)

p = __.chunk_init_p * p

----5----0----5----0----5----0----5----0----5----0----5----|
s = [=====[
---@function  name_
]=====]
---@type AD.At.Function
t = p:match(s)
expect(t.name).equals("name_")
expect(t:get_content(s)).is("")
expect(t.min).is(1)
expect(t.max).is(20)

----5----0----5----0----5----0----5----0----5----0----5----|
s = [=====[
---@function  name_ @ COMMENT
]=====]
t = p:match(s)
expect(t.name).equals("name_")
expect(t:get_content(s)).is("COMMENT")
expect(t.min).is(1)
expect(t.max).is(30)



print("DONE")
