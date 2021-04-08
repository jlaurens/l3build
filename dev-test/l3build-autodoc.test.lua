#!/usr/bin/env texlua

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

local expect = dofile("./l3b-expect.lua")

local lpeg    = require("lpeg")

print("POC")

local p_one = lpeg.Cg(lpeg.P(1), "one")
local p_two = lpeg.Cg(lpeg.P(1), "two")
local t = lpeg.Ct(p_one*p_two):match("12")
print(t.one)
print(t.two)

os.exit()


local P       = lpeg.P

local write   = io.write

function pretty_print(tt, indent, done)
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

p = __.white_and_eol_p
expect(p).is.NOT(nil)

expect(p:match("")).is(1)
expect(p:match("\n")).is(2)
expect(p:match(" ")).is(2)
expect(p:match(" \n")).is(3)
expect(p:match("\n ")).is(2)
expect(p:match(" \n ")).is(3)
expect(p:match("    ")).is(5)
expect(p:match("    ", 2)).is(5)
expect(p:match(" \n  ")).is(3)
expect(p:match(" \n  ", 2)).is(3)
expect(p:match("\n   ")).is(2)

p = __.module_name_p
expect(p).is.NOT(nil)

assert(p:match("abc"))

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

p = __.capture_text_p
expect(p).is.NOT(nil)

expect({ p:match("abc") }).equal({ 1, 4 })
expect({ p:match("  abc  ") }).equal({ 3, 6 })
expect({ p:match("  abc  \n c") }).equal({ 3, 6 })
expect((p*P("\n")):match("  abc  \n c")).is.NOT(nil)

p = __.code_p
expect(p).is.NOT(nil)

expect(p:match("abc")).is(2)
expect(p:match("'")).is(nil)
expect(p:match('"')).is(nil)
expect(p:match("[[")).is(nil)
expect(p:match("-")).is(2)
expect(p:match("--")).is(nil)

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

p = __.capture_comment_and_eol_p
expect(p).is.NOT(nil)

--   ----5----0 --- -5----0----5----0----5----0----5----|
s = "  @ foo  \n  \n"
t = { p:match("  @ foo  \n  \n") }
expect(t).equal({ "foo", 8 })

expect(p:match("    foo  \n  \n")).is(nil)

t = { p:match("         \n  \n") }
expect(t).equal({ nil, 1 })

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

p = __.capture_types_p
expect(p).is.NOT(nil)

expect(p:match("foo")[1]).is("foo")
expect(p:match("foo|chi")[2]).is("chi")
expect(p:match("foo|chi|mee")[3]).is("mee")

expect(lpeg.C("X"):match("X")).is("X")

p = __.no_captures_p(lpeg.C("X"))
expect(p).is.NOT(nil)

expect(p:match("X")).is(2)

---@type AD.ShortLiteral
t = AD.ShortLiteral()
expect(t.__Class).is(AD.ShortLiteral)
expect(t.min).is(0)
expect(t.max).is(-1)
expect(t.after).is(0)

p = __.short_literal_p
expect(p).is.NOT(nil)

---@type AD.ShortLiteral
t = p:match("'234'  \n  ")
expect(t.__Class).is(AD.ShortLiteral)
expect(t.min).is(2)
expect(t.max).is(4)
expect(t.after).is(9)

t = p:match('"234"  \n  ')
expect(t.__Class).is(AD.ShortLiteral)
expect(t.min).is(2)
expect(t.max).is(4)
expect(t.after).is(9)

p = __.long_literal_p
expect(p).is.NOT(nil)

t = p:match('[[345]]  \n  ')
expect(t.__Class).is(AD.LongLiteral)
expect(t.min).is(3)
expect(t.max).is(5)
expect(t.level).is(0)
expect(t.after).is(11)

t = p:match('[===[678]===]  \n  ')
expect(t.__Class).is(AD.LongLiteral)
expect(t.min).is(6)
expect(t.max).is(8)
expect(t.level).is(3)
expect(t.after).is(17)

assert(AD.LineComment)
p = __.line_comment_p
expect(p).is.NOT(nil)

---@type AD.LineComment
t = p:match('-  \n  ')
expect(t).is(nil)
t = p:match('---  \n  ')
expect(t).is(nil)
t = p:match('---  \n  ', 2)
expect(t).is(nil)

t = p:match('--  \n  ')
expect(t.__Class).is(AD.LineComment)
expect(t.min).is(5)
expect(t.max).is(4)
expect(t.after).is(6)

t = p:match('----------')
expect(t.__Class).is(AD.LineComment)
expect(t.min).is(11)
expect(t.max).is(10)
expect(t.after).is(11)

