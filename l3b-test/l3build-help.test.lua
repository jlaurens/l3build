#!/usr/bin/env texlua
--[[
  This is a test file for l3build package.
  It is only intended for development and should appear in any distribution of the l3build package.
  For help, run `texlua l3build.lua test -h`
--]]

local push  = table.insert
local pop   = table.remove

local expect  = _ENV.expect
local l3build = _ENV.l3build

---@type fslib_t
local fslib = require("l3b-fslib")

---@type l3b_help_t
local l3b_help = require("l3build-help")

local function test_basic()
  expect(l3b_help).NOT(nil)
  expect(l3b_help.version).type("function")
  expect(l3b_help.help).type("function")
end

local test_status = {
      setup = function (self)
    self.impl = l3b_help.status_impl
  end,
  test_high = function (self)
    local track = {}
    _ENV.push_print(function (x)
      push(track, x)
    end)
    self.impl.run_high()
    _ENV.pop_print()
    expect(track).equals({ "NOT A RUN HIGH" })
    track = {}
    local name = "FOO".. math.random(999999)
    local value = tostring(math.random(999999))
    l3build.options.get_main_variable = name
    _G[name] = value
    _ENV.push_print(function (x)
      push(track, x)
    end)
    self.impl.run_high()
    _ENV.pop_print()
    local n, v = track[1]:match("GLOBAL VARIABLE: name = (.-), value = (.*)")
    expect(name).is(n)
    expect(value).is(v)
  end,
  test_help = function (self)
    l3b_help.help()
  end,
  test_status_run = function (self)
    fslib.set_working_directory(l3build.work_dir)
    self.impl.run()
  end,
}

return {
  test_basic  = test_basic,
  test_status = test_status,
}
