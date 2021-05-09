#!/usr/bin/env texlua
--[[
  This is a test file for l3build package.
  It is only intending for development and should appear in any distribution of the l3build package.
  For help, run `texlua ../l3build.lua test -h`
--]]

local push = table.insert

---@type utlib_t
local utlib = require("l3b-utillib")

local expect  = _ENV.expect

local function test_readonly()
  local is_readonly = utlib.is_readonly
  local rw = {}
  local ro = utlib.readonly(rw)
  rw.foo = 421
  expect(ro.foo).is(421)
  expect(ro.bar).is(nil)
  expect(function () ro.bar = 421 end).error()
  expect(function () is_readonly(1) end).error()
  expect(is_readonly(rw)).is(false)
  expect(is_readonly(ro)).is(true)
end

local function test_to_quoted_string()
  local to_quoted_string = utlib.to_quoted_string
  expect(to_quoted_string( "" )).is('""')
  expect(to_quoted_string( "" )).is('""')
  expect(to_quoted_string( "a" )).is('"a"')
  expect(to_quoted_string( { "a", "b" } )).is('"a" "b"')
end

local function test_indices()
  local track = {}
  for i in utlib.indices({}) do
    push(track, i)
  end
  expect(track).equals({})
  for i in utlib.indices({ "1", "2", "3" }) do
    push(track, i)
  end
  expect(track).equals({ 1, 2, 3 })
end

local function test_entries()
  local entries = utlib.entries
  local track = {}
  for entry in entries({}) do
    push(track, entry)
  end
  expect(track).equals({})
  for entry in entries({ 1, 3, 2 }) do
    push(track, entry)
  end
  expect(track).equals({ 1, 3, 2 })
  track = {}
  for entry in entries({ 1, 3, 3, 2, 1 }, { unique = true }) do
    push(track, entry)
  end
  expect(track).equals({ 1, 3, 2 })
  track = {}
  for entry in entries({ 1, 3, 3, 2, 1 }, { compare = utlib.compare_ascending }) do
    push(track, entry)
  end
  expect(track).equals({ 1, 1, 2, 3, 3 })
  track = {}
  for entry in entries({ 1, 3, 3, 2, 1 }, { compare = utlib.compare_descending }) do
    push(track, entry)
  end
  expect(track).equals({ 3, 3, 2, 1, 1 })
  track = {}
  for entry in entries({ 1, 3, 3, 2, 1 }, {
    compare = utlib.compare_descending,
    unique = true
  }) do
    push(track, entry)
  end
  expect(track).equals({ 3, 2, 1 })
  track = {}
  for entry in entries({ 1, 3, 3, 2, 1 }, {
    compare = utlib.compare_descending,
    unique = true,
    exclude = function (x)
      return x == 2
    end,
  }) do
    push(track, entry)
  end
  expect(track).equals({ 3, 1 })
end

local function test_items()
  local track = {}
  for i in utlib.items() do
    push(track, i)
  end
  expect(track).equals({ })
  track = {}
  for i in utlib.items( 1, 2, 3 ) do
    push(track, i)
  end
  expect(track).equals({ 1, 2, 3 })
end

local function test_unique_items()
  local track = {}
  for i in utlib.unique_items() do
    push(track, i)
  end
  expect(track).equals({ })
  for i in utlib.unique_items( 1, 2, 2, 3, 3, 3 ) do
    push(track, i)
  end
  expect(track).equals({ 1, 2, 3 })
end

local function test_keys()
  local keys = utlib.keys
  local track = {}
  for k in keys({}) do
    push(track, k)
  end
  expect(track).equals({})
  for k in keys({
    a = 1,
    c = 3,
    b = 2,
  }) do
    track[k] = true
  end
  expect(track).equals({ a = true, b = true, c = true })
  track = {}
  for k in keys({
    a = 1,
    c = 3,
    b = 2,
  }, utlib.compare_ascending) do
    push(track, k)
  end
  expect(track).equals({ "a", "b", "c" })
  track = {}
  for k in keys({
    a = 1,
    c = 3,
    b = 2,
  }, utlib.compare_descending) do
    push(track, k)
  end
  expect(track).equals({ "c", "b", "a", })
end