t = p:match('-- 456 89f \n  ')
expect(t.__Class).is(AD.LineComment)
expect(t.min).is(4)
expect(t.max).is(10)
expect(t.after).is(13)

assert(AD.LongComment)
p = __.long_comment_p
expect(p).is.NOT(nil)

---@type AD.LongComment
t = p:match('--  \n  ')
expect(t).is(nil)

t = __.long_comment_p:match('--[[56 89f]]')
expect(t.__Class).is(AD.LongComment)
expect(t.min).is(5)
expect(t.max).is(10)
expect(t.after).is(13)

t = p:match('--[[\n6 89f]]')
expect(t.__Class).is(AD.LongComment)
expect(t.min).is(6)
expect(t.max).is(10)
expect(t.after).is(13)

t = p:match('--[[\n  8\nf  ]]')
expect(t.__Class).is(AD.LongComment)
expect(t.min).is(8)
expect(t.max).is(10)
expect(t.after).is(15)

t = p:match('--[==[78]=] \n ]==] ')
expect(t.__Class).is(AD.LongComment)
expect(t.min).is(7)
expect(t.max).is(11)
expect(t.after).is(20)

p = __.capture_doc_p
expect(p).is.NOT(nil)

t = p:match('-- ')
expect(t).is(nil)
t = p:match('---- ')
expect(t).is(nil)
t = p:match('---- ', 1)
expect(t).is(nil)

t = p:match('---456789A')
expect(t.__Class).is(AD.Doc)
expect(t.min).is(4)
expect(t.max).is(10)
expect(t.after).is(11)

t = p:match('--- 56 89 ')
expect(t.__Class).is(AD.Doc)
expect(t.min).is(5)
expect(t.max).is(9)
expect(t.after).is(11)

s = [=====[
---456789
---456789
---456789
]=====]
expect(p:match(s,  1).after).is(11)
expect(p:match(s, 11).after).is(21)
expect(p:match(s, 21).after).is(31)
expect((p^2):match(s, 1)).is.NOT(nil)
expect((p^2):match(s, 11)).is.NOT(nil)



p = __.capture_description_long_p
expect(p).is.NOT(nil)

s = [=====[
---
--[===[]===]
]=====]
expect(p:match(s, 1)).is.NOT(nil)
expect(p:match(s, 2)).is(nil)
expect(p:match(s, 5)).is.NOT(nil)

p = __.capture_description_p
expect(p).is.NOT(nil)

t = p:match("--")
expect(t).is(nil)

