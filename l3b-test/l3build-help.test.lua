#!/usr/bin/env texlua
--[[
  This is a test file for l3build package.
  It is only intended for development and should appear in any distribution of the l3build package.
  For help, run `texlua l3build.lua test -h`
--]]

local push  = table.insert

local expect  = _ENV.expect
local l3build = _ENV.l3build

---@type corelib_t
local corelib = require("l3b-corelib")

---@type fslib_t
local fslib = require("l3b-fslib")

---@type l3b_main_t
local l3b_main = require("l3build-main")
local Main = l3b_main.Main

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
    local options = {}
    local kvargs = {}
    self.impl.run_high(options, kvargs)
    _ENV.pop_print()
    expect(track).equals({})
    track = {}
    local name = "FOO".. _ENV.random_string()
    local value = _ENV.random_string()
    options[corelib.GET_MAIN_VARIABLE] = name
    _G[name] = value
    _ENV.push_print(function (x)
      push(track, x)
    end)
    self.impl.run_high(options, kvargs)
    _ENV.pop_print()
    local n, v = track[1]:match("GLOBAL VARIABLE: name = (.-), value = (.*)")
    expect(name).is(n)
    expect(value).is(v)
  end,
  test_status_run = function (self)
    fslib.set_working_directory_provider(function () return l3build.work_dir end)
    _G.bundle = ""
    _G.module = _ENV.random_string()
    local track = {}
    _ENV.push_print(function (x)
      push(track, x)
    end)
    self.impl.run()
    _ENV.pop_print()
    local output = table.concat(track, "\n")
    expect(output:match(_G.module)).NOT(nil)
  end,
}
local function test_help()
  l3build.main = Main()
  l3build.main:configure_cli(l3build.work_dir)
  local track = {}
  _ENV.push_print(function (x)
    push(track, x)
  end)
  l3b_help.help()
  _ENV.pop_print()
  local output = table.concat(track, "\n")
  expect(output:match("usage: l3build")).NOT(nil)
end

return {
  test_basic  = test_basic,
  test_status = test_status,
  test_help   = test_help,
}
