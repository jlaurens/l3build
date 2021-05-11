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

---@module l3b-options

local push      = table.insert

local stderr  = io.stderr

local Object = require("l3b-object")

---@type utlib_t
local utlib             = require("l3b-utillib")
local readonly          = utlib.readonly
local values            = utlib.values
local compare_ascending = utlib.compare_ascending

--[=[ Package implementation ]=]

---@class options_flags_t
---@field public debug boolean

---@type options_flags_t
local flags = {}

---@class options_base_t

---@alias option_type_f fun(options: table, key: string, value: string): error_level_n

---@class option_info_t
---@field public description  string    @short description
---@field public type  string|option_type_f|nil @How to manage values.
---@field public short string|nil       @short CLI key
---@field public long  string           @long CLI key
---@field public name  string           @name in the options table

---@class OptionInfo: option_info_t
---@field public builtin       boolean  @whether the option is builtin
---@field public expect_value  boolean  @False for boolean type, true for the others.
---@field public load_value    fun(options: table, key: string, value?: string): error_level_n @ load the given value

local OptionInfo = Object:make_subclass("OptionInfo")

---Load the given value in the given table
---Raise an error if no value is required
---@param self    OptionInfo
---@param options table
---@param key     string
---@param value?  string
---@return error_level_n
function OptionInfo.load_value(self, options, key, value)
  if self.type == "boolean" then
    options[self.name] = not key:match("^no%-")
  elseif self.type == "string" then
    options[self.name] = value
  elseif self.type == "number" then
    options[self.name] = tonumber(value)
  elseif type(self.type) == "function" then
    return self.type(options, key, value)
  else
    local t = options[self.name] or {}
    options[self.name] = t
    if self.type == "number[]" then
      push(t, tonumber(value))
    else -- string sequence
      push(t, value)
    end
  end
  return 0
end

OptionInfo.__instance_table = {
  expect_value = function (self)
    if flags.debug then
      print("DEBUG options parse expect_value:", self.type)
    end
    return self.type ~= "boolean"
  end,
}

---@class OptionManager
---@field private __by_key  table<string, OptionInfo>
---@field private __by_name table<string, OptionInfo>
---@field private __by_long table<string, OptionInfo>

local OptionManager = Object:make_subclass("OptionManager")

---Return the option info for the given key.
---An option info is meant read only.
---`key` is "version", "v"...
function OptionManager:__initialize()
  self.__by_key = {}
  self.__by_long = {}
  self.__by_name = {}
end

---Return the option info for the given key.
---An option info is meant read only.
---`key` is "version", "v"...
---@param key string
---@return OptionInfo
function OptionManager:info_with_key(key)
  return  self.__by_key[key]
end

---Return the option info for the given key.
---An option info is read only.
---`key` is "version", "v"...
---@param name string
---@return OptionInfo
function OptionManager:info_with_name(name)
  return  self.__by_name[name]
end

---Enumerator of all the target infos.
---Sorted by name
---@param hidden boolean @true to list all hidden targets too.
---@return function
function OptionManager:get_all_infos(hidden)
  return values(self.__by_long, {
    compare = compare_ascending,
    exclude = function (info)
      return not hidden and not info.description
    end,
  })
end

---Register the given option.
---If there is a conflict, an error is raised.
---@param info    option_info_t
---@param builtin boolean|nil
---@return OptionInfo
function OptionManager:register(info, builtin)
  local long  = info.long
  if self.__by_key[long] then
    error("Option already registered for key ".. long)
  end
  local short = info.short
  if short then
    if #short > 1 then
      error("Short option is too long: ".. short)
    end
    if self.__by_key[short] then
      error("Option already registered for key ".. short)
    end
  end
  local name  = info.name or long
  if self.__by_name[name] then
    error("Option already registered for name".. name)
  end
  if name == "target" or name == "names" then
    error("Reserved option name ".. name)
  end
  assert(info.type)
  info = OptionInfo({
    short = short,
    long = long,
    name = name,
    description = info.description,
    type = info.type,
    builtin = builtin and true or false,
  })
  info = readonly(info)
  self.__by_name[name] = info
  self.__by_long[long] = info
  self.__by_key[long]  = info
  if short then
    self.__by_key[short] = info
  end
  return info
end

---Parse the command line arguments.
---When the key is not recognized by the system,
---`on_unknown` gets a chance to recognize it.
---When this function returns `nil` it means no recognition.
---When it returns 0, all is ok otherwise an error occurred.
---@param arg table
---@param on_unknown fun(key: string): boolean|fun(any: any, options: options_base_t) true when catched, false otherwise
---@return table
function OptionManager:parse(arg, on_unknown)
  local result = {
    target = "help",
  }
  -- arg[1] is a special case: must be a command or "-h"/"--help"
  -- arg[1] is a special case: must be a command or "/help"
  -- Deal with this by assuming help and storing only apparently-valid
  -- input
  local a = arg[1]
  if a then
    -- No options are allowed in position 1, so filter those out
    if a == "--version" then
      result.target = "version"
    elseif a:match("^%-") then
      result.target = "help"
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
    ---@type OptionInfo
    local info = self:info_with_key(k)
    if not info then
      local no_no = k:match("^no%-(.*)$")
      if no_no then
        info = self:info_with_key(no_no)
      end
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
            goto top
          elseif catched then
            if #v > 1 then
              error("Unexpected option value in ".. arg_i / v);
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
      error("Unexpected option value in ".. arg_i / v);
    else
      info:load_value(result, k, v)
    end
  end
  if i <= #arg then
   result.names = { table.unpack(arg, i) }
  end
  return result
end

---@class l3b_options_t
---@field public flags          options_flags_t
---@field public OptionManager  OptionManager

return {
  flags = flags,
  OptionManager = OptionManager,
},
---@class __l3b_options_t
---@field private OptionInfo OptionInfo
_ENV.during_unit_testing and
{
  OptionInfo  = OptionInfo,
}
