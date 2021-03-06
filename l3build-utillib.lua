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

-- Aliases
---@alias string_list_t table<integer, string>
-- local safety guards and shortcuts

local next    = next
local concat  = table.concat
local open    = io.open
local os_type = os["type"]

---@alias error_level_t integer

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

---Iterator for the entries of a sequencial table
---@param table table
---@return fun()
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
    if not fh then return end
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
---@return error_level_t
local function write_content(file_path, content)
  if file_path then
    local fh = assert(open(file_path, "w"))
    if not fh then return 1 end
    if os_type == "windows" then
      content = content:gsub("\n", os_newline)
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
local function deep_copy(original)
  local seen = {}
  local function f(obj)
    if type(obj) ~= 'table' then return obj end   -- return as is
    if seen[obj] then return seen[obj] end        -- return already see if any
    local res = {}                                -- make a new table
    seen[obj] = res                               -- mark it as seen
    for k, v in next, obj do res[f(k)] = f(v) end -- copy recursively
    return setmetatable(res, getmetatable(obj))
  end
  return f(original)
end

-- Unique key
local DID_CHOOSE = {}

---@class ut_flags_t
---@field cache_chosen boolean

---@type_t ut_flags_t
local flags = {}

---@alias chooser_t table

---@class chooser_kv_t
---@field prefix string|nil -- prepend this prefix to the key for G, not for dflt
---@field suffix string|nil -- append this prefix to the key for G, not for dflt

--[=[
The purpose of the next chooser function is to allow the customization of a tree from the global domain.
A tree starts at some variable. If the variable is a table with no metatable,
this is a node, otherwise it is a leaf. This applies recursively to the fields.
Then for
```
local c = chooser(G, dflt)
```
`c.foo.bar` is
- nil if no `dflt.foo.bar` exists
- `dflt.foo.bar` if no `G.foo.bar` exists
- `dflt.foo.bar` if `dflt.foo.bar` and `G.foo.bar` have different type
- `G.foo.bar` if it is not a table
- `G.foo.bar` if `dflt.foo.bar` and `G.foo.bar` have the same non nil metatable
- chooser(G.foo.bar, dflt.foo.bar) otherwise
--]=]

local chooser

do
  local key_G, key_dflt, key_kv = {}, {}, {} -- unique keys
  -- shared indexer
  local chooser_MT = {
    __index = function (t, k)
      local dflt = t[key_dflt]
      local dflt_k = dflt[k]            -- default candidate
      if dflt_k == nil then return end  -- unknown key, stop here
      local k_is_string = type(k) == "string"
      if k_is_string and k:sub(1, 1) == "_" then -- private key
        -- cache the result if any such that next time, __index is not called
        if flags.cache_chosen then
          t[k] = dflt_k
        end
        return dflt_k
      end
      local result
      local kk = k
      local kv = t[key_kv]
      if kv and k_is_string then -- modify the global key
        if kv.prefix then kk = kv.prefix .. k end
        if kv.suffix then kk = k .. kv.suffix end
      end
      local G = t[key_G]
      local G_kk = G[kk]                -- global candidate
      if not G_kk then
        result = dflt_k                 -- choose the default candidate
      else
        local type_dflt_k = type(dflt_k)
        local type_G_kk   = type(G_kk)
        if type_G_kk ~= type_dflt_k then   -- wrong type, global candidate is not acceptable
          error("Global ".. k .." must be a ".. type_dflt_k ..", not a ".. type_G_kk)
        end
        if type_dflt_k == "table" then
          local MT = getmetatable(dflt_k)
          if MT then
            if MT ~= getmetatable(G_kk) then
              error("Incompatible objects with different metatables")
            end
            result = G_kk
          else
            result = chooser(G_kk, dflt_k)
          end
        else
          result = G_kk
        end
      end
      -- post treatment
      local did_choose = dflt[DID_CHOOSE]
      if did_choose then
        result = did_choose(result, k)
      end
      -- cache the result if any such that next time, __index is not called
      if flags.cache_chosen and result ~= nil then
        t[k] = result
      end
      return result
    end

  }
  chooser = function (G, dflt, kv)
    return setmetatable({
      [key_G]     = G,
      [key_dflt]  = dflt,
      [key_kv]    = kv,
    }, chooser_MT)
  end
end

---@class utlib_t
---@field to_quoted_string  fun(table: table, separator: string|nil): string
---@field indices           fun(table: table): fun(): integer
---@field entries           fun(table: table): fun(): any
---@field items             fun(...): fun(): any
---@field unique_entries    fun(table: table): fun(): any
---@field unique_items      fun(...): fun(): integer
---@field keys              fun(table: table): fun(): any
---@field values            fun(table: table): fun(): any
---@field first_of          fun(...): any
---@field second_of         fun(...): any
---@field trim              fun(in: string): string
---@field extend_with       fun(holder: table, addendum: table, can_overwrite: boolean): boolean|nil
---@field read_content      fun(file_pat: string, is_binary: boolean): string|nil
---@field write_content     fun(file_pat: string, content: string): error_level_t
---@field deep_copy         fun(original: any): any
---@field DID_CHOOSE        any
---@field flags             ut_flags_t
---@field chooser           fun(G: table, dflt: table, kv: chooser_kv_t): chooser_t

return {
  to_quoted_string  = to_quoted_string,
  indices           = indices,
  entries           = entries,
  items             = items,
  unique_entries    = unique_entries,
  unique_items      = unique_items,
  keys              = keys,
  values            = values,
  first_of          = first_of,
  second_of         = second_of,
  trim              = trim,
  extend_with       = extend_with,
  read_content      = read_content,
  write_content     = write_content,
  deep_copy         = deep_copy,
  flags             = flags,
  DID_CHOOSE        = DID_CHOOSE,
  chooser           = chooser,
}
