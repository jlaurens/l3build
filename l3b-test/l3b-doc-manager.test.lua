#!/usr/bin/env texlua
--[[
  This is a test file for l3build package.
  It is only intended for development and should appear in any distribution of the l3build package.
  For help, run `texlua l3build.lua test -h`
--]]

local push   = table.insert

local expect  = _ENV.expect

local DocManager  = require("l3b-doc-manager")

local function test_initialize()
  expect(DocManager).NOT(nil)
  local dm = DocManager("THE PATH")
  expect(dm.work_path).is("THE PATH")
end

local function test_modules ()
  local dm = DocManager()
  dm.__modules = { "a", "b", "c" }
  local t = {}
  for m in dm.all_modules do
    push(t, m)
  end
  expect(t).equals(dm.__modules)
end

return {
  test_initialize = test_initialize,
  test_modules    = test_modules,
}
