#!/usr/bin/env texlua
--[[
  This is a test file for l3build package.
  It is only intended for development and should appear in any distribution of the l3build package.
  For help, run `texlua l3build.lua test -h`
--]]

local expect  = _ENV.expect
local lpeg    = require("lpeg")
local P       = lpeg.P

---@type lpeg_autodoc_t
local lpad = require("l3b-lpeg-autodoc")

local DB    = _ENV.autodoc_DB or _ENV.loadlib(
  "l3b-test/autodoc_db",
  _ENV
)

_ENV.autodoc_DB = DB

local function test_line_comment()
  local p = lpad.line_comment
  expect(p).NOT(nil)
  for _, TD in ipairs(DB.line_comment) do
    expect(p:match(TD.s, TD.d or 1)).equals(TD:x())
  end
end

local function test_line_doc()
  local p = lpad.line_doc
  expect(p).NOT(nil)
  for _, TD in ipairs(DB.line_doc) do
    expect(p:match(TD.s, TD.d or 1)).equals(TD:x())
  end
end

local function test_short_literal()
  local p = lpad.short_literal
  expect(p).NOT(nil)
  for _, TD in ipairs(DB.short_literal) do
    expect(p:match(TD.s, TD.d or 1)).equals(TD:x())
  end
end

local function test_long_literal()
  local p = lpad.long_literal
  expect(p).NOT(nil)
  for _, TD in ipairs(DB.long_literal) do
    expect(p:match(TD.s, TD.d or 1)).equals(TD:x())
  end
end

local function test_long_comment()
  local p = lpad.long_comment
  expect(p).NOT(nil)
  for _, TD in ipairs(DB.long_comment) do
    expect(p:match(TD.s, TD.d or 1)).equals(TD:x())
  end
end

local function test_long_doc()
  local p = lpad.long_doc
  expect(p).NOT(nil)
  for _, TD in ipairs(DB.long_doc) do
    expect(p:match(TD.s, TD.d or 1)).equals(TD:x())
  end
end

local function test_get_annotation()
  local p = lpad.get_annotation("foo", P("?"))
  expect(p).NOT(nil)
  expect(p:match("---@foo ?")).equals({
    min = 1,
    max = 9,
  })
  expect(function () p:match("---@foo +") end).error()
end

local function test_core_field()
  local p = lpad.core_field
  expect(p).NOT(nil)
  p = lpeg.Ct(p)
  for _, TD in ipairs(DB.core_field) do
    expect(p:match(TD.s, TD.d or 1)).equals(TD:x())
  end
end

local function test_core_class()
  local p = lpad.core_class
  expect(p).NOT(nil)
  p = lpeg.Ct(p)
  for _, TD in ipairs(DB.core_class) do
    expect(p:match(TD.s, TD.d or 1)).equals(TD:x())
  end
end

local function test_core_type()
  local p = lpad.core_type
  expect(p).NOT(nil)
  p = lpeg.Ct(p)
  for _, TD in ipairs(DB.core_type) do
    expect(p:match(TD.s, TD.d or 1)).equals(TD:x())
  end
end

local function test_core_alias()
  local p = lpad.core_alias
  expect(p).NOT(nil)
  p = lpeg.Ct(p)
  for _, TD in ipairs(DB.core_alias) do
    expect(p:match(TD.s, TD.d or 1)).equals(TD:x())
  end
end

local function test_core_return()
  local p = lpad.core_return
  expect(p).NOT(nil)
  p = lpeg.Ct(p)
  for _, TD in ipairs(DB.core_return) do
    expect(p:match(TD.s, TD.d or 1)).equals(TD:x())
  end
end

local function test_core_generic()
  local p = lpad.core_generic
  expect(p).NOT(nil)
  p = lpeg.Ct(p)
  for _, TD in ipairs(DB.core_generic) do
    expect(p:match(TD.s, TD.d or 1)).equals(TD:x())
  end
end

local function test_core_param()
  local p = lpad.core_param
  expect(p).NOT(nil)
  p = lpeg.Ct(p)
  for _, TD in ipairs(DB.core_param) do
    expect(p:match(TD.s, TD.d or 1)).equals(TD:x())
  end
end

local function test_core_vararg()
  local p = lpad.core_vararg
  expect(p).NOT(nil)
  p = lpeg.Ct(p)
  for _, TD in ipairs(DB.core_vararg) do
    expect(p:match(TD.s, TD.d or 1)).equals(TD:x())
  end
end

local function test_core_module()
  local p = lpad.core_module
  expect(p).NOT(nil)
  p = lpeg.Ct(p)
  for _, TD in ipairs(DB.core_module) do
    expect(p:match(TD.s, TD.d or 1)).equals(TD:x())
  end
end

local function test_core_global()
  local p = lpad.core_global
  expect(p).NOT(nil)
  p = lpeg.Ct(p)
  for _, TD in ipairs(DB.core_global) do
    expect(p:match(TD.s, TD.d or 1)).equals(TD:x())
  end
end

local function test_core_author()
  local p = lpad.core_author
  expect(p).NOT(nil)
  p = lpeg.Ct(p)
  for _, TD in ipairs(DB.core_author) do
    expect(p:match(TD.s, TD.d or 1)).equals(TD:x())
  end
end

local function test_core_see()
  local p = lpad.core_see
  expect(p).NOT(nil)
  p = lpeg.Ct(p)
  for _, TD in ipairs(DB.core_see) do
    expect(p:match(TD.s, TD.d or 1)).equals(TD:x())
  end
end

