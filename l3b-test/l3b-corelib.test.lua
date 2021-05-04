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

_G.test_shallow_copy = function ()
  local shallow_copy = corelib.shallow_copy
  local original = {}
  expect(shallow_copy(original)).equals(original)
  original = { a = 1 }
  expect(shallow_copy(original)).equals(original)
  original = setmetatable({ a = 1 }, {})
  local copy = shallow_copy(original)
  expect(copy).equals(original)
  expect(getmetatable(copy)).is(getmetatable(original))
  original.foo = {}
  copy = shallow_copy(original)
  expect(copy.foo.bar).is(nil)
  original.foo.bar = 421
  expect(copy.foo.bar).is(421)
end

_G.test_deep_copy = function ()
  local deep_copy = corelib.deep_copy
  local original = {}
  expect(deep_copy(original)).equals(original)
  original = { a = 1 }
  expect(deep_copy(original)).equals(original)
  original = setmetatable({ a = 1 }, {})
  local copy = deep_copy(original)
  expect(copy).equals(original)
  expect(getmetatable(copy)).is(getmetatable(original))
  original.foo = {}
  copy = deep_copy(original)
  expect(copy.foo.bar).is(nil)
  original.foo.bar = 421
  expect(copy.foo.bar).is(nil)
end

_G.test_bridge = function ()
  local primary = {
    p_1 = 1,
    p_2 = 2,
    p_3 = {
      p_31 = 31,
    },
    t = {},
  }
  local secondary = {
    s_1 = 11,
    s_2 = 21,
    s_3 = {
      s_31 = 311,
    },
    t = {},
  }
  local b = corelib.bridge({
    primary   = primary,
    secondary = secondary,
  })
  expect(b.p_1).is(primary.p_1)
  expect(b.p_2).is(primary.p_2)
  expect(b.p_3).equals({ p_31 = 31 })
  expect(b.s_1).is(secondary.s_1)
  expect(b.s_2).is(secondary.s_2)
  expect(b.s_3).equals({ s_31 = 311 })
  primary.s_1 = secondary.s_1 + 10
  expect(b.s_1).is(primary.s_1)
  primary.s_1 = nil
  expect(b.s_1).is(secondary.s_1)

  expect(b.t).equals({})
  primary.t.p = 1 + math.random()
  expect(b.t.p).equals(primary.t.p)
  secondary.t.s = 2 + math.random()
  expect(b.t.s).equals(secondary.t.s)

  b = corelib.bridge({
    primary = primary,
    secondary = secondary,
    prefix = "before_",
    suffix = "_after",
  })
  primary.before_x_after = 1
  secondary.before_y_after = 2
  expect(b.x).is(1)
  expect(b.y).is(2)
  b = corelib.bridge({
    primary = {},
    secondary = {},
    index = function (self, k)
      if k == "foo" then
        return 421
      end
    end,
  })
  expect(b.foo).is(421)
  b = corelib.bridge({
    primary = {
      foo = 421,
    },
    secondary = {
      bar = 421,
    },
    complete = function (self, k, result)
      if k == "foo" then
        return 2 * result
      end
    end,
  })
  expect(b.foo).is(842)
  expect(b.bar).is(421)

  local track
  b = corelib.bridge({
    primary = {
      foo = 421,
    },
    secondary = {
      bar = 421,
    },
    newindex = function (self, k, value)
      if k == "mee" then
        track = value
      end
    end,
  })
  b.mee = 421
  expect(track).is(421)

  b = corelib.bridge()
  local key = {}
  _G[key] = 421
  expect(b[key]).is(421)
end

function _G.test_base_extension()
  local test = --_G.LU_wrap_test(
    function (s, expected)
      expect(s:get_base_extension()).equals(expected)
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
