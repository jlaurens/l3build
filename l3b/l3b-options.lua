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

local select  = select
local next    = next
local append  = table.insert

local stderr  = io.stderr

---@type utlib_t
local utlib         = require("l3b-utillib")
local sorted_values = utlib.sorted_values

---@class l3build_options_t
---@field config    table
---@field date      string
---@field debug     boolean
---@field dirty     boolean
---@field dry_run   boolean
---@field email     string
---@field engine    table
---@field epoch     string
---@field file      string
---@field first     boolean
---@field force     boolean
---@field full      boolean
---@field halt_on_error boolean -- real name "halt-on-error"
---@field help      boolean
---@field message   string
---@field names     table
---@field quiet     boolean
---@field rerun     boolean
---@field shuffle   boolean
---@field texmfhome string

local option_list = {
    config = {
      description = "Sets the config(s) used for running tests",
      short = "c",
      type  = "table"
    },
    date = {
      description = "Sets the date to insert into sources",
      type  = "string"
    },
    debug = {
      description = "Runs target in debug mode (not supported by all targets)",
      type = "boolean"
    },
    dirty = {
      description = "Skip cleaning up the test area",
      type = "boolean"
    },
    ["dry-run"] = {
      description = "Dry run for install",
      type = "boolean"
    },
    email = {
      description = "Email address of CTAN uploader",
      type = "string"
    },
    engine = {
      description = "Sets the engine(s) to use for running test",
      short = "e",
      type  = "table"
    },
    epoch = {
      description = "Sets the epoch for tests and typesetting",
      type  = "string"
    },
    file = {
      description = "Take the upload announcement from the given file",
      short = "F",
      type  = "string"
    },
    first = {
      description = "Name of first test to run",
      type  = "string"
    },
    force = {
      description = "Force tests to run if engine is not set up",
      short = "f",
      type  = "boolean"
    },
    full = {
      description = "Install all files",
      type = "boolean"
    },
    ["halt-on-error"] = {
      description = "Stops running tests after the first failure",
      short = "H",
      type  = "boolean"
    },
    help = {
      description = "Print this message and exit",
      short = "h",
      type  = "boolean"
    },
    last = {
      description = "Name of last test to run",
      type  = "string"
    },
    message = {
      description = "Text for upload announcement message",
      short = "m",
      type  = "string"
    },
    quiet = {
      description = "Suppresses TeX output when unpacking",
      short = "q",
      type  = "boolean"
    },
    rerun = {
      description = "Skip setup: simply rerun tests",
      type  = "boolean"
    },
    ["show-log-on-error"] = {
      description = "If 'halt-on-error' stops, show the full log of the failure",
      type  = "boolean"
    },
    shuffle = {
      description = "Shuffle order of tests",
      type  = "boolean"
    },
    texmfhome = {
      description = "Location of user texmf tree",
      type = "string"
    },
    version = {
      description = "Print version information and exit",
      type = "boolean"
    }
  }

---@alias option_type_f fun(options: table, key: string, value: string): error_level_t

---@class option_info_t
---@field description  string  short description
---@field type  "boolean"|"string"|"number"|option_type_f|nil How to manage values.
---@field short string|nil  short CLI key
---@field long  string  long CLI key
---@field name  string  name in the options table
---@field expect_value  boolean False for boolean type, true for the others.
---@field load_value    fun(options: table, key: string, value?: string): error_level_t load the given value
---@field builtin       boolean whether the option is builtin

-- metatable for option_info_t
local MT = {}

---Load the given value in the given table
---Raise an error if no value is required
---@param options table
---@param key     string
---@param value?  string
---@return error_level_t
function MT:load_value (options, key, value)
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

function MT:__index(k)
  if k == "expect_value" then
    return self.type ~= "boolean"
  end
  if k == "short" then
    return nil
  end
  error("Unknown field name ".. k)
end
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
  return sorted_values(by_long, function (info)
    return not info.description
  end)
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
  info = setmetatable({
    short = short,
    long = long,
    name = name,
    description = info.description,
    type = info.type,
    builtin = builtin and true or false,
  }, MT)
  info = setmetatable({}, {
    __index = info,
    __newindex = function (t, k, v)
      error("Readonly object")
    end,
  })
  by_name[name] = true
  by_long[long] = info
  by_key[long]  = info
  if short then
    by_key[short] = info
  end
end

for k, v in pairs(option_list) do
  v.long = k
  register(v, true)
end

-- This is done as a function (rather than do ... end) as it allows early
-- termination (break)
---comment
---@param arg table
---@return table
local function parse(arg)
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
      result["target"] = "version"
    elseif not a:match("^%-") then
      result["target"] = a
    end
  end
  -- Stop here if help or version is required
  if result["target"] == "help" or result["target"] == "version" then
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
    -- Terminate search for options
    local long, k, v = arg_i:match("^(%-)%-([^=]*)=?(.*)")
    if not k then
      -- this is not a long argument
      k, v = arg_i:match("^%-(.)=?(.*)")
      if not k then
        -- this is not short argument either
        -- forthcoming arguments are names
        if arg_i == "-" then
          i = i + 1
        end
        break
      end
    elseif arg_i == "--" then
      -- forthcoming arguments are names too
      i = i + 1
      break
    end
    ---@type option_info_t
    local info = get_info_by_key(k)
    if not info then
      -- Private special debugging options "--debug-<key>"
      local key = arg_i:match("^%-%-debug%-(%w[%w%d_-]*)")
      if key then
        require("l3build").debug[key:gsub("-", "_")] = true
        goto top
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
      info.load_value(result, k, v)
    elseif #v > 1 then
      error("Unexpected option value in ".. arg_i .."/".. v);
    end
  end
  local names = { table.unpack(arg, i) }
  if next(names) then
   result["names"] = names
  end
  return result
end

---@class l3b_options_t
---@field get_all_info      fun(hidden:  boolean): fun(): option_info_t|nil
---@field get_info_by_key   fun(key:  string): option_info_t
---@field get_info_by_name  fun(name: string): option_info_t
---@field register          fun(info: option_info_t, builtin: boolean)
---@field parse fun(arg: table<integer, string>): table<string, boolean|string|number|string_list_t>

return {
  get_all_info      = get_all_info,
  get_info_by_key   = get_info_by_key,
  get_info_by_name  = get_info_by_name,
  register          = register,
  parse             = parse,
}
