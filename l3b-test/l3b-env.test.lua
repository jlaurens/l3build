#!/usr/bin/env texlua
--[[
  This is a test file for l3build package.
  It is only intended for development and should appear in any distribution of the l3build package.
  For help, run `texlua l3build.lua test -h`
--]]

require("l3b-pathlib")

---@type Object
local Object = require("l3b-object")

---@type Env
local Env = require("l3b-env")

---@type oslib_t
local oslib = require("l3b-oslib")
local write_content = oslib.write_content

local expect  = _ENV.expect

local function test_Env()
  expect(Env).NOT(nil)
  expect(Env()).NOT(nil)
end

local function test_global()
  -- Env, its instances and subclasses
  -- inherit values from the global environment
  local key = _ENV.random_string()
  local value = _ENV.random_number()
  _G[key] = value
  expect(Env[key]).is(value)
  local env = Env()
  expect(env[key]).is(value)
  local E = Env:make_subclass("Class")
  expect(E()[key]).is(value)
  _G[key] = nil
  expect(env[key]).is(nil)
  expect(E[key]).is(nil)
end

local test_load = {
  setup = function (self)
    self.dir = _ENV.make_temporary_dir()
    self.path = self.dir / _ENV.random_string()
    self.rhs = "r".. _ENV.random_string()
    self.lhs = "l".. _ENV.random_string()
    self.E = Env:make_subclass("E")
    self.e = self.E()
  end,
  load_file = function (self, increment)
    write_content(self.path, ([[
#!/usr/bin/env texlua
%s = %s + 1
]]):format(increment and self.rhs or self.lhs, self.rhs))
    local f = loadfile(self.path, "t", self.e)
    expect(f).NOT(nil)
    f()
  end,
  test_global = function (self)
    -- get a global value, set an environment value
    _G[self.rhs] = 421
    self:load_file()
    expect(self.e[self.lhs]).is(422)
  end,
  test_E = function (self)
    -- get an E value, set an environment value
    self.E[self.rhs] = 421
    self:load_file()
    expect(self.e[self.lhs]).is(422)
  end,
  test_e = function (self)
    -- get an e value, set an environment value
    self.e[self.rhs] = 421
    self:load_file()
    expect(self.e[self.lhs]).is(422)
  end,
  test_global_increment = function (self)
    -- get a global value, set an environment value
    _G[self.rhs] = 421
    self:load_file(true)
    expect(self.e[self.rhs]).is(422)
    expect(_G[self.rhs]).is(421)
  end,
  test_E_increment = function (self)
    -- get an E value, set an environment value
    self.E[self.rhs] = 421
    self:load_file(true)
    expect(self.e[self.rhs]).is(422)
    expect(self.E[self.rhs]).is(421)
  end,
  test_e_increment = function (self)
    -- get an e value, set an environment value
    self.e[self.rhs] = 421
    self:load_file(true)
    expect(self.e[self.rhs]).is(422)
  end,
}
local test_activate = {
  test_Env = function ()
    local key = _ENV.random_string()
    local value = _ENV.random_number()
    -- find global value only when active
    _G[key] = value
    expect(Env[key]).is(value)
    Object.deactivate_env(Env)
    expect(Env[key]).is(nil)
    Object.activate_env(Env)
    _G[key] = nil
    -- find Object value only when active
    Object[key] = value
    expect(Env[key]).is(value)
    Object.deactivate_env(Env)
    expect(Env[key]).is(nil)
    Object.activate_env(Env)
    Object[key] = nil
  end,
  test_e = function ()
    local e = Env()
    local key = _ENV.random_string()
    local value = _ENV.random_number()
    -- find global value only when active
    _G[key] = value
    expect(e[key]).is(value)
    Object.deactivate_env(e)
    expect(e[key]).is(nil)
    Object.activate_env(e)
    _G[key] = nil
    -- find Object value only when active
    Object[key] = value
    expect(e[key]).is(value)
    Object.deactivate_env(e)
    expect(e[key]).is(nil)
    Object.activate_env(e)
    Object[key] = nil
    -- Always find Env value
    Env[key] = value
    expect(e[key]).is(value)
    Object.deactivate_env(e)
    expect(e[key]).is(value)
  end,
}

return {
  test_Env      = test_Env,
  test_global   = test_global,
  test_load     = test_load,
  test_activate = test_activate,
}
