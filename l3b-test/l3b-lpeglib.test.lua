#!/usr/bin/env texlua
--[[
  This is a test file for l3build package.
  It is only intended for development and should appear in any distribution of the l3build package.
  For help, run `texlua l3build.lua test -h`
--]]

local expect  = _ENV.expect

---@type lpeglib_t
local lpeglib = require("l3b-lpeglib")
local get_base_class = lpeglib.get_base_class

local function test_base()
  expect(lpeglib).NOT(nil)
end

local test_lpeg = {
  test_white_p = function(self)
    ---@type lpeg_t
    local p = lpeglib.white_p
    expect(p).NOT(nil)
    expect(p:match("")).is(nil)
    expect(p:match("a")).is(nil)
    expect(p:match(" ")).is(2)
    expect(p:match("\t")).is(2)
  end,
  test_black_p = function(self)
    ---@type lpeg_t
    local p = lpeglib.black_p
    expect(p).NOT(nil)
    expect(p:match("")).is(nil)
    expect(p:match("a")).is(2)
    expect(p:match(" ")).is(nil)
    expect(p:match("\t")).is(nil)
  end,
  test_eol_p = function(self)
    ---@type lpeg_t
    local p = lpeglib.eol_p
    expect(p).NOT(nil)
    expect(p:match("")).is(1)
    expect(p:match("a")).is(1)
    expect(p:match("\n")).is(2)
    expect(p:match("\n\n")).is(2)
  end,
  test_alt_ascii_p = function(self)
    ---@type lpeg_t
    local p = lpeglib.alt_ascii_p
    expect(p).NOT(nil)
    expect(p:match("")).is(nil)
    expect(p:match("a")).is(2)
    expect(p:match("\129")).is(nil)
    expect(p:match("\n")).is(nil)
  end,
  test_alt_utf8_p = function(self)
    ---@type lpeg_t
    local p = lpeglib.alt_utf8_p
    expect(p).NOT(nil)
    expect(p:match("\019")).is(2)
    expect(p:match("\xC2\xA9")).is(3)
    expect(p:match("\xE2\x88\x92")).is(4)
    expect(p:match("\xF0\x9D\x90\x80")).is(5)
    expect(p:match("a-z")).is(2)
  end,
  test_get_spaced_p = function(self)
    ---@type lpeg_t
    local p = lpeglib.get_spaced_p
    expect(p).NOT(nil)
    expect(p("abc"):match("abc")).is(4)
    expect(p("abc"):match("   abc")).is(7)
    expect(p("abc"):match("abc   ")).is(7)
    expect(p("abc"):match("   abc   ")).is(10)
  end,
  test_spaced_colon_p = function(self)
    ---@type lpeg_t
    local p = lpeglib.spaced_colon_p
    expect(p).NOT(nil)
    expect(p:match(":")).is(2)
    expect(p:match("  :")).is(4)
    expect(p:match(":  ")).is(4)
    expect(p:match("  :  ")).is(6)
    expect(p:match("  :  abc")).is(6)
  end,
  test_spaced_comma_p = function(self)
    ---@type lpeg_t
    local p = lpeglib.spaced_comma_p
    expect(p).NOT(nil)
    expect(p:match(',')).is(2)
    expect(p:match("  ,")).is(4)
    expect(p:match(",  ")).is(4)
    expect(p:match("  ,  ")).is(6)
  end,
  test_variable_p = function(self)
    ---@type lpeg_t
    local p = lpeglib.variable_p
    expect(p).NOT(nil)
    expect(p:match("abc foo")).is(4)
    expect(p:match("abc123 foo")).is(7)
    expect(p:match("abc123_ foo")).is(8)
    expect(p:match("0bc123_ foo")).is(nil)
  end,
  test_identifier_p = function(self)
    ---@type lpeg_t
    local p = lpeglib.identifier_p
    expect(p).NOT(nil)
    expect(p:match("abc foo")).is(4)
    expect(p:match("abc.def foo")).is(8)
    expect(p:match(".abc.def foo")).is(nil)
  end,
  test_function_name_p = function(self)
    ---@type lpeg_t
    local p = lpeglib.function_name_p
    expect(p).NOT(nil)
    expect(p:match("abc foo")).is(4)
    expect(p:match("abc.def foo")).is(8)
    expect(p:match(".abc.def foo")).is(nil)
    expect(p:match("abc foo")).is(4)
    expect(p:match("abc:def foo")).is(8)
    expect(p:match("a.c:def foo")).is(8)
    expect(p:match("a:c:def foo")).is(4)
  end,
}

local test_consume_1_character_p = {
  setup = function(self)
    _G.UFT8_DECODING_ERROR = false
    self.done = nil
    _ENV.push_print(function (x)
      self.done = x
    end)
  end,
  teardown = function(self)
    _ENV.pop_print()
  end,
  test = function(self)
    ---@type lpeg_t
    local p = lpeglib.consume_1_character_p
    expect(p).NOT(nil)
    expect(p:match("a")).is(2)
    expect(p:match("\xC2")).is(nil)
    expect(_G.UFT8_DECODING_ERROR).is(true)
    expect(self.done).contains("UTF8 problem")
  end
}

local function test_get_base_class()
  expect({ get_base_class("a") }).equals({
   "a",
  })
  expect({ get_base_class("a.b") }).equals({
    "b",
    "a",
  })
  expect({ get_base_class("a.b.c") }).equals({
    "c",
    "a.b",
  })
  expect({ get_base_class("a.b:c") }).equals({
    "c",
    "a.b",
  })
end


return {
  test_base           = test_base,
  test_lpeg           = test_lpeg,
  test_consume_1_character_p  = test_consume_1_character_p,
  test_get_base_class = test_get_base_class,
}