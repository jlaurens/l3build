#!/usr/bin/env texlua

local expect  = require("l3b-test/expect").expect
local lpeg  = require("lpeg")
local P     = lpeg.P

---@type lpeg_autodoc_t
local lpad = require("l3b-lpeg-autodoc")

local DB = require("l3b-test/autodoc_db")

_G.test_line_comment = function ()
  local p = lpad.line_comment
  expect(p).NOT(nil)
  for _, TD in ipairs(DB.line_comment) do
    expect(p:match(TD.s)).equals(TD:x())
  end
end

_G.test_line_doc = function ()
  local p = lpad.line_doc
  expect(p).NOT(nil)
  for _, TD in ipairs(DB.line_doc) do
    expect(p:match(TD.s)).equals(TD:x())
  end
end

_G.test_short_literal = function ()
  local p = lpad.short_literal
  expect(p).NOT(nil)
  for _, TD in ipairs(DB.short_literal) do
    expect(p:match(TD.s)).equals(TD:x())
  end
end

_G.test_long_literal = function ()
  local p = lpad.long_literal
  expect(p).NOT(nil)
  for _, TD in ipairs(DB.long_literal) do
    expect(p:match(TD.s)).equals(TD:x())
  end
end

_G.test_long_comment = function ()
  local p = lpad.long_comment
  expect(p).NOT(nil)
  for _, TD in ipairs(DB.long_comment) do
    expect(p:match(TD.s)).equals(TD:x())
  end
end

_G.test_long_doc = function ()
  local p = lpad.long_doc
  expect(p).NOT(nil)
  for _, TD in ipairs(DB.long_doc) do
    expect(p:match(TD.s)).equals(TD:x())
  end
end

_G.test_get_annotation = function ()
  local p = lpad.get_annotation("foo", P("?"))
  expect(p).NOT(nil)
  expect(p:match("---@foo ?")).equals({
    min = 1,
    max = 9,
  })
  expect(function () p:match("---@foo +") end).error()
end

_G.test_core_field = function ()
  local p = lpad.core_field
  expect(p).NOT(nil)
  p = lpeg.Ct(p)
  for _, TD in ipairs(DB.core_field) do
    expect(p:match(TD.s)).equals(TD:x())
  end
end

_G.test_core_class = function ()
  local p = lpad.core_class
  expect(p).NOT(nil)
  p = lpeg.Ct(p)
  for _, TD in ipairs(DB.core_class) do
    expect(p:match(TD.s)).equals(TD:x())
  end
end

_G.test_core_type = function ()
  local p = lpad.core_type
  expect(p).NOT(nil)
  p = lpeg.Ct(p)
  for _, TD in ipairs(DB.core_type) do
    expect(p:match(TD.s)).equals(TD:x())
  end
end

_G.test_core_alias = function ()
  local p = lpad.core_alias
  expect(p).NOT(nil)
  p = lpeg.Ct(p)
  for _, TD in ipairs(DB.core_alias) do
    expect(p:match(TD.s)).equals(TD:x())
  end
end

_G.test_core_return = function ()
  local p = lpad.core_return
  expect(p).NOT(nil)
  p = lpeg.Ct(p)
  for _, TD in ipairs(DB.core_return) do
    expect(p:match(TD.s)).equals(TD:x())
  end
end

_G.test_core_generic = function ()
  local p = lpad.core_generic
  expect(p).NOT(nil)
  p = lpeg.Ct(p)
  for _, TD in ipairs(DB.core_generic) do
    expect(p:match(TD.s)).equals(TD:x())
  end
end

_G.test_core_param = function ()
  local p = lpad.core_param
  expect(p).NOT(nil)
  p = lpeg.Ct(p)
  for _, TD in ipairs(DB.core_param) do
    expect(p:match(TD.s)).equals(TD:x())
  end
end

_G.test_core_vararg = function ()
  local p = lpad.core_vararg
  expect(p).NOT(nil)
  p = lpeg.Ct(p)
  for _, TD in ipairs(DB.core_vararg) do
    expect(p:match(TD.s)).equals(TD:x())
  end
end

_G.test_core_module = function ()
  local p = lpad.core_module
  expect(p).NOT(nil)
  p = lpeg.Ct(p)
  for _, TD in ipairs(DB.core_module) do
    expect(p:match(TD.s)).equals(TD:x())
  end
end

_G.test_core_global = function ()
  local p = lpad.core_global
  expect(p).NOT(nil)
  p = lpeg.Ct(p)
  for _, TD in ipairs(DB.core_global) do
    expect(p:match(TD.s)).equals(TD:x())
  end
end

_G.test_core_author = function ()
  local p = lpad.core_author
  expect(p).NOT(nil)
  p = lpeg.Ct(p)
  for _, TD in ipairs(DB.core_author) do
    expect(p:match(TD.s)).equals(TD:x())
  end
end

