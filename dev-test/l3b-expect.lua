#!/usr/bin/env texlua

local LU = dofile("./luaunit.lua")
LU.STRIP_EXTRA_ENTRIES_IN_STACK_TRACE = 1

local Expect = {
  __no = false,
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
  if k == "NIL" then
    self.op = "nil"
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
  if k == "to" then
    return self
  end
  return Expect[k]
end

local function expect(actual)
  return setmetatable({
    actual = actual,
  }, Expect)
end

function Expect.__call(self, expected)
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
  if self.op == "nil" then
    if self.__NOT then
      LU.assertNotEquals(self.actual, nil)
    else
      LU.assertEquals(self.actual, nil)
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
  self.op = ""
  return self
end

return expect