local function test_sorted_pairs()
  local track = {}
  local sorted_pairs = utlib.sorted_pairs
  for k, v in sorted_pairs({}) do
    push(track, k)
  end
  expect(track).equals({})
  track = {}
  for k, v in sorted_pairs({
    a = 1,
    c = 3,
    b = 2,
  }, { compare = utlib.compare_ascending}) do
    push(track, k)
  end
  expect(track).equals({ "a", "b", "c" })
  track = {}
  for k, v in sorted_pairs({
    a = 1,
    c = 3,
    b = 2,
  }, { compare = utlib.compare_descending}) do
    push(track, k)
  end
  expect(track).equals({ "c", "b", "a" })
end

local function test_values()
  local track = {}
  local values = utlib.values
  for k, v in values({}) do
    push(track, k)
  end
  expect(track).equals({})
  track = {}
  for k, v in values({
    a = 1,
    c = 3,
    b = 2,
  }, { compare = utlib.compare_ascending}) do
    push(track, k)
  end
  expect(track).equals({ 1, 2, 3 })
  track = {}
  for k, v in values({
    a = 1,
    c = 3,
    b = 2,
  }, { compare = utlib.compare_descending}) do
    push(track, k)
  end
  expect(track).equals({ 3, 2, 1 })
end

local function test_first_of()
  local first_of = utlib.first_of
  expect(first_of()).is(nil)
  expect(first_of(1)).is(1)
  expect(first_of(1, 2)).is(1)
end

local function test_second_of()
  local second_of = utlib.second_of
  expect(second_of()).is(nil)
  expect(second_of(1)).is(nil)
  expect(second_of(1, 2)).is(2)
  expect(second_of(1, 2, 3)).is(2)
end

local function test_trim()
  local trim = utlib.trim
  expect(trim("")).is("")
  expect(trim(" ")).is("")
  expect(trim(" a")).is("a")
  expect(trim("a ")).is("a")
  expect(trim(" a ")).is("a")
  expect(trim(" a b ")).is("a b")
end

local function test_extend_with()
  local extend_with = utlib.extend_with
  local t = {}
  extend_with(t, {})
  expect(t).equals({})
  t = {}
  extend_with(t, { foo = 1 } )
  expect(t).equals({ foo = 1 })
  extend_with(t, { bar = 2 } )
  expect(t).equals({ foo = 1, bar = 2 })
  extend_with(t, { bar = 3 }, true )
  expect(t).equals({ foo = 1, bar = 3 })
  expect(function () extend_with(t, { bar = 4 } ) end).error()
end

local function test_to_ymd_hms()
  local to_ymd_hms = utlib.to_ymd_hms
  local diff =
    19 + 60 * (18 + 60 * 17)
  expect(to_ymd_hms(diff)).is(" 17:18:19")
  diff =
    15 + 60 * (
    14 + 60 * (
    13 + 24 * (
    12 + 30 * (
    11 + 12 * (
    10
    )))))
    expect(to_ymd_hms(diff)).is("10 years, 11 months, 12 days 13:14:15")
end

local function test_is_error()
  local is_error = utlib.is_error
  expect(is_error(nil)).is(false)
  expect(is_error(0)).is(false)
  expect(is_error(math.random(999999))).is(false)
end

return {
  test_readonly         = test_readonly,
  test_to_quoted_string = test_to_quoted_string,
  test_indices          = test_indices,
  test_entries          = test_entries,
  test_items            = test_items,
  test_unique_items     = test_unique_items,
  test_keys             = test_keys,
  test_sorted_pairs     = test_sorted_pairs,
  test_values           = test_values,
  test_first_of         = test_first_of,
  test_second_of        = test_second_of,
  test_trim             = test_trim,
  test_extend_with      = test_extend_with,
  test_to_ymd_hms       = test_to_ymd_hms,
  test_is_error         = test_is_error,
}

