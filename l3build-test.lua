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
local lfs   = require("lfs")

local l3build = require("l3build")

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
  if k == "match" then
    self.op = k
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
  if self.op == "match" then
    (self.__NOT and LU.assertFalse or LU.assertTrue)
    (self.actual:match(expected) ~= nil)
  end
  self.op = ""
  return self
end

-- create an environment for test chunks
local ENV = setmetatable({
  TEST_DIR        = l3build.TEST_DIR,
  TEST_ALT_DIR    = l3build.TEST_ALT_DIR,
  LU              = LU,
  expect          = expect,
  pretty_print    = pretty_print,
  push_print      = push_print,
  pop_print       = pop_print,
  l3build         = l3build,
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

l3build.options = {}

local run = function ()
  if arg[2] == "-h" or arg[2] == "--help" then
    print([[
Launching tests from the main directory:

> texlua l3build.lua test

run all the testsuites

> texlua l3build.lua test foo,bar

run tests files which names contain either "foo" or "bar"

> texlua l3build.lua test -p foo -p bar

from all test files run only test containing either "foo" or "bar".
]])
    os.exit(0)
  end
  -- test shortcut:
  -- when a `l3b_test_diagnostic` file exists
  -- execute it and return its result
  local l3b_test_diagnostic_path = l3build.work_dir .. "l3b_test_diagnostic.lua"
  --l3b_test_diagnostic_path = "/Users/jlaurens/Desktop/l3b_test_diagnostic.lua"
  if lfs.attributes(l3b_test_diagnostic_path, "mode") then
    local f, msg = loadfile(l3b_test_diagnostic_path)
    if not f then
      error(msg)
    end
    print("DEBUGGG")
    return f()
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

  function ENV.random_number()
    return math.random(100000, 999999)
  end

  function ENV.random_string()
    return "_".. tostring(ENV.random_number())
  end

  local temporary_file_name = os.tmpname()
  os.remove(temporary_file_name)
  local temporary_dir = temporary_file_name:match("^.*/")
    .. 'l3build'
    .. ENV.random_string()
  lfs.mkdir(temporary_dir)

  function ENV.make_temporary_dir(name)
    local result = temporary_dir .. '/' .. (name or ENV.random_string())
    return lfs.mkdir(result) and result or nil
  end

  ---comment
  ---@param dir string    @ directory must exist
  ---@param name string   @ name of the module
  ---@param build_content string  @ content of `build.lua`
  ---@return string|nil   @ path of the module, nil on error
  ---@return nil|error_level_n @ positive number on error, nil otherwise
  function ENV.create_test_module(dir, name, build_content, test_content)
    local result = dir .."/".. name
    if not lfs.mkdir(result) then
      return nil, 1
    end
    local file_path = result .."/build.lua"
    local fh = assert(io.open(file_path, "w"))
    if not fh then
      return nil, 1
    end
    build_content = "#!/usr/bin/env texlua\n".. build_content
    if os["type"] == "windows" then
      build_content = build_content:gsub("\n", "\r\n")
    end
    local error_level
    if not fh:write(build_content) then
      result = nil
      error_level = 1
    end
    fh:close()
    if test_content then
      -- test_content = "#!/usr/bin/env texlua\n".. test_content
      if os["type"] == "windows" then
        test_content = test_content:gsub("\n", "\r\n")
      end
      file_path = result .."/l3b_test_diagnostic.lua"
      print("diagnostic file_path", file_path, test_content)
      fh = assert(io.open(file_path, "w"))
      if not fh then
        return nil, 1
      end
      if not fh:write(test_content) then
        result = nil
        error_level = 1
      end
      fh:close()
    end
    return result, error_level
  end

  ---@type fun(): string|nil @ string iterator
  local all_names
  do
    local test_names = {}
    local test_dir = l3build.work_dir .. l3build.TEST_DIR
    if lfs.attributes(test_dir, "mode") then
      for test_name in lfs.dir(test_dir) do
        if test_name:match(".*%.test%..*") then
          if arg[2] and not arg[2]:match("^%-") then
            for test in arg[2]:gmatch("[^,]+") do
              if test_name:match(test) then
                push(test_names, test_name)
                break
              end
            end
          else
            push(test_names, test_name)
          end
        end
      end
      -- name iterator
      all_names = function ()
        local i = 0
        return function ()
          i = i + 1
          return test_names[i] and test_dir .."/".. test_names[i]
        end
      end
    elseif arg[2] and not arg[2]:match("^%-") then
      for test_name in arg[2]:gmatch("[^,]+") do
        print(test_name)
        if test_name:match("%.test*.lua$") then
          push(test_names, test_name)
        end
      end
      all_names = function ()
        local i = 0
        return function ()
          i = i + 1
          return test_names[i]
        end
      end
    else
      print("No test to perform")
      return 1
    end
  end
  for test_name in all_names() do
    if not done[test_name] then
      done[test_name] = true -- don't test it twice
      local name = test_name:gsub( "%.lua$", "")
      local key  = name:match("(%w+)%.test$")
      local path = name .. ".lua"
      print("Register tests for ".. path:match("[^/]+$"))
      local f = loadfile(path, "t", ENV)
      local tests = f()
      for k, v in pairs(tests) do
        _G[get_key(k, key)] = v
      end
    end
  end
  print("Running all requested tests")
  local i = 2
  if arg[2] and not arg[2]:match("^%-") then
    i = 3
  end
  arg[#arg + 1] = "-v"
  local result = LU["LuaUnit"].run(table.unpack(arg, i))
  print("Removing", temporary_dir)
  -- os.exit( result )
  -- no recursive call
  do
    local dirs = { temporary_dir }
    local j = 0
    local files = {}
    while j < #dirs do
      j = j + 1
      local dir = dirs[j]
      for entry in lfs.dir(dir) do
        if entry ~= "." and entry ~= ".." then
          local path = dir .."/".. entry
          if lfs.attributes(path, "mode") == "directory" then
            push(dirs, path)
          else
            push(files, path)
          end
        end
      end
    end
    for jj = #files, 1, -1 do
      os.remove(files[jj])
    end
    for jj = #dirs, 1, -1 do
      lfs.rmdir(dirs[jj])
    end
  end
  os.exit( result )
  return
end

return {
  run = run
}
