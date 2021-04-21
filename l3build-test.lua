--[[

File l3build-test.lua Copyright (C) 2028-2020 The LaTeX Project

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

local write   = io.write

function _G.pretty_print(tt, indent, done)
  done = done or {}
  indent = indent or 0
  if type(tt) == "table" then
    local w = 0
    for k, _ in pairs(tt) do
      local l = #tostring(k)
      if l > w then
        w = l
      end
    end
    for k, v in pairs(tt) do
      local filler = (" "):rep(w - #tostring(k))
      write((" "):rep(indent)) -- indent it
      if type(v) == "table" and not done[v] then
        done[v] = true
        if next(v) then
          write(('["%s"]%s = {\n'):format(tostring(k), filler))
          _G.pretty_print(v, indent + w + 7, done)
          write((" "):rep( indent + w + 5)) -- indent it
          write("}\n")
        else
          write(('["%s"]%s = {}\n'):format(tostring(k), filler))
        end
      elseif type(v) == "string" then
        write(('["%s"]%s = "%s"\n'):format(
            tostring(k), filler, tostring(v)))
      else
        write(('["%s"]%s = %s\n'):format(
            tostring(k), filler, tostring(v)))
      end
    end
  else
    write(tostring(tt) .."\n")
  end
end

local LU = require("l3b-test/luaunit")
function _G.LU_wrap_test(f)
  return function (...)
    LU.STRIP_EXTRA_ENTRIES_IN_STACK_TRACE =
      LU.STRIP_EXTRA_ENTRIES_IN_STACK_TRACE + 1
    local result = f(...)
    LU.STRIP_EXTRA_ENTRIES_IN_STACK_TRACE =
      LU.STRIP_EXTRA_ENTRIES_IN_STACK_TRACE - 1
    return result
  end
end
package.loaded["luaunit"] = LU

local run = function ()
  dofile(
    arg[2]:gsub( "%.lua$", "") .. ".lua"
  )
  os.exit( LU["LuaUnit"].run(table.unpack(arg, 3)) )
  return
end

return {
  run = run
}
