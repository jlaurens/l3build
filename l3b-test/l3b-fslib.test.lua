local standard_print = print
local catched_print = print

_G.print = function (...)
  catched_print(...)
end

---@type fslib_t
local fslib = require("l3b-fslib")

local expect  = require("l3b-test/expect").expect

function _G.test()
  expect(fslib).NOT(nil)
end

