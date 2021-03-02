--[[

File l3build-utillib.lua Copyright (C) 2018-2020 The LaTeX Project

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

--[=[ Usage
---@type utlib_t
local utlib = require("l3b.utillib")
local to_quoted_string = utlib.to_quoted_string
local indices = utlib.indices
local entries = utlib.entries
local items = utlib.items
local unique_entries = utlib.unique_entries
local unique_items = utlib.unique_items
local keys = utlib.keys
local values = utlib.values
--]=]

-- local safety guards and shortcuts

local next = next
local concat = table.concat

---Turn the string list into quoted items separated by a sep
---@param table table
---@param separator string|nil defaults to " "
---@return string
local function to_quoted_string(table, separator)
  local t = {}
  for i = 1, #table do
    t[i] = ("%q"):format(table[i])
  end
  return concat(t, separator or " ")
end
--[=[ Original implementation
local function tab_to_str(table)
  local string = ""
  for i in entries(table) do
    string = string .. " " .. "\"" .. i .. "\""
  end
  return string
end
]=]

---@type fun(table: table): fun(): integer
local indices = ipairs

---Iterator for the entries of a sequencial table
---@param table table
---@return fun()
local function entries(table)
  local i = 0
  return function ()
    i = i + 1
    return table[i]
  end
end

---Iterator for the items given in arguments
---@vararg any
---@return fun()
local function items(...)
  return entries({ ... })
end

---Iterator for the entries of a sequencial table.
---Every entry is ignored when already listed.
---@param table table
---@return fun()
local function unique_entries(table)
  local i = 0
  local already = {}
  return function ()
    while true do
      i = i + 1
      local result = table[i]
      if not result then return result end -- end of iteration
      if not already[result] then
        already[result] = true
        return result
      end
    end
  end
end

---Iterator for the items given in arguments
---Every item is ignored when already listed.
local function unique_items(...)
  return unique_entries({ ... })
end

---@type fun(table: table): fun(): any
local keys = pairs

---Iterates over the values of the table
---@param table table
---@return fun()
local function values(table)
  local k, v
  return function ()
    k, v = next(table, k)
    return v
  end
end

---Return the first argument
---@param first any
---@return any
---@usage first_of(gsub(...))
local function first_of(first)
  return first
end

---Return the second argument
---@param _ any
---@param second any
---@return any
---@usage first_of(gsub(...))
local function second_of(_, second)
  return second
end

---Return a copy of s witthout heading nor trailing spaces.
---@param s string
---@return string
local function trim(s) -- TODO: local or move to utlib
  return s:match("^%s*(.-)%s*$")
end

---Merge in place `holder` with `addendum`.
---@param holder table The receiver
---@param addendum table What is merged into the receiver
---@param can_overwrite boolean|nil if falsy overwriting is an error
---@return table holder
local function extend_with(holder, addendum, can_overwrite)
  for key, value in pairs(addendum) do
    assert(can_overwrite or not holder[key], "Conflicting symbol ".. key)
    holder[key] = value
  end
  return holder
end

---@class utlib_t
---@field to_quoted_string function
---@field indices function
---@field entries function
---@field items function
---@field unique_entries function
---@field unique_items function
---@field keys function
---@field values function
---@field first_of function
---@field second_of function
---@field extend_with function

return {
  to_quoted_string = to_quoted_string,
  indices = indices,
  entries = entries,
  items = items,
  unique_entries = unique_entries,
  unique_items = unique_items,
  keys = keys,
  values = values,
  first_of = first_of,
  second_of = second_of,
  trim = trim,
  extend_with = extend_with,
}
