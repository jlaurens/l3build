local standard_print = print
local catched_print = print

_G.print = function (...)
  catched_print(...)
end

---@type oslib_t
local oslib = require("l3b-oslib")

local expect  = require("l3b-test/expect").expect

function _G.test()
  expect(oslib).NOT(nil)
end


function _G.test_OS()
  local OS = oslib.OS
  expect(OS).NOT(nil)
end
