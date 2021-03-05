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

local next = next
local concat = table.concat
local open = io.open

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

---if filename is non nil and file readable return contents otherwise nil
---@param file_path string
---@param is_binary boolean
---@return string? the content of the file
---@return string? an error message
local function read_content(file_path, is_binary)
  if file_path then
    local fh = open(file_path, is_binary and "rb" or "r")
    if not fh then return nil end
    local contents = fh:read("a")
    fh:close()
    return contents
  end
end

---if filename is non nil and file readable return contents otherwise nil
---@param file_path string
---@param content string
---@return error_level_t
local function write_content(file_path, content)
  if file_path then
    local fh, err = assert(open(file_path, "w"))
    if not fh then return 1 end
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

---@class chooser_kv_t
---@field prefix string|nil -- prepend this prefix to the key for G, not for dflt
---@field suffix string|nil -- append this prefix to the key for G, not for dflt

---Return an object that picks its attributes from G or dflt
---Central method in variables management.
---If `dflt` defines a function for key `DID_CHOOSE`,
---it will be used to apply a post treatment to the result.
---This postflight function has signature fun(result: any, k: string): any
---For example, returned directory paths may be normalized that way.
---If the key starts with "_", `G` is ignored (key is private).
---@param G       any, in general _G
---@param dflt    any
---@param kv      chooser_kv_t
---@return fun(t: table, k: any): any
local function chooser(G, dflt, kv)
  local function __index(t, k)        -- will end in a metatable just below
    local dflt_k = dflt[k]            -- default candidate
    if dflt_k == nil then return end  -- unknown key, stop here
    if k:sub(1, 1) == "_" then -- private key
      -- cache the result if any such that next time, __index is not called
      if flags.cache_chosen then
        t[k] = dflt_k
      end
      return dflt_k
    end
    local result
    local kk = k
    if kv and type(k) == "string" then -- modify the global key
      if kv.prefix then kk = kv.prefix .. k end
      if kv.suffix then kk = k .. kv.suffix end
    end
    local G_kk = G[kk]                -- global candidate
    if not G_kk then
      result = dflt_k                 -- choose the default candidate
    else
      local type_G_kk = type(G_kk)
      local type_dflt_k = type(dflt_k)
      if type_G_kk ~= type_dflt_k then   -- wrong type, global candidate is not acceptable
        error("Global ".. k .." must be a ".. type_dflt_k ..", not a ".. type_G_kk)
      end
      result = type_G_kk == "table"
        and chooser(G_kk, dflt_k)
        or  G_kk
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

  return setmetatable({}, { __index = __index })
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
---@field chooser           fun(G: table, dflt: table): fun(t: table, k: any): any

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