--[=====[


local type    = type
local print   = print
local rawget  = rawget
local assert  = assert
local pairs   = pairs
local next    = next

local sort        = table.sort
local push      = table.insert
local concat      = table.concat
local tbl_unpack  = table.unpack

--[=[ Package implementation ]=]

local MT = getmetatable("")
function MT.__div(a, b)
  return a .."/".. b
end

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
---@field public debug flags_t

---@type utlib_vars_t
local Vars = {
  debug = {}
}

---@alias error_level_n integer

---Turn the string list into quoted items separated by a sep
---@param table table
---@param separator string|nil @defaults to " "
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
---@param reverse boolean @true for reverse ordering
---@return fun(): integer|nil
---@usage `for i in indices(t) do ... end` instead of `for i = 1, #t do ... end`
local function indices(table, reverse)
  if reverse then
    local i = #table + 1
    return function ()
      i = i - 1
      return i > 0 and i or nil
    end
  else
    local i = 0
    return function ()
      i = i + 1
      return i <= #table and i or nil
    end
  end
end

---Compare function to sort in reverse order
---@param a any @comparable with <
---@param b any @comparable with <
---@return boolean
local function compare_descending(a, b)
  return a > b
end

-- Ascending counterpart. Implemented for balancing reasons
-- despite it is the default behavior in `table.sort`.
---Compare function to sort in default order.
---@param a any @comparable with <
---@param b any @comparable with <
---@return boolean
local function compare_ascending(a, b)
  return a < b
end


---@alias compare_f  fun(a: any, b: any): boolean

---@alias exclude_f  fun(value: any): boolean

---@class iterator_kv_t
---@field public unique boolean
---@field public compare compare_f
---@field public exclude exclude_f

---@alias iterator_f fun(): any

---Iterator for the entries of a sequencial table
---No ordering when compare is not provided.
---@generic T
---@param table T[]
---@param kv    iterator_kv_t
---@return fun(): T|nil
local function entries(table, kv)
  local function raw_iterator(t)
    local i = 0
    return function ()
      i = i + 1
      if not t then
        print(debug.traceback())
      end
      return t[i]
    end
  end
  if not kv then
    return raw_iterator(table)
  end
  if kv.compare then
    table = { tbl_unpack(table) }
    sort(table, kv.compare)
  end
  local iterator = raw_iterator(table)
  if not kv.exclude then
    return iterator
  end
  local already = {}
  return function ()
    repeat
      local result = iterator()
      if result == nil then -- end of iteration
        return result
      elseif not kv.unique or not already[result] then
        if not kv.exclude or not kv.exclude(result) then
          already[result] = true
          return result
        end
      end
    until false
  end
end

---Iterator for the items given in arguments
---@vararg any
---@return iterator_f
---@usage `for item in items(a, b, c) do ... end`
local function items(...)
  return entries({ ... })
end

---Iterator for the items given in arguments
---Every item is ignored when already listed.
---@vararg any
---@return iterator_f
---@usage `for item in unique_items(a, b, c) do ... end`
local function unique_items(...)
  return entries({ ... }, { unique = true })
end

---Keys iterator, possibly sorted.
---No defaultordering when no comparator is given.
---@generic K, V
---@param table     table<K,V>
---@param compare?  fun(l: K, r: K): boolean
---@return fun(): K|nil
local function keys(table, compare)
  local kk = {}
  for k, _ in pairs(table) do
    push(kk, k)
  end
  return entries(kk, { compare = compare })
end

---@class sorted_kv_t
---@field public compare compare_f
---@field public exclude exclude_f

---Iterates over the values of the table.
---Values are sorted according to the keys ordering.
---Values are filtered out by the excluder.
---@generic K, V
---@param table table<K,V>
---@param kv? sorted_kv_t
---@return fun(): K|nil, V|nil
local function sorted_pairs(table, kv)
  kv = kv or {}
  local iterator = keys(table, kv.compare)
  return function ()
    repeat
      local k = iterator()
      if k == nil then
        return
      end
      local value = table[k]
      if not kv.exclude or not kv.exclude(value) then
        return k, value
      end
    until false
  end
end

---Iterates over the values of the table
---Values are sorted according to the keys ordering.
---Values are filtered.
---@generic K, V
---@param table table<K,V>
---@param kv? sorted_kv_t
---@return fun(): V|nil
local function values(table, kv)
  local iterator = sorted_pairs(table, kv)
  return function ()
    repeat
      local _, v = iterator()
      return v
    until false
  end
end

---Return the first argument
---@generic T
---@param first T
---@return T
---@usage `first_of(gsub(...))`
local function first_of(first)
  return first
end

---Return the second argument
---@generic T
---@param _ any
---@param second T
---@return T
---@usage `second_of(...)`
local function second_of(_, second)
  return second
end

---Return a copy of s without heading nor trailing spaces.
---@param s string
---@return string
local function trim(s)
  return s:match("^%s*(.-)%s*$")
end

---Merge in place `holder` with `addendum`.
---@generic K, V
---@param holder table<K,V> @The receiver
---@param addendum table<K,V> @What is merged into the receiver
---@param can_overwrite? boolean @if falsy overwriting is an error
---@return table<K,V> @holder
local function extend_with(holder, addendum, can_overwrite)
  for key, value in pairs(addendum) do
    assert(can_overwrite or not holder[key], "Conflicting symbol ".. tostring(key))
    holder[key] = value
  end
  return holder
end

---Make a shallow copy of the given object,
---taking the metatable into account.
---@generic T
---@param original T
---@return T
local function shallow_copy(original)
  local res = {}
  for k, v in next, original do res[k] = v end
  return setmetatable(res, getmetatable(original))
end

--https://gist.github.com/tylerneylon/81333721109155b2d244#gistcomment-3262222
---Make a deep copy of the given object
---@generic T
---@param original T
---@return T
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

--[==[ Bridge business
Some proxy of both primary and secondary tables,
with supplemental computed properties given by index.
--]==]

---@class bridge_kv_t
---@field public prefix    string
---@field public suffix    string
---@field public index     fun(t: table, k: any): any
---@field public newindex  fun(t: table, k: any, result: any): boolean
---@field public complete  fun(t: table, k: any, result: any): any
---@field public map       table<string,string>
---@field public primary   table @the main object, defaults to _G
---@field public secondary table @the secondary object

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
        if result == nil and kv.index then
          result = kv.index(t, k)
        end
        if kv.complete then
          result = kv.complete(t, k, result)
        end
        if kv.secondary then
          local result_2 = kv.secondary[k_G]
          if  result ~= result_2
          and type(result)   == "table"
          and type(result_2) == "table"
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
      push(display_date, ("%d %s"):format(n, item))
    end
  end
  local display_time = {}
  for item in items("hour", "min", "sec") do
    local n = diff_date[item]
    push(display_time, ("%02d"):format(n))
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

---@alias flags_t table<string,boolean>

---@type flags_t
local flags = {}

---@class utlib_t
---@field public Vars               utlib_vars_t
---@field public flags              flags_t
---@field public to_quoted_string   fun(table: table, separator: string|nil): string
---@field public indices            fun(table: table, reverse: boolean): fun(): integer
---@field public compare_ascending  compare_f
---@field public compare_descending compare_f
---@field public entries            fun(table: table, kv: sorted_kv_t): iterator_f
---@field public items              fun(...): iterator_f
---@field public unique_items       fun(...): iterator_f
---@field public keys               fun(table: table, compare: compare_f): iterator_f
---@field public sorted_pairs       fun(table: table, kv: sorted_kv_t): fun(): any, any
---@field public values             fun(table: table, kv: sorted_kv_t): iterator_f
---@field public first_of           fun(...): any
---@field public second_of          fun(...): any
---@field public trim               fun(in: string): string
---@field public extend_with        fun(holder: table, addendum: table, can_overwrite: boolean): boolean|nil
---@field public readonly           fun(t: table, quiet: boolean): table
---@field public is_readonly        fun(t: table): boolean
---@field public shallow_copy       fun(original: any): any
---@field public deep_copy          fun(original: any): any
---@field public bridge             fun(kv: bridge_kv_t): table
---@field public to_ymd_hms         fun(diff: integer): string
---@field public print_diff_time    fun(format: string, diff: integer)

return {
  Vars                = Vars,
  flags               = flags,
  to_quoted_string    = to_quoted_string,
  indices             = indices,
  entries             = entries,
  items               = items,
  unique_items        = unique_items,
  compare_ascending   = compare_ascending,
  compare_descending  = compare_descending,
  keys                = keys,
  sorted_pairs        = sorted_pairs,
  values              = values,
  first_of            = first_of,
  second_of           = second_of,
  trim                = trim,
  extend_with         = extend_with,
  readonly            = readonly,
  is_readonly         = is_readonly,
  shallow_copy        = shallow_copy,
  deep_copy           = deep_copy,
  bridge              = bridge,
  to_ymd_hms          = to_ymd_hms,
  print_diff_time     = print_diff_time,
}
]=====]