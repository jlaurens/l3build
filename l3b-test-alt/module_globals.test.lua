#!/usr/bin/env texlua
--[[
  This is a test file for l3build package.
  It is only intended for development and should appear in any distribution of the l3build package.
  For help, run `texlua l3build.lua test -h`
--]]

local expect = _ENV.expect

local function test_basic()
  expect(1).is(1)
end

return {
  test_basic          = test_basic,
}
