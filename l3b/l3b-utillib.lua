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

-- Aliases
---@alias string_list_t table<integer, string>
-- local safety guards and shortcuts

local type    = type
local print   = print
local rawget  = rawget
local assert  = assert
local pairs   = pairs
local next    = next

local sort        = table.sort
local append      = table.insert
local concat      = table.concat
local tbl_unpack  = table.unpack

--[=[ Package implementation ]=]

--[==[ Readonly business
A readonly table is not immutable because we can always use `rawset`.
The purpose is to prevent spurious higher changes like `foo.bar = baz`.
With a level of indirections, we loose the `pairs` benefit
unless we define a `__pairs` event handler.
]==]

local KEY_READONLY_ORIGINAL = {} -- unique key to point to the orginal table

---Return a readony proxy to the given table.
---@param t     table
---@param quiet boolean
---@return table
local function readonly(t, quiet)
  assert(type(t) == "table")
  if rawget(t, KEY_READONLY_ORIGINAL) then
    return t
  end
  return setmetatable({
    [KEY_READONLY_ORIGINAL] = t,
  }, {
    __index = function (tt, k)
      local original = rawget(tt, KEY_READONLY_ORIGINAL)
      return original[k]
    end,
    __newindex = quiet and nil or function (tt, k, v)
      error("Readonly table ".. tostring(k) .."=".. tostring(v))
    end,
    __pairs = function (tt)
      local original = rawget(tt, KEY_READONLY_ORIGINAL)
      return pairs(original)
    end
  })
end

---True iff `t` is the result of a previous `readonly` call.
---The argument must be indexable.
---@param t any
---@return boolean
local function is_readonly(t)
  return rawget(t, KEY_READONLY_ORIGINAL) ~= nil
end

--[==[ End of the readonly business ]==]

---@class utlib_vars_t
---@field debug flag_table_t

---@type utlib_vars_t
local Vars = {
  debug = {}
}

---@alias error_level_n integer

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
--[===[ Original implementation
local function tab_to_str(table)
  local string = ""
  for i in entries(table) do
    string = string .. " " .. "\"" .. i .. "\""
  end
  return string
end
]===]

---Iterator for the indices of a sequencial table.
---Purely syntactic sugar for people preferring `for in` loops.
---@param table table
---@return fun()
---@usage `for i in indices(t) do ... end` instead of `for i = 1, #t do ... end`
local function indices(table)
  local i = 0
  return function ()
    i = i + 1
    return i <= #table and i or nil
  end
end

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

---Iterator for the entries of a sequencial table.
---Every entry is ignored when already listed.
---@param table table
---@return fun()
local function unique_entries(table)
  local i = 0
  local already = {}
  return function ()
    repeat -- forever
      i = i + 1
      local result = table[i]
      if result == nil then -- end of iteration
        return result
      elseif not already[result] then
        already[result] = true
        return result
      end
    until false
  end
end

---Iterator for the entries of a sequencial table.
---Every entry is ignored when already listed.
---@param table table
---@return fun()
local function sorted_entries(table)
  local sorted = { tbl_unpack(table) }
  sort(sorted)
  return entries(sorted)
end

---Iterator for the items given in arguments
---@vararg any
---@return fun()
---@usage `for item in items(a, b, c) do ... end`
local function items(...)
  return entries({ ... })
end

---Iterator for the items given in arguments
---Every item is ignored when already listed.
local function unique_items(...)
  return unique_entries({ ... })
end

---Iterator for the items given in arguments
---Every item is ignored when already listed.
local function sorted_items(...)
  return sorted_entries({ ... })
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

---Iterates over the values of the table
---Values are sorted according to the keys
---Values are filtered.
---@param table table
---@param exclude fun(value: any): boolean
---@return fun()
local function sorted_values(table, exclude)
  local i, kk = 0, {}
  for k in keys(table) do
    append(kk, k)
  end
  sort(kk)
  return function ()
    repeat -- forever
      i = i + 1
      local k = kk[i]
      if k == nil then
        return
      end
      local value = table[k]
      if not exclude or not exclude(value) then
        return value
      end
    until false
  end
end

---Iterates over the values of the table
---Values are sorted according to the keys
---Values are filtered.
---@param table table
---@param exclude fun(value: any): boolean
---@return fun()
local function sorted_pairs(table, exclude)
  local i, kk = 0, {}
  for k in keys(table) do
    append(kk, k)
  end
  sort(kk)
  return function ()
    repeat -- forever
      i = i + 1
      local k = kk[i]
      if k == nil then
        return
      end
      local value = table[k]
      if not exclude or not exclude(value) then
        return k, value
      end
    until false
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
---@usage seconf_of(...)
local function second_of(_, second)
  return second
end

---Return a copy of s witthout heading nor trailing spaces.
---@param s string
---@return string
local function trim(s)
  return s:match("^%s*(.-)%s*$")
end

---Merge in place `holder` with `addendum`.
---@param holder table The receiver
---@param addendum table What is merged into the receiver
---@param can_overwrite boolean|nil if falsy overwriting is an error
---@return table holder
local function extend_with(holder, addendum, can_overwrite)
  for key, value in pairs(addendum) do
    assert(can_overwrite or not holder[key], "Conflicting symbol ".. tostring(key))
    holder[key] = value
  end
  return holder
end

--https://gist.github.com/tylerneylon/81333721109155b2d244#gistcomment-3262222
---Make a deep copy of the given object
---@param original any
---@return any
local function shallow_copy(original)
  local res = {}
  for k, v in next, original do res[k] = v end
  return setmetatable(res, getmetatable(original))
end

