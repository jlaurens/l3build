local standard_print = print
local catched_print = print

_G.print = function (...)
  catched_print(...)
end

---@type corelib_t
local corelib = require("l3b-corelib")

local expect  = require("l3b-test/expect").expect

function _G.test()
  expect(corelib).NOT(nil)
end

function _G.test_base_extension()
  local test = --_G.LU_wrap_test(
    function (s, expected)
      expect(s:l3b_base_extension()).contains(expected)
    end
  --)
  test("", {
    base = "",
    extension = ""
  })
  test("abc", {
    base = "abc",
    extension = ""
  })
  for _, base in ipairs({
    "",
    "a",
    ".",
    ".a",
    "a.",
    "..",
    "..a",
    ".a.",
    "a..",
    "a.b",
    ".a.b",
    "a.b.",
  }) do
    for _, extension in ipairs({"", "ext"}) do
      test(base ..".".. extension, {
        base = base,
        extension = extension
      })          
    end
  end
end

_G.test_lpeg = {
  test_white_p = function(self)
    local p = corelib.white_p
    expect(p).NOT(nil)
    expect(p:match("")).is(nil)
    expect(p:match("a")).is(nil)
    expect(p:match(" ")).is(2)
    expect(p:match("\t")).is(2)
  end,
  test_black_p = function(self)
    local p = corelib.black_p
    expect(p).NOT(nil)
    expect(p:match("")).is(nil)
    expect(p:match("a")).is(2)
    expect(p:match(" ")).is(nil)
    expect(p:match("\t")).is(nil)
  end,
  test_eol_p = function(self)
    local p = corelib.eol_p
    expect(p).NOT(nil)
    expect(p:match("")).is(1)
    expect(p:match("a")).is(1)
    expect(p:match("\n")).is(2)
    expect(p:match("\n\n")).is(2)
  end,
  test_ascii_p = function(self)
    local p = corelib.ascii_p
    expect(p).NOT(nil)
    expect(p:match("")).is(nil)
    expect(p:match("a")).is(2)
    expect(p:match("\129")).is(nil)
    expect(p:match("\n")).is(nil)
  end,
  test_utf8_p = function(self)
    local p = corelib.utf8_p
    expect(p).NOT(nil)
    expect(p:match("\019")).is(2)
    expect(p:match("\xC2\xA9")).is(3)
    expect(p:match("\xE2\x88\x92")).is(4)
    expect(p:match("\xF0\x9D\x90\x80")).is(5)
  end,
  test_consume_1_character_p = function(self)
    local done
    catched_print = function (x)
      done = x
    end
    local p = corelib.consume_1_character_p
    expect(p).NOT(nil)
    expect(p:match("a")).is(2)
    expect(p:match("\xC2")).is(nil)
    expect(done).contains("UTF8 problem")
    catched_print = standard_print
  end,
  test_get_spaced_p = function(self)
    local p = corelib.get_spaced_p
    expect(p).NOT(nil)
    expect(p("abc"):match("abc")).is(4)
    expect(p("abc"):match("   abc")).is(7)
    expect(p("abc"):match("abc   ")).is(7)
    expect(p("abc"):match("   abc   ")).is(10)
  end,
  test_spaced_colon_p = function(self)
    local p = corelib.spaced_colon_p
    expect(p).NOT(nil)
    expect(p:match(":")).is(2)
    expect(p:match("  :")).is(4)
    expect(p:match(":  ")).is(4)
    expect(p:match("  :  ")).is(6)
  end,
  test_spaced_comma_p = function(self)
    local p = corelib.spaced_comma_p
    expect(p).NOT(nil)
    expect(p:match(",")).is(2)
    expect(p:match("  ,")).is(4)
    expect(p:match(",  ")).is(4)
    expect(p:match("  ,  ")).is(6)
  end,
  test_variable_p = function(self)
    local p = corelib.variable_p
    expect(p).NOT(nil)
    expect(p:match("abc foo")).is(4)
    expect(p:match("abc123 foo")).is(7)
    expect(p:match("abc123_ foo")).is(8)
    expect(p:match("0bc123_ foo")).is(nil)
  end,
  test_identifier_p = function(self)
    local p = corelib.identifier_p
    expect(p).NOT(nil)
    expect(p:match("abc foo")).is(4)
    expect(p:match("abc.def foo")).is(8)
    expect(p:match(".abc.def foo")).is(nil)
  end,
  test_function_name_p = function(self)
    local p = corelib.function_name_p
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

