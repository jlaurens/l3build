#!/usr/bin/env texlua
--[[
  This is a test file for l3build package.
  It is only intended for development and should appear in any distribution of the l3build package.
  For help, run `texlua l3build.lua test -h`
--]]

local lfs = require("lfs")

local expect = _ENV.expect

require("l3b-pathlib")

---@type modlib_t
local modlib = require("l3b-modlib")

---@type Module
local Module = modlib.Module
---@type ModEnv
local ModEnv = modlib.ModEnv

local function test_basic()
  expect(Module).NOT(nil)
  expect(ModEnv).NOT(nil)
end

local function test_instance()
  ---@type Module
  local dir = _ENV.create_test_module()
  local module = Module({ path = dir })
  expect(module).NOT(nil)
  expect(module.path).ends_with(dir / ".")
  expect(Module.__get_module_of_env(module.env)).is(module)
  expect(Module.__get_module_of_env(ModEnv)).is(Module)
  lfs.mkdir(dir / "foo")
  module = Module({ path = dir / "foo" })
  expect(module).NOT(nil)
  expect(module.path).ends_with(dir / '.')
end

local function test_static()
  ---@type Module
  local dir = _ENV.create_test_module()
  local module = Module({ path = dir })
  expect(function ()
    module:__get_module_of_env()
  end).error()
  expect(function ()
    module:__set_module_of_env()
  end).error()
end

local test_main_module = {
  test_Class = function (self)
    expect(Module.main_module).is(Module)
    expect(Module.__get_module_of_env(ModEnv)).is(Module)
  end,
  test_instance = function (self)
    local A = _ENV.create_test_module({
      name = "A",
    })
    print("DEBUGG", A)
    local module_A = Module({ path = A })
    local AA = _ENV.create_test_module({
      dir = A,
      name = "AA",
    })
    local module_AA = Module({ path = AA })
    local AAA = _ENV.create_test_module({
      dir = AA,
      name = "AAA",
    })
    local module_AAA = Module({ path = AAA })
    local AAB = AA .."/".. "l3b-test-alt"
    expect(_ENV.mkdir(AAB)).is(true)
    AAB = _ENV.create_test_module({
      dir = AAB ,
      name = "AAB",
    })
    local module_AAB = Module({ path = AAB })
    expect(module_A.main_module).is(module_A)
    expect(module_AA.main_module.path).is(module_A.path)
    -- expect(module_AAA.main_module).is(module_A)
    -- expect(module_AAB.main_module).is(module_AAB)
  end,
}

return {
  test_basic        = test_basic,
  test_instance     = test_instance,
  test_static       = test_static,
  test_main_module  = test_main_module,
}
