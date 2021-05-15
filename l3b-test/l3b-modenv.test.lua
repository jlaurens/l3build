#!/usr/bin/env texlua
--[[
  This is a test file for l3build package.
  It is only intended for development and should appear in any distribution of the l3build package.
  For help, run `texlua l3build.lua test -h`
--]]

require("l3b-pathlib")

---@type ModEnv
local ModEnv

---@type __modenv_t
local __

ModEnv, __ = _ENV.loadlib("l3b-modenv")

local expect  = _ENV.expect

local function test_ModEnv()
  expect(ModEnv).NOT(nil)
  expect(ModEnv()).NOT(nil)
  local module = { is_instance = true, foo = 421 }
  local me = ModEnv(module)
  expect(me:get_private_property(__.MODULE)).is(module)
end

local test_dir = {
  test_maindir = function (self)
    local maindir = _ENV.random_string()
    local module = {
      is_instance = true,
      main_module = {
        path = maindir
      }
    }
    local me = ModEnv(module)
    expect(me.maindir).is(maindir)
  return
  end,
}

return {
  test_ModEnv = test_ModEnv,
  test_dir    = test_dir,
}
