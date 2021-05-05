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

-- create an environment for test chunks
local ENV = setmetatable({
  LU              = LU,
  expect          = require("l3b-test/expect").expect,
  pretty_print    = pretty_print,
  push_print      = push_print,
  pop_print       = pop_print,
  during_unit_testing = true,
}, {
  __index = _G
})

ENV.loadlib = function (name)
  -- Next is an _ENV that will allow a module to export
  -- more symbols than usually done in order to finegrain testing
  local __ = setmetatable({
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

  for test_name in arg[2]:gmatch("[^,]+") do
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
