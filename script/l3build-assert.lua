--[[

File l3build-assert.lua Copyright (C) 2018-2020 The LaTeX Project

It may be distributed and/or modified under the conditions of the
LaTeX Project Public License (LPPL), either version 1.3c of this
license or (at your option) any later version.  The latest version
of this license is in the file

   http://www.latex-project.org/lppl.txt

This file is part of the "l3build bundle" (The Work in LPPL)
and all files in that bundle must be distributed together.

-----------------------------------------------------------------------

The development version of the bundle can be found at

   https://github.com/latex3/l3build

for those people who are interested.

--]]

-- This is a work in progress

local lu   = require("luaunit")

local insert = table.insert
local append = table.insert
local remove = table.remove

-- The concept of flag is very handy to control the workflow
--[[
  local flag = af.new_flag()
  ...
  flag.push("foo")
  ...
  flag.push("bar")
  ...
  flag.expect("foo/bar")
--]]
local new_flag = function(af)
  af = af or lu
  local value = {}
  local closure = function ()
    return {
      reset = function (what)
        value = what and { tostring(what) } or {}
      end,
      push = function (what)
        what = tostring(what)
        append(value, what)
      end,
      pop = function ()
        remove(value)
      end,
      shift = function (what)
        what = tostring(what)
        insert(value, 1, what)
      end,
      unshift = function ()
        remove(value, 1)
      end,
      expect = function (what)
        local expected = ""
        local sep = ""
        for _,v in ipairs(value) do
          expected = expected .. sep .. v
          sep = "/"
        end
        af.assert_equals(what and tostring(what) or "", expected)
      end
    }
  end
  return closure()
end

-- return a proxy to luaunit.
-- Once there will be a built assertion framework
-- it will return a proxy to this framework
return setmetatable({
  new_flag = new_flag,
  flag = new_flag(),
}, {
  __index = lu,
  __newindex = lu,
})
