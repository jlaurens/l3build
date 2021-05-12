#!/usr/bin/env texlua
--[[
  This is a test file for l3build package.
  It is only intended for development and should appear in any distribution of the l3build package.
  For help, run `texlua l3build.lua test -h`
--]]

local expect = _ENV.expect

---@type l3b_unpk_t
local l3b_unpk = require("l3build-unpack")

local function test_basic()
  expect(l3b_unpk).NOT(nil)
end

return {
  test_basic          = test_basic,
}
