--[[

File l3build-arguments.lua Copyright (C) 2018-2020 The LaTeX Project

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

local append    = table.insert

local stderr  = io.stderr

---@type utlib_t
local utlib             = require("l3b-utillib")
local readonly          = utlib.readonly
local values            = utlib.values
local compare_ascending = utlib.compare_ascending

--[=[ Package implementation ]=]

---@class options_flags_t
---@field debug boolean

---@type options_flags_t
local flags = {}

---@class options_base_t

---@alias option_type_f fun(options: table, key: string, value: string): error_level_n

---@class option_info_t
---@field description  string  short description
---@field type  "boolean"|"string"|"number"|option_type_f|nil How to manage values.
---@field short string|nil  short CLI key
---@field long  string  long CLI key
---@field name  string  name in the options table
---@field expect_value  boolean False for boolean type, true for the others.
---@field load_value    fun(options: table, key: string, value?: string): error_level_n load the given value
---@field builtin       boolean whether the option is builtin

---@type table<string, option_info_t>
local by_key = {}
---@type table<string, option_info_t>
local by_name = {}
---@type table<string, option_info_t>
local by_long = {}

---Return the option info for the given key.
---An option info is meant read only.
---`key` is "version", "v"...
---@param key string
---@return option_info_t
local function get_info_by_key(key)
  return  by_key[key]
end

---Return the option info for the given key.
---An option info is read only.
---`key` is "version", "v"...
---@param name string
---@return option_info_t
local function get_info_by_name(name)
  return  by_name[name]
end

---Enumerator of all the target infos.
---Sorted by name
---@param hidden boolean true to list all hidden targets too.
---@return function
local function get_all_info(hidden)
  return values(by_long, {
    compare = compare_ascending,
    exclude = function (info)
      return not info.description
    end,
  })
end

---Load the given value in the given table
---Raise an error if no value is required
---@param options table
---@param key     string
---@param value?  string
---@return error_level_n
local function load_value(self, options, key, value)
  if self.type == "boolean" then
    options[self.name] = not key:match("^no-")
  elseif self.type == "string" then
    options[self.name] = value
  elseif self.type == "number" then
    options[self.name] = tonumber(value)
  elseif type(self.type) == "function" then
    return self.type(options, key, value)
  else -- string sequence
    local t = options[self.name] or {}
    options[self.name] = t
    append(t, value)
  end
  return 0
end

local chooser_index = function (t, k)
  if k == "expect_value" then
    if flags.debug then
      print("DEBUG options parse expect_value:", t.type)
    end
    return t.type ~= "boolean"
  end
  if k == "short" then
    return nil
  end
  if k == "load_value" then
    return load_value
  end
  print(debug.traceback())
  error("Unknown field name ".. k)
end

---Register the given option.
---If there is a conflict, an error is raised.
---@param info    option_info_t
---@param builtin boolean|nil
local function register(info, builtin)
  local long  = info.long
  if by_key[long] then
    error("Option aleady registered for key".. long)
  end
  local short = info.short
  if short then
    if #short > 1 then
      error("Short option is too long: ".. short)
    end
    if by_key[short] then
      error("Option aleady registered for key".. short)
    end
  end
  local name  = info.name or long
  if by_name[name] then
    error("Option aleady registered for name".. name)
  end
  if name == "target" or name == "names" then
    error("Reserved option name ".. name)
  end
  assert(info.type)
  info = {
    short = short,
    long = long,
    name = name,
    description = info.description,
    type = info.type,
    builtin = builtin and true or false,
  }
  info = setmetatable(info, {
    __index = chooser_index
  })
  info = readonly(info)
  by_name[name] = true
  by_long[long] = info
  by_key[long]  = info
  if short then
    by_key[short] = info
  end
end

-- This is done as a function (rather than do ... end) as it allows early
-- termination (break)
---When the key is not recognized by the system,
---`on_unknown` gets a chance to recognize it.
---When this function returns `nil` it means no recognition.
---When it returns 0, all is ok otherwise an error occurred.
---@param arg table
---@param on_unknown fun(key: string): boolean|fun(any: any, options: options_base_t) true when catched, false otherwise
---@return table
local function parse(arg, on_unknown)
  local result = {
    target = "help",
  }
  -- arg[1] is a special case: must be a command or "-h"/"--help"
  -- Deal with this by assuming help and storing only apparently-valid
  -- input
  local a = arg[1]
  if a then
    -- No options are allowed in position 1, so filter those out
    if a == "--version" then
      result.target = "version"
    elseif not a:match("^%-") then
      result.target = a
    end
  end
  -- Stop here if help or version is required
  if result.target == "help" or result.target == "version" then
    return result
  end
  -- Examine all other arguments
  -- Use a while loop rather than for as this makes it easier
  -- to grab arg for optionals where appropriate
  local i = 1
  while true do
    ::top::
    i = i + 1
    local arg_i = arg[i]
    if not arg_i then
      break
    end
    if flags.debug then
      print("DEBUG options parse:", arg_i)
    end
    if arg_i == "-" or arg_i == "--" then
      i = i + 1
      break
    end
    -- Terminate search for options
    local k, v = arg_i:match("^%-%-([^=]*)=?(.*)")
    if not k then
      -- this is not a long argument
      k, v = arg_i:match("^%-(.)=?(.*)")
      if not k then
        -- this is not short argument either,
        -- forthcoming arguments are names
        break
      end
      if flags.debug then
        print("DEBUG options parse: short")
      end
    else
      if flags.debug then
        print("DEBUG options parse: long")
      end
    end
    ---@type option_info_t
    local info = get_info_by_key(k)
    if not info then
      if on_unknown then
        local catched = on_unknown(k)
        if type(catched) == "function" then
          -- this is a callback to require an associate value
          if #v == 0 then
            i = i + 1
            v = arg[i]
            if v == nil then
              error("Missing option value for ".. arg_i);
            end
          end
          if flags.debug then
            print("DEBUG options parse: catched unknown with value")
          end
          catched(v, result)
        elseif catched then
          if #v > 1 then
            error("Unexpected option value in ".. arg_i .."/".. v);
          end
          if flags.debug then
            print("DEBUG options parse: catched unknown")
          end
          goto top
        end
      end
      stderr:write("Unknown option " .. arg_i .."\n")
      return { target = "help" }
    end
    if info.expect_value then
      if #v == 0 then
        i = i + 1
        v = arg[i]
        if v == nil then
          error("Missing option value for ".. arg_i);
        end
      end
      info:load_value(result, k, v)
    elseif #v > 1 then
      error("Unexpected option value in ".. arg_i .."/".. v);
    else
      info:load_value(result, k, v)
    end
  end
  if i <= #arg then
   result.names = { table.unpack(arg, i) }
  end
  return result
end

---@alias l3b_options_parse_f fun(arg: string[]): table<string, any>

---@class l3b_options_t
---@field ut_flags_t        options_flags_t
---@field get_all_info      fun(hidden:  boolean): fun(): option_info_t|nil
---@field get_info_by_key   fun(key:  string): option_info_t
---@field get_info_by_name  fun(name: string): option_info_t
---@field register          fun(info: option_info_t, builtin: boolean)
---@field parse             l3b_options_parse_f

return {
  flags             = flags,
  get_all_info      = get_all_info,
  get_info_by_key   = get_info_by_key,
  get_info_by_name  = get_info_by_name,
  register          = register,
  parse             = parse,
}
