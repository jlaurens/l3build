#!/usr/bin/env texlua
--[[
  This is a test file for l3build package.
  It is only intending for development and should appear in any distribution of the l3build package.
  For help, run `texlua ../l3build.lua test -h`
--]]

local expect  = _ENV.expect

---@type corelib_t
local corelib = require("l3b-corelib")

local function test_base()
  expect(corelib).NOT(nil)
end

local function test_shallow_copy()
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

local function test_deep_copy()
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

local function test_bridge()
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
  _G[key] = nil
end

return {
  test_base           = test_base,
  test_shallow_copy   = test_shallow_copy,
  test_deep_copy      = test_deep_copy,
  test_bridge         = test_bridge,
}
