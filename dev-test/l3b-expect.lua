#!/usr/bin/env texlua

local LU = dofile("./luaunit.lua")
LU.STRIP_EXTRA_ENTRIES_IN_STACK_TRACE = 1

local Expect = {
  __NOT = false,
  __almost = false,
}

function Expect:__index(k)
  if k == "NOT" then
    self.__NOT = not self.__NOT
    return self
  end
  if k == "almost" then
    self.__almost = true
    return self
  end
  if k == "equal" or k == "equals" then
    self.op = "=="
    return self
  end
  if k == "error" then
    self.op = "error"
    return self
  end
  if k == "is" then
    self.op = "is"
    return self
  end
  if k == "greater" then
    self.op = ">"
    return self
  end
  if k == "less" then
    self.op = "<"
    return self
  end
  if k == "contains" then
    self.op = "⊇"
    return self
  end
  if k == "to" then
    return self
  end
  if k == "than" then
    return self
  end
  return Expect[k]
end

function Expect.__call(self, expected, options)
  options = options or {}
  if self.op == "==" then
    if self.__NOT then
      if self.__almost then
        LU.assertNotAlmostEquals(self.actual, expected)
      else
        LU.assertNotEquals(self.actual, expected)
      end
    elseif self.__almost then
      LU.assertAlmostEquals(self.actual, expected)
    else
      LU.assertEquals(self.actual, expected)
    end
  end
  if self.op == "error" then
    if self.__NOT then
      self.actual()
    else
      LU.assertError(self.actual)
    end
  end
  if self.op == "is" then
    if self.__NOT then
      LU.assertNotIs(self.actual, expected)
    else
      LU.assertIs(self.actual, expected)
    end
  end
  if self.op == ">" then
    if  self.__NOT
    and type(self.actual) == "table"
    and type(expected) == "table"
    then
      for k, v in pairs(self.actual) do
        LU.assertEquals(expected[k], v)
      end
      return
    end
    if self.__NOT then
      LU.assertFalse(self.actual > expected)
    else
      LU.assertTrue(self.actual > expected)
    end
  end
  if self.op == "<" then
    if self.__NOT then
      LU.assertFalse(self.actual < expected)
    else
      LU.assertTrue(self.actual < expected)
    end
  end
  if self.op == "⊇" then
    if  type(self.actual) == "table"
    and type(expected) == "table"
    then
      for k, v in pairs(expected) do
        LU.assertEquals(self.actual[k], v)
      end
      return
    end
    ;(options.case_insensitive
      and LU.assert_str_icontains
      or  LU.assert_str_contains
    )(
        self.actual,
        expected
      )
  end
  self.op = ""
  return self
end

local function expect(actual)
  return setmetatable({
    actual = actual,
  }, Expect)
end

---Run a unit test
---@param msg string
---@param run_f fun()
local function test(msg, run_f)
  local setup_f = function () end
  local teardown_f = function () end
  local tests = {}
  local function setup(f)
    setup_f = f
  end
  local function teardown(f)
    teardown_f = f
  end
  run_f()


end

return {
  expect  = expect,
  test    = test,
}, LU