---@type AD.Description
t = p:match("---")
expect(t.__Class).is(AD.Description)
expect(t.short.__Class).is(AD.Doc)
expect(#t.long).is(0)
expect(t.after).is(4)

t = p:match("---\n")
expect(t.after).is(5)

t = p:match("---\ns")
expect(t.after).is(5)

t = p:match("---\n\n")
expect(t.after).is(5)

t = p:match("-- \n---")
expect(t.__Class).is(AD.Description)
expect(t.short.__Class).is(AD.Doc)
expect(#t.long).is(0)
expect(t.after).is(8)

t = p:match("---\n---")
expect(t.__Class).is(AD.Description)
expect(t.short.__Class).is(AD.Doc)
expect(#t.long).is(1)
expect(t.long[1].__Class).is(AD.Doc)
expect(t.after).is(8)

s = [=====[
---
--[[]]
]=====]
t = p:match(s)
expect(t.__Class).is(AD.Description)
expect(t.short.__Class).is(AD.Doc)
expect(#t.long).is(0)
expect(t.after).is(12)

s = [=====[
---
--[===[]===]
]=====]
t = p:match(s)
expect(t.__Class).is(AD.Description)
expect(t.short.__Class).is(AD.Doc)
expect(#t.long).is(1)
expect(t.long[1].__Class).is(AD.LongComment)
expect(t.after).is(18)

s = [=====[
---
--[===[]===]
--
---
s   s
]=====]
t = p:match(s)
expect(t.__Class).is(AD.Description)
expect(t.short.__Class).is(AD.Doc)
expect(#t.long).is(2)
expect(t.long[1].__Class).is(AD.LongComment)
expect(t.long[2].__Class).is(AD.Doc)
expect(t.after).is(25)

p = __.capture_description_p
expect(p).is.NOT(nil)

expect(p:match("---")).is.NOT(nil)
expect(p:match("---\n---")).is.NOT(nil)
expect(p:match("---\n--[===[]===]")).is.NOT(nil)

p = __.capture_comment_and_eol_p
expect(p).is.NOT(nil)

p = __.capture_at_field_p
expect(p).is.NOT(nil)

expect(p:match("--- @field public foo \n bar")).is(nil)

---@type AD.AtField
t = p:match("--- @field public foo bar")

expect(t.__Class).is(AD.AtField)

expect(t.description.__Class).is(AD.Description)
expect(t.min).is(12)
expect(t.max).is(25)
expect(t.after).is(26)
expect(t.name).is("foo")
expect(t.visibility).is("public")
expect(t.types[1]).is("bar")

t = p:match("--- @field private foo bar\n   ")
expect(t.__Class).is(AD.AtField)
expect(t.visibility).is("private")
expect(t.types).equal({ "bar" })
expect(t.min).is(12)
expect(t.max).is(26)
expect(t.after).is(28)

----5----0   ----5----0----5----0----5----0----5----0----5
t = p:match("--- @field private foo bar @ commentaire   ")
expect(t.__Class).is(AD.AtField)
expect(t.visibility).is("private")
expect(t.types).equal({ "bar" })
expect(t.min).is(12)
expect(t.max).is(40)
expect(t.after).is(44)
expect(t.comment).is("commentaire")

t = p:match("--- @field private foo bar\n   ")
expect(t.__Class).is(AD.AtField)
expect(t.visibility).is("private")
expect(t.types).equal({ "bar" })
expect(t.min).is(22)
expect(t.max).is(36)
expect(t.after).is(38)

t = p:match("--- @field private foo bar\n   ")
expect(t.__Class).is(AD.AtField)
expect(t.visibility).is("private")
expect(t.types).equal({ "bar" })
expect(t.min).is(32)
expect(t.max).is(46)
expect(t.after).is(48)

p = __.capture_at_see_p
expect(p).is.NOT(nil)

---@type AD.AtSee
t = p:match("---@see what do you want of me  ")
expect(t.__Class).is(AD.AtSee)
expect(t.min).is(9)
expect(t.max).is(30)
expect(t.after).is(33)
expect(t.references).is("what do you want of me")

-- @class MY_TYPE[:PARENT_TYPE] [@comment]

p = __.capture_at_class_p
expect(p).is.NOT(nil)

---@type AD.Class
t = p:match("---@class MY_TYPE")
expect(t.__Class).is(AD.Class)
expect(t.min).is(11)
expect(t.max).is(17)
expect(t.after).is(18)
expect(t.parent).is(nil)
expect(t.comment).is(nil)

---@type AD.Class
t = p:match("---@class MY_TYPE: PARENT_TYPE")
expect(t.__Class).is(AD.Class)
expect(t.min).is(11)
expect(t.max).is(30)
expect(t.after).is(31)
expect(t.parent).is("PARENT_TYPE")
expect(t.comment).is(nil)


p = __.capture_class_p
expect(p).is.NOT(nil)

----5----0----5----0----5----0----5----0----5----|
s = [[
---@class TYPE: PARENT @        COMMENT
---@field protected NAME TYPE @   OTHER]]

---@type AD.AtClass
t = __.capture_class_p:match(s)
expect(t.__Class).is(AD.AtClass)
expect(t.min).is(11)
expect(t.max).is(39)
expect(t.after).is(41)
expect(t.parent).is("PARENT")
expect(t.comment).is("COMMENT")
---@type AD.AtField
t = __.capture_field_p:match(s, 41)
expect(t.__Class).is(AD.AtField)
expect(t.min).is(51)
expect(t.max).is(79)
expect(t.after).is(80)
expect(t.visibility).is("protected")
expect(t.name).is("NAME")
expect(t.types).equal({ "TYPE" })
expect(t.comment).is("OTHER")

---@type AD.Class
t = p:match(s)
expect(t.__Class).is(AD.Class)
expect(t.min).is(11)
expect(t.max).is(39)
expect(t.after).is(80)
expect(t.parent).is("PARENT")
expect(t.comment).is("COMMENT")
expect(#t.fields).is(1)
expect(t.see).is(nil)
expect(t.black_code).is(0)
f = t.fields[1]
expect(f.name).is("NAME")
expect(f.types).equal({ "TYPE" })
expect(f.comment).is("OTHER")

---@type AD.Class
t = p:match([[---@class MY_TYPE: PARENT_TYPE @ COMMENT
---SHORT DOC
---@field public NAME TYPE @ OTHER COMMENT]])
expect(t.__Class).is(AD.Class)
expect(t.min).is(11)
expect(t.max).is(40)
expect(t.after).is(97)
expect(t.parent).is("PARENT_TYPE")
expect(t.comment).is("COMMENT")
expect(#t.fields).is(1)
expect(t.see).is(nil)
expect(t.black_code).is(0)
f = t.fields[1]
expect(f.name).is("NAME")
expect(f.types).equal({ "TYPE" })
expect(f.comment).is("OTHER COMMENT")
expect(f.description).is.NOT(nil)
expect(f:get_short_description()).is("SHORT DOC")
expect(f:get_long_description()).is("")

s = [=====[
---@class MY_TYPE: PARENT_TYPE @ COMMENT
---@field public NAME TYPE @ OTHER COMMENT
---SEE SHORT DESCRIPTION
--[===[SEE LONG DESCRIPTION]===]
---@see SEE
   foo bar]=====]
---@type AD.Class
t = p:match(s)
expect(t.__Class).is(AD.Class)
expect(t.min).is(11)
expect(t.max).is(40)
expect(t.after).is(165)
expect(t.parent).is("PARENT_TYPE")
expect(t.comment).is("COMMENT")
expect(#t.fields).is(1)
expect(t.see:get_short_description()).is("SEE SHORT DESCRIPTION")
expect(t.see:get_long_description()).is("SEE LONG DESCRIPTION")
expect(t.black_code).is(158)
f = t.fields[1]
expect(f.name).is("NAME")
expect(f.types).equal({ "TYPE" })
expect(f.comment).is("OTHER COMMENT")

p = __.capture_type_p
expect(p).is.NOT(nil)

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
expect(t.comment).is("COMMENT")

s = [=====[
---SHORT DESCRIPTION
---@type MY_TYPE|OTHER_TYPE]=====]
t = p:match(s)
expect(t).is.NOT(nil)
expect(t:get_short_description()).is("SHORT DESCRIPTION")
expect(t:get_long_description()).is("")

s = [=====[
---SHORT DESCRIPTION
--[===[LONG DESCRIPTION]===]
---@type MY_TYPE|OTHER_TYPE]=====]
t = p:match(s)
expect(t).is.NOT(nil)
expect(t:get_short_description()).is("SHORT DESCRIPTION")
expect(t:get_long_description()).is("LONG DESCRIPTION")

p = __.alias_p
expect(p).is.NOT(nil)

s = [=====[
---@alias NEW_NAME TYPE ]=====]
---@type AD.AtAlias
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
expect(t.comment).is("SOME   COMMENT")
expect(t.min).is(15)
expect(t.max).is(40)
expect(t.after).is(41)

----5----0----5----0----5----0----5----0----5----|
s = [=====[
---@alias     NAME TYPE @ SOME   COMMENT         
     SUITE                                        ]=====]
t = p:match(s)
expect(t).is.NOT(nil)
expect(t.name).is("NAME")
expect(t.types).equal({ "TYPE" })
expect(t.comment).is("SOME   COMMENT")
expect(t.min).is(15)
expect(t.max).is(40)
expect(t.after).is(51)

p = __.capture_param_p
expect(p).is.NOT(nil)

----5----0----5----0----5----0----5----0----5----|
s = [=====[
---@param NAME TYPE]=====]
t = p:match(s)
expect(t.name).is("NAME")
expect(t.types).equal({ "TYPE" })
expect(t.comment).is(nil)
expect(t.min).is(11)
expect(t.max).is(19)
expect(t.after).is(20)

----5----0----5----0----5----0----5----0----5----|
s = [=====[
---@param NAME TYPE
]=====]
t = p:match(s)
expect(t.name).is("NAME")
expect(t.types).equal({ "TYPE" })
expect(t.comment).is(nil)
expect(t.min).is(11)
expect(t.max).is(19)
expect(t.after).is(21)

----5----0----5----0----5----0----5----0----5----|
s = [=====[
---@param NAME TYPE  |  OTHER
]=====]
t = p:match(s)
expect(t.name).is("NAME")
expect(t.types).equal({ "TYPE", "OTHER" })
expect(t.comment).is(nil)
expect(t.min).is(11)
expect(t.max).is(29)
expect(t.after).is(31)

----5----0----5----0----5----0----5----0----5----|
s = [=====[
---@param NAME TYPE  |  OTHER@  COMMENT
]=====]
t = p:match(s)
expect(t.name).is("NAME")
expect(t.types).equal({ "TYPE", "OTHER" })
expect(t.comment).is("COMMENT")
expect(t.min).is(11)
expect(t.max).is(39)
expect(t.after).is(41)

p = __.capture_return_p
expect(p).is.NOT(nil)

----5----0----5----0----5----0----5----0----5----|
s = [=====[
---   @return TYPE   |  OTHER @ COMMENT
]=====]
t = p:match(s)
expect(t.types).equal({ "TYPE", "OTHER" })
expect(t.comment).is("COMMENT")
expect(t.min).is(15)
expect(t.max).is(39)
expect(t.after).is(41)

p = __.capture_generic_p
expect(p).is.NOT(nil)

s = [=====[
-- @generic T1 [: PARENT_TYPE] [, T2 [: PARENT_TYPE]]
]=====]

s = [=====[
---@generic T1
]=====]
---@type AD.AtGeneric
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
expect(t.comment).is("COMMENT")
expect(t.min).is(15)
expect(t.max).is(59)
expect(t.after).is(61)

p = __.capture_vararg_p
expect(p).is.NOT(nil)

s = [=====[
-- @vararg TYPE[|OTHER_TYPE] [ @ comment ]
]=====]

----5----0----5----0----5----0----5----0----5----0----5----|
s = [=====[
---@vararg    TYPE_
]=====]
t = p:match(s)
expect(t.types).equals({ "TYPE_" })
expect(t.comment).is(nil)
expect(t.min).is(15)
expect(t.max).is(19)
expect(t.after).is(21)

----5----0----5----0----5----0----5----0----5----0----5----|
s = [=====[
---@vararg    TYPE_|TYPE
]=====]
t = p:match(s)
expect(t.types).equals({ "TYPE_", "TYPE" })
expect(t.comment).is(nil)
expect(t.min).is(15)
expect(t.max).is(24)
expect(t.after).is(26)

----5----0----5----0----5----0----5----0----5----0----5----|
s = [=====[
---@vararg    TYPE_|TYPE@CMT_
]=====]
t = p:match(s)
expect(t.types).equals({ "TYPE_", "TYPE" })
expect(t.comment).is("CMT_")
expect(t.min).is(15)
expect(t.max).is(29)
expect(t.after).is(31)

p = __.capture_module_p
expect(p).is.NOT(nil)

----5----0----5----0----5----0----5----0----5----0----5----|
s = [=====[
---   @module name_
]=====]
---@type AD.AtModule
t = p:match(s)
expect(t.name).equals("name_")
expect(t.comment).is(nil)
expect(t.min).is(15)
expect(t.max).is(19)
expect(t.after).is(21)

----5----0----5----0----5----0----5----0----5----0----5----|
s = [=====[
---   @module name_ @ COMMENT
]=====]
t = p:match(s)
expect(t.name).equals("name_")
expect(t.comment).is("COMMENT")
expect(t.min).is(15)
expect(t.max).is(29)
expect(t.after).is(31)

p = __.capture_global_p
expect(p).is.NOT(nil)

----5----0----5----0----5----0----5----0----5----0----5----|
s = [=====[
---  @global  name_
]=====]
---@type AD.AtGlobal
t = p:match(s)
expect(t.name).equals("name_")
expect(t.comment).is(nil)
expect(t.min).is(15)
expect(t.max).is(19)
expect(t.after).is(21)

----5----0----5----0----5----0----5----0----5----0----5----|
s = [=====[
---  @global  name_ @ COMMENT
]=====]
---@type AD.AtGlobal
t = p:match(s)
expect(t.name).equals("name_")
expect(t.comment).is("COMMENT")
expect(t.min).is(15)
expect(t.max).is(29)
expect(t.after).is(31)

p = __.capture_code_p
expect(p).is.NOT(nil)

expect(p:match("-- bla bla bla")).is(nil)

----5----0----5----0----5----0----5----0----5----0----5----|
s = [=====[
    XXXXX XXXX
]=====]
---@type AD.Code
t = p:match(s)
expect(t.min).is(5)
expect(t.max).is(14)
expect(t.after).is(16)

p = __.capture_break_p
expect(p).is.NOT(nil)

expect(p:match("")).is(nil)
expect(p:match("\n").after).is(2)
expect(p:match(" \n ").after).is(3)
expect(p:match(" \n \n").after).is(5)


p = __.capture_function_annotation_p
expect(p).is.NOT(nil)

----5----0----5----0----5----0----5----0----5----0----5----|
s = [=====[
---@function  name_
]=====]
---@type AD.AtFunction
t = p:match(s)
expect(t.name).equals("name_")
expect(t.comment).is(nil)
expect(t.min).is(15)
expect(t.max).is(19)
expect(t.after).is(21)

----5----0----5----0----5----0----5----0----5----0----5----|
s = [=====[
---@function  name_ @ COMMENT
]=====]
t = p:match(s)
expect(t.name).equals("name_")
expect(t.comment).is("COMMENT")
expect(t.min).is(15)
expect(t.max).is(29)
expect(t.after).is(31)



print("DONE")