_G.test_core_see = function ()
  local p = lpad.core_see
  expect(p).NOT(nil)
  p = lpeg.Ct(p)
  for _, TD in ipairs(DB.core_see) do
    expect(p:match(TD.s)).equals(TD:x())
  end
end

_G.test_core_function = function ()
  local p = lpad.core_function
  expect(p).NOT(nil)
  p = lpeg.Ct(p)
  for _, TD in ipairs(DB.core_function) do
    expect(p:match(TD.s)).equals(TD:x())
  end
end

_G.test_guess_function_name = function ()
  local p = lpad.guess_function_name
  expect(p).NOT(nil)
  for _, TD in ipairs(DB.guess_function_name) do
    expect(p:match(TD.s)).equals(TD:x())
  end
end

_G.test_paragraph_break = function ()
  local p = lpad.paragraph_break
  expect(p).NOT(nil)
  for _, TD in ipairs(DB.paragraph_break) do
    expect(p:match(TD.s)).equals(TD:x())
  end
end

_G.test_named_pos = function ()
  local p = lpad.named_pos
  expect(p).NOT(nil)
  for _, TD in ipairs(DB.named_pos) do
    local opt = TD.d
    expect(
        lpeg.Ct(lpeg.P(opt.before)
      * p(opt.name, opt.shift)
    ):match(TD.s)).equals(TD:x())
  end
end

_G.test_chunk_init = function ()
  local p = lpad.chunk_init
  expect(p).NOT(nil)
  expect(lpeg.Ct(p):match("")).equals({
    min = 1,
    max = 0,
  })
end

_G.test_chunk_start = function ()
  local p = lpad.chunk_start
  expect(p).NOT(nil)
  expect(
    lpeg.Ct(
      lpeg.Cg(lpeg.Cc(421), "min") * p
    ):match("")
  ).equals({
    min = 421,
  })
end

_G.test_chunk_stop = function ()
  local p = lpad.chunk_stop
  expect(p).NOT(nil)
  p = lpeg.Ct(p)
  for _, TD in ipairs(DB.chunk_stop) do
    expect(p:match(TD.s)).equals(TD:x())
  end
end

_G.test_one_line_chunk_stop = function ()
  local p = lpad.one_line_chunk_stop
  expect(p).NOT(nil)
  p = lpeg.Ct(p)
  for _, TD in ipairs(DB.one_line_chunk_stop) do
    expect(p:match(TD.s)).equals(TD:x())
  end
end

_G.test_special_begin = function ()
  local p = lpad.special_begin
  expect(p).NOT(nil)
  for _, TD in ipairs(DB.special_begin) do
    expect(p:match(TD.s)).equals(TD:x())
  end
end

_G.test_capture_comment = function ()
  local p = lpad.capture_comment
  expect(p).NOT(nil)
  expect(function () p:match("abc") end).error()
  p = lpeg.Ct(p)
  for _, TD in ipairs(DB.capture_comment) do
    expect(p:match(TD.s)).equals(TD:x())
  end
end

_G.test_lua_type = function ()
  local p = lpad.lua_type
  expect(p).NOT(nil)
  for _, TD in ipairs(DB.lua_type) do
    expect(p:match(TD.s)).equals(TD:x())
  end
end

_G.test_named_types = function ()
  local p = lpad.named_types
  expect(p).NOT(nil)
  p = lpeg.Ct(p)
  for _, TD in ipairs(DB.named_types) do
    expect(p:match(TD.s)).equals(TD:x())
  end
end

_G.test_named_optional = function ()
  local p = lpad.named_optional
  expect(p).NOT(nil)
  p = lpeg.Ct(p)
  for _, TD in ipairs(DB.named_optional) do
    expect(p:match(TD.s)).equals(TD:x())
  end
end

_G.test_at_match = function ()
  local p = lpad.at_match
  expect(p).NOT(nil)
  for _, TD in ipairs(DB.at_match) do
    expect(p(TD.d.name):match(TD.s)).equals(TD:x())
  end
end

_G.test_error_annotation = function ()
  local p = lpad.error_annotation
  expect(p).NOT(nil)
  expect(function () p:match("") end).error()
end

_G.test_content = function ()
  local p = lpad.content
  expect(p).NOT(nil)
  p = lpeg.Ct(p)
  for _, TD in ipairs(DB.content) do
    expect(p:match(TD.s)).equals(TD:x())
  end
end

_G.test_comment_2 = function ()
  local p = lpeg.Ct(
      lpad.chunk_init
    * lpad.capture_comment
    * lpad.chunk_stop
  )
  local t, s
  s = ""
  t = p:match(s)
  expect(t).equals({
    min=1,
    content_min=1,
    content_max=0,
    max=0,
  })
  s = "@ FOO \n BAR"
  t = p:match(s)
  expect(t).equals({
    min = 1,
    content_min = 3,
    content_max = 5,
    max = 7,
  })
end
