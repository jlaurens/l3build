#!/usr/bin/env texlua
--[[
  This is a test file for l3build package.
  It is only intended for development and should appear in any distribution of the l3build package.
  For help, run `texlua l3build.lua test -h`
--]]

---@type fslib_t
local fslib         = require("l3b-fslib")

---@type oslib_t
local oslib         = require("l3b-oslib")
local write_content = oslib.write_content

local expect = _ENV.expect

---@type Module
local Module = require("l3b-module")

local function test_basic()
  expect(Module).NOT(nil)
end

local function test_POC()
  local maindir = _ENV.make_temporary_dir()
  expect(maindir).NOT(nil)
  fslib.set_working_directory_provider(function () return maindir end)
  local script_path = maindir / "unpack.lua"
  write_content(script_path, [[
#!/usr/bin/env texlua
FOO = "BAR"
_ENV.BAR = "_ENV.BAR"
]])
  local ENV = setmetatable({}, {
    __index = _G,
  })
  local f = loadfile(script_path, "t", ENV)
  f()
  expect(ENV.FOO).is("BAR")
  expect(ENV.BAR).is("_ENV.BAR")
end

return {
  test_basic          = test_basic,
  test_POC            = test_POC,
}
