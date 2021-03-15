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
local open    = io.open
local os_type = os["type"]

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

---if filename is non nil and file readable return contents otherwise nil.
---The content is converted to unix line ending when not binary.
---@param file_path string
---@param is_binary boolean
---@return string? the content of the file
---@return string? an error message
local function read_content(file_path, is_binary)
  if file_path then
    local fh = open(file_path, is_binary and "rb" or "r")
    if not fh then
      return
    end
    local content = fh:read("a")
    fh:close()
    return not is_binary and os_type == "windows"
      and content:gsub("\r\n?", "\n")
      or  content
  end
end

---if filename is non nil and file readable return contents otherwise nil
---Before write, the content is converted to host line ending.
---@param file_path string
---@param content string
---@return error_level_n
local function write_content(file_path, content)
  if file_path then
    local fh = assert(open(file_path, "w"))
    if not fh then
      return 1
    end
    if os_type == "windows" then
      content = content:gsub("\n", _G.os_newline)
    end
    local error_level = fh:write(content) and 0 or 1
    fh:close()
    return error_level
  end
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


--[==[ Chooser business ]==]

---@class ut_flags_t
---@field cache_chosen boolean

---@type_t ut_flags_t
local flags = {}

---@alias chooser_t table
---@alias chooser_computed_f  fun(t: table, k: any, v_dflt: any): any
---@alias chooser_fallback_f  fun(t: table, k: any, v_dflt: any, v_G: any): any
---@alias chooser_complete_f  fun(t: table, k: any, result: any): any

---@class chooser_kv_t
---@field global    table
---@field default   table
---@field prefix    string|nil prepend this prefix to the key for G, not for dflt
---@field suffix    string|nil append this prefix to the key for G, not for dflt
---@field computed  table<string, chooser_computed_f>
---@field fallback  chooser_fallback_f if the global value is not acceptable, this is a possible fallback.
---@field complete  chooser_complete_f

--[=[
The purpose of the next chooser function is to allow
the customization of a tree from the global domain.
A tree starts at some variable.
If the variable is a table with no metatable,
this is a node, otherwise it is a leaf. This applies recursively to the fields.
Then for
```
local c = chooser({ global = G, default = dflt })
```
`c.foo.bar` is
- nil if no `dflt.foo.bar` exists
- `dflt.foo.bar` if no `G.foo.bar` exists
- `dflt.foo.bar` if `dflt.foo.bar` and `G.foo.bar` have different type
- `G.foo.bar` if it is not a table
- `G.foo.bar` if `dflt.foo.bar` is a non void sequence
- `G.foo.bar` if `dflt.foo.bar` is empty
- `G.foo.bar` if `dflt.foo.bar` and `G.foo.bar` have the same non nil metatable
- chooser({ global = G.foo.bar, default = dflt.foo.bar }) otherwise

Things get a bit more complicated by computed properties.
Help is provided by `kv` fields `compute` and `fallback`.
Given a key k, we have 4 candidates
1) the default one dflt_k
2) comp_k computed from dflt_k with some `compute` field
3) the global one G_k
If we have neither dflt_k nor comp_k, the key k is unknown.
The latter takes precedence over the former.
If G_k s incompatible with dflt_k and comp_k,
then the `fallback` field is asked for an alernate value.
--]=]

---See above
---@param kv chooser_kv_t
---@return chooser_t
local chooser

do
  local KEY_kv = {} -- unique key

  -- shared indexer
  local chooser_MT = {
    __index = function (t --[[:table]], k --[[:any]])
      local kv = rawget(t, KEY_kv)
      local dflt = kv.default
      ---@type chooser_kv_t
      local dflt_k = dflt[k]  -- default candidate
      local function postflight(result)
        ---@type chooser_complete_f
        local complete = kv.complete
        if complete then
          result = complete(t, k, result)
        end
        -- cache the result if any such that next time, __index is not called
        if flags.cache_chosen and result ~= nil then
          rawset(t, k, result)
        end
        return result
      end
      ---@type chooser_computed_f
      local computed = kv.computed
      if computed then
        local comp_k = computed[k]
        if comp_k ~= nil then
          comp_k = comp_k(t, k, dflt_k) -- a computed property is available
          if comp_k ~= nil then
            dflt_k = comp_k
          end
        end
      end
      if dflt_k == nil then   -- unknown key, neither default nor computed
        return                -- stop here
      end
      local result
      local G = kv.global.G
      local kk = k
      if type(k) == "string" then
        if Vars.debug.chooser then
          print("DEBUG chooser", k)
        end
        if kv.prefix then kk = kv.prefix .. k end
        if kv.suffix then kk = k .. kv.suffix end
      end
      local G_kk = G[kk]                -- global candidate
      if G_kk == nil then
        result = dflt_k   -- choose the default candidate
      else
        local type_dflt_k = type(dflt_k)
        local type_G_kk   = type(G_kk)
        if type_G_kk ~= type_dflt_k then   -- wrong type, global candidate is not acceptable
          ---@type chooser_fallback_f
          local fallback = kv.fallback
          if fallback then -- the index function take precedence
            result = fallback(t, k, dflt_k, G_kk)
            if result ~= nil then
              return postflight(result)
            end
          end
          error("Global ".. k .." must be a ".. type_dflt_k ..", not a ".. type_G_kk)
        end
        if type_dflt_k == "table" then
          if #dflt_k > 0 then
            result = G_kk -- accept sequences as is
          elseif not next(dflt_k) then
            result = G_kk -- accept non void tables as is
          elseif dflt_k[KEY_kv] ~= nil then -- this is a chooser
            dflt_k[KEY_kv].global = G_kk -- now this chooser has a global
            return dflt_k
          else
            local MT = getmetatable(dflt_k)
            if MT then
              if MT ~= getmetatable(G_kk) then
                error("Incompatible objects with different metatables")
              end
              result = G_kk -- accept tables with the same metatable. Unused yet.
            else
              result = chooser({ -- return a proxy
                global = { G = G_kk },
                default = dflt_k
              })
            end
          end
        else
          result = G_kk -- accept candidate when not a table
        end
      end
      return postflight(result)
    end
  }
  chooser = function (kv)
    local result = setmetatable({
      [KEY_kv] = shallow_copy(kv)
    }, chooser_MT)
    return result
  end
end

---@class utlib_t
---@field Vars              utlib_vars_t
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
---@field read_content      fun(file_pat: string, is_binary: boolean): string|nil
---@field write_content     fun(file_pat: string, content: string): error_level_n
---@field flags             ut_flags_t
---@field readonly          fun(t: table, quiet: boolean): table
---@field is_readonly       fun(t: table): boolean
---@field shallow_copy      fun(original: any): any
---@field deep_copy         fun(original: any): any
---@field chooser           fun(G: table, dflt: table, kv: chooser_kv_t): chooser_t

return {
  Vars              = Vars,
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
  read_content      = read_content,
  flags             = flags,
  readonly          = readonly,
  is_readonly       = is_readonly,
  write_content     = write_content,
  shallow_copy      = shallow_copy,
  deep_copy         = deep_copy,
  chooser           = chooser,
}