local function test_core_function()
  local p = lpad.core_function
  expect(p).NOT(nil)
  p = lpeg.Ct(p)
  for _, TD in ipairs(DB.core_function) do
    expect(p:match(TD.s, TD.d or 1)).equals(TD:x())
  end
end

local function test_guess_function_name()
  local p = lpad.guess_function_name
  expect(p).NOT(nil)
  for _, TD in ipairs(DB.guess_function_name) do
    expect(p:match(TD.s, TD.d or 1)).equals(TD:x())
  end
end

local function test_paragraph_break()
  local p = lpad.paragraph_break
  expect(p).NOT(nil)
  for _, TD in ipairs(DB.paragraph_break) do
    expect(p:match(TD.s, TD.d or 1)).equals(TD:x())
  end
end

local function test_named_pos()
  local p = lpad.named_pos
  expect(p).NOT(nil)
  for _, TD in ipairs(DB.named_pos) do
    local opt = TD.d
    expect(
        lpeg.Ct(lpeg.P(opt.before)
      * p(opt.name, opt.shift)
    ):match(TD.s, opt.min or 1)).equals(TD:x())
  end
end

local function test_chunk_init()
  local p = lpad.chunk_init
  expect(p).NOT(nil)
  expect(lpeg.Ct(p):match("")).equals({
    min = 1,
    max = 0,
  })
end

local function test_chunk_start()
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

local function test_chunk_stop()
  local p = lpad.chunk_stop
  expect(p).NOT(nil)
  p = lpeg.Ct(p)
  for _, TD in ipairs(DB.chunk_stop) do
    expect(p:match(TD.s, TD.d or 1)).equals(TD:x())
  end
end

local function test_one_line_chunk_stop()
  local p = lpad.one_line_chunk_stop
  expect(p).NOT(nil)
  p = lpeg.Ct(p)
  for _, TD in ipairs(DB.one_line_chunk_stop) do
    expect(p:match(TD.s, TD.d or 1)).equals(TD:x())
  end
end

local function test_special_begin()
  local p = lpad.special_begin
  expect(p).NOT(nil)
  for _, TD in ipairs(DB.special_begin) do
    expect(p:match(TD.s, TD.d or 1)).equals(TD:x())
  end
end

local function test_capture_comment()
  local p = lpad.capture_comment
  expect(p).NOT(nil)
  expect(function () p:match("abc") end).error()
  p = lpeg.Ct(p)
  for _, TD in ipairs(DB.capture_comment) do
    expect(p:match(TD.s, TD.d or 1)).equals(TD:x())
  end
end

local function test_lua_type()
  local p = lpad.lua_type
  expect(p).NOT(nil)
  for _, TD in ipairs(DB.lua_type) do
    expect(p:match(TD.s, TD.d or 1)).equals(TD:x())
  end
end

local function test_named_types()
  local p = lpad.named_types
  expect(p).NOT(nil)
  p = lpeg.Ct(p)
  for _, TD in ipairs(DB.named_types) do
    expect(p:match(TD.s, TD.d or 1)).equals(TD:x())
  end
end

local function test_named_optional()
  local p = lpad.named_optional
  expect(p).NOT(nil)
  p = lpeg.Ct(p)
  for _, TD in ipairs(DB.named_optional) do
    expect(p:match(TD.s, TD.d or 1)).equals(TD:x())
  end
end

local function test_at_match()
  local p = lpad.at_match
  expect(p).NOT(nil)
  for _, TD in ipairs(DB.at_match) do
    local opt = TD.d
    expect(p(opt.name):match(TD.s, opt.min or 1)).equals(TD:x())
  end
end

local function test_error_annotation()
  local p = lpad.error_annotation
  expect(p).NOT(nil)
  expect(function () p:match("") end).error()
end

local function test_content()
  local p = lpad.content
  expect(p).NOT(nil)
  p = lpeg.Ct(p)
  for _, TD in ipairs(DB.content) do
    expect(p:match(TD.s, TD.d or 1)).equals(TD:x())
  end
end

local function test_comment_2()
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

return {
  test_line_comment         = test_line_comment,
  test_line_doc             = test_line_doc,
  test_short_literal        = test_short_literal,
  test_long_literal         = test_long_literal,
  test_long_comment         = test_long_comment,
  test_long_doc             = test_long_doc,
  test_get_annotation       = test_get_annotation,
  test_core_field           = test_core_field,
  test_core_class           = test_core_class,
  test_core_type            = test_core_type,
  test_core_alias           = test_core_alias,
  test_core_return          = test_core_return,
  test_core_generic         = test_core_generic,
  test_core_param           = test_core_param,
  test_core_vararg          = test_core_vararg,
  test_core_module          = test_core_module,
  test_core_global          = test_core_global,
  test_core_author          = test_core_author,
  test_core_see             = test_core_see,
  test_core_function        = test_core_function,
  test_guess_function_name  = test_guess_function_name,
  test_paragraph_break      = test_paragraph_break,
  test_named_pos            = test_named_pos,
  test_chunk_init           = test_chunk_init,
  test_chunk_start          = test_chunk_start,
  test_chunk_stop           = test_chunk_stop,
  test_one_line_chunk_stop  = test_one_line_chunk_stop,
  test_special_begin        = test_special_begin,
  test_capture_comment      = test_capture_comment,
  test_lua_type             = test_lua_type,
  test_named_types          = test_named_types,
  test_named_optional       = test_named_optional,
  test_at_match             = test_at_match,
  test_error_annotation     = test_error_annotation,
  test_content              = test_content,
  test_comment              = test_comment_2,
}

