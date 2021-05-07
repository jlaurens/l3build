#!/usr/bin/env texlua
--[[
  This is a test file for l3build package.
  It is only intending for development and should appear in any distribution of the l3build package.
  For help, run `texlua ../l3build.lua test -h`
--]]

local push   = table.insert

local expect  = _ENV.expect

---@type l3b_targets_t
local targets

---@type __l3b_targets_t
local __

targets, __ = _ENV.loadlib("l3b-targets")

local register_info = targets.register_info
local get_info      = targets.get_info
local get_all_infos = targets.get_all_infos
local process       = targets.process

local function test_base()
  expect(targets).NOT(nil)
end

local test_info = {
  setup = function (self)
  end,
  teardown = function (self)
    for k, _ in pairs(__.DB) do
      __.DB[k] = nil
    end
  end,
  info_1 = {
    description = "DESCRIPTION_1",
    package = "PACKAGE".. tostring(math.random(999999)),
    name    = "NAME_1",
    alias   = "ALIAS_1",
  },
  info_2 = {
    description = "DESCRIPTION_2",
    package = "PACKAGE".. tostring(math.random(999999)),
    name    = "NAME_2",
    alias   = "ALIAS_2",
  },
  test_register_info = function (self)
    register_info(self.info_1)
    ---@type target_info_t
    local info_1 = get_info(self.info_1.name)
    expect(info_1).equals({
      description = "DESCRIPTION_1",
      package = self.info_1.package,
      name    = "NAME_1",
      alias   = "ALIAS_1",
      builtin = false,
    })
    expect(function () register_info(self.info_1) end).error()
  end,
  test_get_all_infos = function (self)
    register_info(self.info_1)
    register_info(self.info_2)
    local result = {}
    for info in get_all_infos() do
      push(result, info)
    end
    expect(result).items.map(function (x) return x.name end).equals({
      "NAME_1",
      "NAME_2",
    })
  end,
  test_process = function (self)
    register_info(self.info_1)
    local options = {}
    expect(function () process(options) end).error()
    options.target = "NAME_1"
    expect(function () process(options) end).error()
    local pkg = {}
    package.loaded[self.info_1.package] = pkg
    local kvarg = {}
    local track = {}
    -- required preflight method
    kvarg.preflight = function ()
      track.preflight = true
    end
    expect(function () process(options, kvarg) end).error()
    track = {}
    pkg.NAME_1 = function ()
      track.run = true
    end
    process(options, kvarg)
    expect(track).equal({
      run       = true,
      preflight = true,
    })
    package.loaded[self.info_1.package] = nil

  end,
}

return {
  test_base = test_base,
  test_info = test_info,
}
