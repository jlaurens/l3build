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

local append           = table.insert
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

local option_list =
  {
    config =
      {
        desc  = "Sets the config(s) used for running tests",
        short = "c",
        type  = "table"
      },
    date =
      {
        desc  = "Sets the date to insert into sources",
        type  = "string"
      },
    debug =
      {
        desc = "Runs target in debug mode (not supported by all targets)",
        type = "boolean"
      },
    dirty =
      {
        desc = "Skip cleaning up the test area",
        type = "boolean"
      },
    ["dry-run"] =
      {
        desc = "Dry run for install",
        type = "boolean"
      },
    email =
      {
        desc = "Email address of CTAN uploader",
        type = "string"
      },
    engine =
      {
        desc  = "Sets the engine(s) to use for running test",
        short = "e",
        type  = "table"
      },
    epoch =
      {
        desc  = "Sets the epoch for tests and typesetting",
        type  = "string"
      },
    file =
      {
        desc  = "Take the upload announcement from the given file",
        short = "F",
        type  = "string"
      },
    first =
      {
        desc  = "Name of first test to run",
        type  = "string"
      },
    force =
      {
        desc  = "Force tests to run if engine is not set up",
        short = "f",
        type  = "boolean"
      },
    full =
      {
        desc = "Install all files",
        type = "boolean"
      },
    ["halt-on-error"] =
      {
        desc  = "Stops running tests after the first failure",
        short = "H",
        type  = "boolean"
      },
    help =
      {
        desc  = "Print this message and exit",
        short = "h",
        type  = "boolean"
      },
    last =
      {
        desc  = "Name of last test to run",
        type  = "string"
      },
    message =
      {
        desc  = "Text for upload announcement message",
        short = "m",
        type  = "string"
      },
    quiet =
      {
        desc  = "Suppresses TeX output when unpacking",
        short = "q",
        type  = "boolean"
      },
    rerun =
      {
        desc  = "Skip setup: simply rerun tests",
        type  = "boolean"
      },
    ["show-log-on-error"] =
      {
        desc  = "If 'halt-on-error' stops, show the full log of the failure",
        type  = "boolean"
      },
    shuffle =
      {
        desc  = "Shuffle order of tests",
        type  = "boolean"
      },
    texmfhome =
      {
        desc = "Location of user texmf tree",
        type = "string"
      },
    version =
      {
        desc = "Print version information and exit",
        type = "boolean"
      }
  }

---@alias option_type_f fun(options: table, key: string, value: string): error_level_t

---@class option_info_t
---@field desc  string  short description
---@field type  "boolean"|"string"|"number"|option_type_f|nil How to manage values.
---@field short string|nil  short CLI key
---@field long  string  long CLI key
---@field name  string  name in the options table
---@field expect_value  boolean False for boolean type, true for the others.
---@field load_value    fun(options: table, key: string, value?: string): error_level_t load the given value

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
  if k == "require_value" then
    return self.type ~= "boolean"
  end
  error("")
end
---@type table<string, option_info_t>
local by_key = {}
---@type table<string, option_info_t>
local by_name = {}

---Return the option info for the given key.
---An option info is read only.
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

---Register the given option.
---If there is a conflict, an error is raised.
---@param info option_info_t
local function register(info)
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
  info = setmetatable({
    short = short,
    long = long,
    name = name,
    desc = info.desc,
    type = info.type,
  }, MT)
  info = setmetatable({}, {
    __index = info,
    __newindex = function (t, k, v)
      error("Readonly object")
    end,
  })
  by_name[name] = true
  by_key[long] = info
  if short then
    by_key[short] = info
  end
end

for k, v in pairs(option_list) do
  v.long = k
  register(v)
end

---@class l3b_options_t
---@field get_info_by_key   fun(key:  string): option_info_t
---@field get_info_by_name  fun(name: string): option_info_t
---@field register          fun(info: option_info_t)

return {
  get_info_by_key   = get_info_by_key,
  get_info_by_name  = get_info_by_name,
  register          = register,
}
