--[[

File l3build-test.lua Copyright (C) 2028-2020 The LaTeX Project

It may be distributed and/or modified under the conditions of the
LaTeX Project Public License (LPPL), either version 1.3c of this
license or (at your option) any later version.  The latest version
of this license is in the file

   http://www.latex-project.org/lppl.txt

This file is part of the "l3build bundle" (The Work in LPPL)
and all files in that bundle must be distributed together.

-----------------------------------------------------------------------

The development version of the bundle can be found at

   https://github.com/latex3/l3build

for those people who are interested.

--]]

local write = io.write
local push  = table.insert
local pop   = table.remove

local lpeg  = require("lpeg")

local l3build = require("l3build")

local TEST_DIR = "l3b-test"

-- next is redundant
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

local LU = require("l3b-test/luaunit")

LU.STRIP_EXTRA_ENTRIES_IN_STACK_TRACE = 1

function _G.LU_wrap_test(f)
  return function (...)
    LU.STRIP_EXTRA_ENTRIES_IN_STACK_TRACE =
      LU.STRIP_EXTRA_ENTRIES_IN_STACK_TRACE + 1
    local result = f(...)
    LU.STRIP_EXTRA_ENTRIES_IN_STACK_TRACE =
      LU.STRIP_EXTRA_ENTRIES_IN_STACK_TRACE - 1
    return result
  end
end
package.loaded["luaunit"] = LU

local print_stack = {
  _G.print
}

function _G.print(...)
  print_stack[#print_stack](...)
end

local function push_print(f)
  push(print_stack, f)
end

local function pop_print()
  assert(#print_stack > 0, "pop with no previous push")
  pop(print_stack)
end

local Expect = {
  __NOT = false,
  __almost = false,
  __items = false,
}

local function expect(actual)
  return setmetatable({
    actual = actual,
  }, Expect)
end

function Expect:__index(k)
  if k == "map" then
    return function (f)
      local modifier = self.modifier
      self.modifier = modifier
        and function (before)
          local result = {}
          for kk, vv in pairs(modifier(before)) do
            result[kk] = f(vv)
          end
          return result
        end
        or function (before)
          local result = {}
          for kk, vv in pairs(before) do
            result[kk] = f(vv)
          end
          return result
        end
      return self
    end
  end
  if k == "NOT" then
    self.__NOT = not self.__NOT
    return self
  end
  if k == "almost" then
    self.__almost = true
    return self
  end
  if k == "items" then
    self.op = self.op or "=="
    self.__items = true
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
  if k == "type" then
    local modifier = self.modifier
    self.modifier = modifier
      and function (before)
        return type(modifier(before))
      end
      or function (before)
        return type(before)
      end
    return self
  end
  if k == "Class" then
    local modifier = self.modifier
    self.modifier = modifier
      and function (before)
        return modifier(before).__Class
      end
      or function (before)
        return before.__Class
      end
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
  if k == "instance_of" then
    self.op = k
    return self
  end
  if k == "than" then
    return self
  end
  return Expect[k]
end

function Expect.__call(self, expected, options)
  options = options or {}
  if self.modifier then
    self.actual = self.modifier(self.actual)
  end
  if self.op == "==" then
    if self.__NOT then
      if self.__almost then
        LU.assertNotAlmostEquals(self.actual, expected)
      else
        LU.assertNotEquals(self.actual, expected)
      end
    elseif self.__almost then
      LU.assertAlmostEquals(self.actual, expected)
    elseif self.__items then
      LU.assertItemsEquals(self.actual, expected)
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
  if self.op == "is" or not self.op then
    if self.__NOT then
      LU.assertNotIs(self.actual, expected)
    else
      LU.assertIs(self.actual, expected)
    end
  end
  if self.op == ">" then
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
      if self.__NOT then
        print("NOT is not supported for contains verb")
        LU.assertNotIs(self.actual, expected)
      end
      for k, v in pairs(expected) do
        if  type(v) == "table"
        and type(self.actual[k]) == "table"
        then
          expect(self.actual[k]).contains(v)
        else
          LU.assertEquals(self.actual[k], v)
        end
      end
      return
    end
    if expected == nil then
      expect(self.actual).is(nil)
    else
      expect(self.actual).NOT(nil)
      ;(options.case_insensitive
        and LU.assert_str_icontains
        or  LU.assert_str_contains
      )(
          self.actual,
          expected
        )
    end
  end
  if self.op == "instance_of" then
    (self.__NOT and LU.assertFalse or LU.assertTrue)
    (self.actual:is_instance_of(expected))
  end
  self.op = ""
  return self
end

-- create an environment for test chunks
local ENV = setmetatable({
  LU              = LU,
  expect          = expect,
  pretty_print    = pretty_print,
  push_print      = push_print,
  pop_print       = pop_print,
  during_unit_testing = true,
}, {
  __index = _G
})

ENV.loadlib = function (name, __)
  -- Next is an _ENV that will allow a module to export
  -- more symbols than usually done in order to finegrain testing
  __ = __ or setmetatable({
    during_unit_testing = true,
  }, {
    __index = _G
  })
  local loader = loadfile(
    l3build.work_dir .."l3b/".. name ..".lua",
    "t",
    __
  ) or loadfile(
    l3build.work_dir .. name ..".lua",
    "t",
    __
  )
  -- return whatever the module returns
  return loader()
end

local run = function ()
  if arg[2] == "-h" or arg[2] == "--help" then
    print([[
Launching tests from the l3b-test/ directory:

> texlua ../l3build.lua test *

run all the testsuites

> texlua ../l3build.lua test foo,bar

run tests files which names contain either "foo" or "bar"

> texlua ../l3build.lua test * -p foo -p bar

from all test files run only test containing either "foo" or "bar".
]])
    os.exit(0)
  end
  ---@type table<string,boolean>
  local done = {}
  -- arg[2] is a comma separated list of names
  -- it means that base names should not contain any comma!
  -- This is also an assumption made by lua somewhere
  local function get_key(k, key)
    local p =
        lpeg.Cmt(
          lpeg.C( lpeg.P(4) ),
          function (s, i, what)
            if what:lower() == "test" then
              return i
            end
          end
        )^-1
      * lpeg.P("_")^0
      * lpeg.C( lpeg.P(1)^0 )
    local kk0 = "test_".. key .."_".. p:match(k)
    local kk = kk0
    local suffix = 0
    while _G[kk] ~= nil do
      suffix = 1 + suffix
      kk = kk0 .."_".. suffix
    end
    return kk
  end

  local all_names

  do
    local test_names = {}
    local lfs = require("lfs")
    for test_name in lfs.dir(l3build.work_dir .. TEST_DIR) do
      if test_name:match(".*%.test%..*") then
        for test in arg[2]:gmatch("[^,]+") do
          if test_name:match(test) then
            push(test_names, test_name)
            break
          end
        end
      end
    end
    local i = 0
    all_names = function ()
      i = i + 1
      return test_names[i]
    end
  end

  for test_name in all_names do
    if not done[test_name] then
      done[test_name] = true -- don't test it twice
      local name = test_name:gsub( "%.lua$", "")
      local key  = name:match("(%a-)%.test")
      local path = name .. ".lua"
      print("Register tests for ".. path)
      local f = loadfile(path, "t", ENV)
      local tests = f()
      for k, v in pairs(tests) do
        _G[get_key(k, key)] = v
      end
    end
  end
  print("Running all tests")
  arg[#arg + 1] = "-v" -- error without this
  os.exit( LU["LuaUnit"].run(table.unpack(arg, 3)) )
  return
end

return {
  run = run
}
