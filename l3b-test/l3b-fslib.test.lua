---@type fslib_t
local fslib = require("l3b-fslib")

local expect  = _ENV.expect

local function test()
  expect(fslib).NOT(nil)
end

return {
  test = test,
}