--https://gist.github.com/tylerneylon/81333721109155b2d244#gistcomment-3262222
---Make a deep copy of the given object
---@param original any
---@return any
local function deep_copy(original)
  local seen = {}
  local function f(obj)
    if type(obj) ~= 'table' then  -- return as is
      return obj
    end
    if seen[obj] then             -- return already see if any
      return seen[obj]
    end
    local res = {}                                -- make a new table
    seen[obj] = res                               -- mark it as seen
    for k, v in next, obj do res[f(k)] = f(v) end -- copy recursively
    return setmetatable(res, getmetatable(obj))
  end
  return f(original)
end

--[==[ Bridge business ]==]

---@class bridge_kv_t
---@field prefix    string
---@field suffix    string
---@field index     fun(t: table, k: any): any
---@field newindex  fun(t: table, k: any, result: any): boolean
---@field complete  fun(t: table, k: any, result: any): any
---@field map       table<string,string>
---@field primary   table the main object, defaults to _G
---@field secondary table the secondary object

---Return a bridge to "global" variables
---@param kv bridge_kv_t
---@return table
local function bridge(kv)
  local MT = {}
  if kv then
    kv = shallow_copy(kv)
    MT.__index = function (t --[[: table]], k --[[: string]])
      if type(k) == "string" then
        if kv.map then
          k = kv.map[k]
          if not k then
            return
          end
        end
        local k_G = (kv.prefix or "") .. k .. (kv.suffix or "")
        local primary = kv.primary or _G
        local result  = primary[k_G]
        if not result and kv.index then
          result = kv.index(t, k)
        end
        if kv.complete then
          result = kv.complete(t, k, result)
        end
        if kv.secondary then
          local result_2 = kv.secondary[k_G]
          if  result ~= result_2
          and type(result_2) == "table"
          and type(result)    == "table"
          then
            result = bridge({
              primary   = result,
              secondary = result_2
            })
          end
        end
        return result
      end
    end
    if kv.newindex then
      MT.__newindex = function (t, k, v)
        assert(kv.newindex(t, k, v), "Readonly bridge ".. tostring(k) .." ".. tostring(v))
      end
    end
  else
    MT.__index = function (t, k)
      return _G[k]
    end
    MT.__newindex = function (t, k, v)
      error("Readonly bridge".. tostring(k) .." ".. tostring(v))
    end
  end
  return setmetatable({}, MT)
end

---Convert a diff time into a display time
---@param diff number
---@return string
local function to_ymd_hms(diff)
  local diff_date = {}
  diff_date.sec = diff % 60
  diff = diff // 60
  diff_date.min = diff % 60
  diff = diff // 60
  diff_date.hour = diff % 24
  diff = diff // 24
  diff_date.day = diff % 30
  diff = diff // 30
  diff_date.month = diff % 12
  diff = diff // 12
  diff_date.year = diff
  local display_date = {}
  for item in items("year", "month", "day") do
    local n = diff_date[item]
    if n > 0 then
      append(display_date, ("%d %s"):format(n, item))
    end
  end
  local display_time = {}
  for item in items("hour", "min", "sec") do
    local n = diff_date[item]
    append(display_time, ("%02d"):format(n))
  end
  return concat({
    concat(display_date, ", "),
    concat(display_time, ':')
  }, ' ')
end

---Print the diff time, if any.
---@param format string
---@param diff number
local function print_diff_time(format, diff)
  if diff > 0 then
    print(format:format(to_ymd_hms(diff)))
  end
end

---@alias utlib_flags_t table<string,boolean>

---@type utlib_flags_t
local flags = {}

---@class utlib_t
---@field Vars              utlib_vars_t
---@field flags             utlib_flags_t
---@field to_quoted_string  fun(table: table, separator: string|nil): string
---@field indices           fun(table: table): fun(): integer
---@field entries           fun(table: table): fun(): any
---@field unique_entries    fun(table: table): fun(): any
---@field sorted_entries    fun(table: table): fun(): any
---@field items             fun(...): fun(): any
---@field unique_items      fun(...): fun(): integer
---@field sorted_items      fun(...): fun(): integer
---@field keys              fun(table: table): fun(): any
---@field values            fun(table: table): fun(): any
---@field sorted_values     fun(table: table, exclude: fun(value: any): boolean): fun(): any
---@field sorted_pairs      fun(table: table, exclude: fun(value: any): boolean): fun(): any, any
---@field first_of          fun(...): any
---@field second_of         fun(...): any
---@field trim              fun(in: string): string
---@field extend_with       fun(holder: table, addendum: table, can_overwrite: boolean): boolean|nil
---@field readonly          fun(t: table, quiet: boolean): table
---@field is_readonly       fun(t: table): boolean
---@field shallow_copy      fun(original: any): any
---@field deep_copy         fun(original: any): any
---@field bridge            fun(kv: bridge_kv_t): table
---@field to_ymd_hms        fun(diff: integer): string
---@field print_diff_time   fun(format: string, diff: integer)

return {
  Vars              = Vars,
  flags             = flags,
  to_quoted_string  = to_quoted_string,
  indices           = indices,
  entries           = entries,
  unique_entries    = unique_entries,
  sorted_entries    = sorted_entries,
  items             = items,
  unique_items      = unique_items,
  sorted_items      = sorted_items,
  keys              = keys,
  values            = values,
  sorted_values     = sorted_values,
  sorted_pairs      = sorted_pairs,
  first_of          = first_of,
  second_of         = second_of,
  trim              = trim,
  extend_with       = extend_with,
  readonly          = readonly,
  is_readonly       = is_readonly,
  shallow_copy      = shallow_copy,
  deep_copy         = deep_copy,
  bridge            = bridge,
  to_ymd_hms        = to_ymd_hms,
  print_diff_time   = print_diff_time,
}
