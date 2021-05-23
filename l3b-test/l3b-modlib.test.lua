#!/usr/bin/env texlua
--[[
  This is a test file for l3build package.
  It is only intended for development and should appear in any distribution of the l3build package.
  For help, run `texlua l3build.lua test -h`
--]]

local lfs = require("lfs")

local expect = _ENV.expect

require("l3b-pathlib")

---@type fslib_t
local fslib = require("l3b-fslib")
local tree = fslib.tree

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
  local dir = _ENV.create_test_module_ds()
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
  local dir = _ENV.create_test_module_ds()
  local module = Module({ path = dir })
  expect(function ()
    module.__:get_module_of_env()
  end).error()
  expect(function ()
    module.__:set_module_of_env()
  end).error()
end

local test_main_parent_module = {
  test_Class = function (self)
    expect( function ()
              print(Module.main_module)
            end
    ).error()
    expect(Module.__get_module_of_env(ModEnv)).is(Module)
  end,
  test_instance = function (self)
    -- create a bundle A at path_A
    -- with embedded modules A/AA, A/AA/AAA
    local path_A = _ENV.create_test_module_ds({
      name = "A",
    })
    local module_A = Module({ path = path_A })
    expect(module_A.path).contains(path_A)
    local path_AA = _ENV.create_test_module_ds({
      dir = path_A,
      name = "AA",
    })
    local module_AA = Module({ path = path_AA })
    local path_AAA = _ENV.create_test_module_ds({
      dir = path_AA,
      name = "AAA",
    })
    local module_AAA = Module({ path = path_AAA })
    -- special case: the "l3b-test-alt" is a barrier
    local path_AAB = path_AA / "l3b-test-alt"
    expect(_ENV.mkdir(path_AAB)).is(true)
    path_AAB = _ENV.create_test_module_ds({
      dir = path_AAB ,
      name = "AAB",
    })
    local module_AAB = Module({ path = path_AAB })
    expect(module_A.parent_module).is(nil)
    expect(module_A.main_module).is(module_A)
    expect(module_AA.parent_module).is(module_A)
    expect(module_AA.main_module).is(module_A)
    expect(module_AAA.parent_module).is(module_AA)
    expect(module_AAA.main_module).is(module_A)
    expect(module_AAB.parent_module).is(nil)
    expect(module_AAB.main_module).is(module_AAB)
  end,
}

local test_child_modules = {
  test_no_children = function (self)
    local path_A = _ENV.create_test_module_ds({
      name = "A",
    })
    local module_A = Module({ path = path_A })
    expect(#module_A.child_modules).is(0)
  end,
  test_children_just_below = function (self)
    local path_A = _ENV.create_test_module_ds({
      name = "A",
    })
    local module_A = Module({ path = path_A })
    local path_AA = _ENV.create_test_module_ds({
      dir = path_A,
      name = "AA",
    })
    local module_AA = Module({ path = path_AA })
    local path_AB = _ENV.create_test_module_ds({
      dir = path_A,
      name = "AB",
    })
    local module_AB = Module({ path = path_AB })
    expect(module_A.child_modules).items({ module_AA, module_AB})
  end,
  test_deep_children = function (self)
    local path_A = _ENV.create_test_module_ds({
      name = "A",
    })
    local module_A = Module({ path = path_A })
    local path_AA = _ENV.create_test_module_ds({
      dir = path_A / _ENV.random_string(),
      name = "A_A",
    })
    expect(path_AA).NOT(nil)
    local module_AA = Module({ path = path_AA })
    local path_AB = _ENV.create_test_module_ds({
      dir = path_A / _ENV.random_string(),
      name = "A_B",
    })
    expect(path_AB).NOT(nil)
    local module_AB = Module({ path = path_AB })
    expect(module_A.child_modules).items({ module_AA, module_AB})
    -- local found = {}
    -- find all the "build.lua" files inside the receiver's directory
    -- We assume that tree goes from top to bottom
    -- for entry in tree(path_A, "*/**/build.lua", {
    --   excludeX = function (e)
    --     for already in entries(found) do
    --       if not relative(e.src, already):match("^..") then
    --         return true -- do not dig inside modules
    --       end
    --     end
    --   end
    -- }) do
    --   print(entry.src)
    -- end

  end,
  test_grand_children = function (self)
    -- grand children are not children
    -- but are children of children
    local path_A = _ENV.create_test_module_ds({
      name = "A",
    })
    local module_A = Module({ path = path_A })
    local path_AA = _ENV.create_test_module_ds({
      dir = path_A,
      name = "AA",
    })
    local module_AA = Module({ path = path_AA })
    local path_AAA = _ENV.create_test_module_ds({
      dir = path_AA,
      name = "AAA",
    })
    local module_AAA = Module({ path = path_AAA })
    expect(module_A.child_modules).items({ module_AA })
    expect(module_AA.child_modules).items({ module_AAA })
  end,
}

local function test_rewrite_compare()
  expect(modlib.rewrite_log).error()
  expect(modlib.rewrite_pdf).error()
  expect(modlib.compare_tlg).error()
end

return {
  test_basic              = test_basic,
  test_instance           = test_instance,
  test_static             = test_static,
  test_main_parent_module = test_main_parent_module,
  test_child_modules      = test_child_modules,
  test_rewrite_compare    = test_rewrite_compare,
}
