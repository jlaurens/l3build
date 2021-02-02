--[[

File l3build-arguments.lua Copyright (C) 2018-2020 The LaTeX3 Project

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

local exit             = os.exit
local stderr           = io.stderr

local find             = string.find
local gmatch           = string.gmatch
local match            = string.match
local sub              = string.sub

local insert           = table.insert

-- Parse command line options

---Option definition
---@key type string one of "boolean", "table", "string"
---@key desc string the description as displayed in help
---@key short string one character length option
---@key builtin boolean for internal use, must not be documented
---@table option_def

-- option_list = {} defined in the client

local defs = {} -- long name -> option def
local map  = {} -- long name -> long name and short name -> long name

---Declare option
---@param builtin? boolean optional, true for builtin options. Do not document in the dtx.
---@param key_1 string option name, some format restrictions
---@param def_1 table option definition
---@usage declare_option(builtin, key_1, def_1, ..., key_n, def_n) -- private
---@usage declare_option(key_1, def_1, ..., key_n, def_n) -- public
local function declare_option(builtin, key_1, def_1, ...)
  local declare
  declare = function (key_i, def_i, ...)
    if boot.debug_level > 0 then -- see advanced boot.trace
      print('Declaring option ' .. key_i)
    end
    local long_pattern  = "^[a-zA-Z0-9_][a-zA-Z0-9_%-]+$"
    local short_pattern = "^[a-zA-Z0-9_]$"
    if not key_i then
      return -- list exhausted, success
    elseif not type(key_i) == "string" then
      error("Option key must be a string")
    elseif map[key_i] then
      error("Option key is already used " .. key_i)
    elseif not key_i:match(long_pattern) then
      error("Option key is too short or contains an unsupported character")
    elseif not def_i then
      error("Missing definition for option " .. key_i)
    elseif  def_i.type ~= "boolean"
        and def_i.type ~= "string"
        and def_i.type ~= "table"
    then
      error("The type of " .. key_i .. ' is unsupported')
    elseif def_i.short then
      if not def_i.short:match(short_pattern) then
        error("Short option name must be one letter of [a-zA-Z0-9_]" .. tostring(def_i.short))
      end
      if map[def_i.short] then
        error("Short option already used " .. def_i.short)
      end
      map[def_i.short] = key_i
    end
    map[key_i] = key_i
    defs[key_i] = {
      type    = def_i.type,
      desc    = def_i.desc,
      short   = def_i.short,
      builtin = builtin,
    }
    return declare(...)
  end
  local success, msg
  if type(key_1) == "string" then -- first argument is meant boolean
    success, msg = pcall(declare, key_1, def_1, ...)
  else -- no optional first argument given
    local key_2
    key_1, def_1, key_2 = builtin, key_1, def_1
    builtin = false
    success, msg = pcall(declare, key_1, def_1, key_2, ...)
  end
  if not success then
    error("!Error: " .. msg)
  end
end

-- next will be reformatted, in the meanwhile it helps diff analyze
declare_option(true, -- these are builtin option
    -- Hidden options are possible (with no desc)?
    "config",
      {
        desc  = "Sets the config(s) used for running tests",
        short = "c",
        type  = "table"
      },
    "date",
      {
        desc  = "Sets the date to insert into sources",
        type  = "string"
      },
    "debug",
      {
        desc = "Runs target in debug mode (not supported by all targets)",
        type = "boolean"
      },
    "dirty",
      {
        desc = "Skip cleaning up the test area",
        type = "boolean"
      },
    "dry-run",
      {
        desc = "Dry run for install",
        type = "boolean"
      },
    "email",
      {
        desc = "Email address of CTAN uploader",
        type = "string"
      },
    "engine",
      {
        desc  = "Sets the engine(s) to use for running test",
        short = "e",
        type  = "table"
      },
    "epoch",
      {
        desc  = "Sets the epoch for tests and typesetting",
        type  = "string"
      },
    "file",
      {
        desc  = "Take the upload announcement from the given file",
        short = "F",
        type  = "string"
      },
    "first",
      {
        desc  = "Name of first test to run",
        type  = "string"
      },
    "force",
      {
        desc  = "Force tests to run if engine is not set up",
        short = "f",
        type  = "boolean"
      },
    "full",
      {
        desc = "Install all files",
        type = "boolean"
      },
    "halt-on-error",
      {
        desc  = "Stops running tests after the first failure",
        short = "H",
        type  = "boolean"
      },
    "help",
      {
        desc  = "Print this message and exit",
        short = "h",
        type  = "boolean"
      },
    "last",
      {
        desc  = "Name of last test to run",
        type  = "string"
      },
    "message",
      {
        desc  = "Text for upload announcement message",
        short = "m",
        type  = "string"
      },
    "quiet",
      {
        desc  = "Suppresses TeX output when unpacking",
        short = "q",
        type  = "boolean"
      },
    "rerun",
      {
        desc  = "Skip setup: simply rerun tests",
        type  = "boolean"
      },
    "show-log-on-error",
      {
        desc  = "If 'halt-on-error' stops, show the full log of the failure",
        type  = "boolean"
      },
    "shuffle",
      {
        desc  = "Shuffle order of tests",
        type  = "boolean"
      },
    "texmfhome",
      {
        desc = "Location of user texmf tree",
        type = "string"
      },
    "version",
      {
        desc = "Print version information and exit",
        type = "boolean"
      }
)

-- This is done as a function (rather than do ... end) as it allows early
-- termination (break)
local function argparse(arg)
  local result = { }
  local names  = { }
  local long_options =  { }
  local short_options = { }
  -- Turn long/short options into two lookup tables
  for k,v in pairs(option_list) do
    if v["short"] then
      short_options[v["short"]] = k
    end
    long_options[k] = k
  end
  local arg = arg
  -- arg[1] is a special case: must be a command or "-h"/"--help"
  -- Deal with this by assuming help and storing only apparently-valid
  -- input
  local a = arg[1]
  result["target"] = "help"
  if a then
    -- No options are allowed in position 1, so filter those out
    if a == "--version" then
      result["target"] = "version"
    elseif not match(a, "^%-") then
      result["target"] = a
    end
  end
  -- Stop here if help or version is required
  if result["target"] == "help" or result["target"] == "version" then
    return result
  end
  -- An auxiliary to grab all file names into a table
  local function remainder(num)
    local names = { }
    for i = num, #arg do
      insert(names, arg[i])
    end
    return names
  end
  -- Examine all other arguments
  -- Use a while loop rather than for as this makes it easier
  -- to grab arg for optionals where appropriate
  local i = 2
  while i <= #arg do
    local a = arg[i]
    -- Terminate search for options
    if a == "--" then
      names = remainder(i + 1)
      break
    end
    -- Look for optionals
    local opt
    local optarg
    local opts
    -- Look for and option and get it into a variable
    if match(a, "^%-") then
      if match(a, "^%-%-") then
        opts = long_options
        local pos = find(a, "=", 1, true)
        if pos then
          opt    = sub(a, 3, pos - 1)
          optarg = sub(a, pos + 1)
        else
          opt = sub(a, 3)
        end
      else
        opts = short_options
        opt  = sub(a, 2, 2)
        -- Only set optarg if it is there
        if #a > 2 then
          optarg = sub(a, 3)
        end
      end
      -- Now check that the option is valid and sort out the argument
      -- if required
      local optname = opts[opt]
      if optname then
        -- Tidy up arguments
        if option_list[optname]["type"] == "boolean" then
          if optarg then
            local opt = "-" .. (match(a, "^%-%-") and "-" or "") .. opt
            stderr:write("Value not allowed for option " .. opt .."\n")
            return {"help"}
          end
        else
         if not optarg then
          optarg = arg[i + 1]
          if not optarg then
            stderr:write("Missing value for option " .. a .."\n")
            return {"help"}
          end
          i = i + 1
         end
        end
      else
        stderr:write("Unknown option " .. a .."\n")
        return {"help"}
      end
      -- Store the result
      if optarg then
        if option_list[optname]["type"] == "string" then
          result[optname] = optarg
        else
          local opts = result[optname] or { }
          for hit in gmatch(optarg, "([^,%s]+)") do
            insert(opts, hit)
          end
          result[optname] = opts
        end
      else
        result[optname] = true
      end
      i = i + 1
    end
    if not opt then
      names = remainder(i)
      break
    end
  end
  if next(names) then
   result["names"] = names
  end
  return result
end

-- Sanity check
function check_engines()
  if options["engine"] and not options["force"] then
     -- Make a lookup table
     local t = { }
    for _, engine in pairs(checkengines) do
      t[engine] = true
    end
    for _, engine in pairs(options["engine"]) do
      if not t[engine] then
        print("\n! Error: Engine \"" .. engine .. "\" not set up for testing!")
        print("\n  Valid values are:")
        for _, engine in ipairs(checkengines) do
          print("  - " .. engine)
        end
        print("")
        exit(1)
      end
    end
  end
end

return {
  _TYPE     = "module",
  _NAME     = "arguments",
  _VERSION  = "2021/30/01(dev)",
  parse     = argparse,
  defs      = defs,
  declare_option = declare_option,
}
