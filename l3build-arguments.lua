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
local append           = table.insert

-- Parse command line options

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
        desc  = "Print version information and exit",
        type  = "boolean",
        short = "v" -- why no short before
      }
  }

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


---Option definition table
---@key desc string description, optional when reserved
---@key type string one of "string", "boolean" or "table"
---@key short[opt] string the short option name, length must be 1
---@key reserved[opt] boolean


local defs = {} -- long string -> option definition

-- the same cli option may be given either by its long or short name.
local map  = {}  -- long or short -> long

---Declare the given cli options.
---@param key_1 string long option name: `foo` in `--foo`
---@param def_1 table an option definition
---@param key_2 string long option name: `bar` in `--bar`
---@param def_2 table an option definition
---@return number 0 on proper termination, positive otherwise.
---@export
local function declare_options(...)
  local function readonly_def(d) -- see https://www.lua.org/pil/13.4.5.html
    return setmetatable({}, {
      __index = {
        desc     = d.desc,
        type     = d.type,
        reserved = d.reserved,
      },
      __newindex = function (t,k,v)
        error("attempt to update an read-only table", 2)
      end
    })
  end
  local feed
  -- will be called recursively to consume 2 arguments at a time
  -- error level + error string or nil
  feed = function (key_i, def_i, ...)
    if not key_i  then
      return 0, nil -- the list is exhausted
    elseif #key_i < 2  then
      return 1, "Name too short " .. key_i
    elseif map[key_i] then
      return 1, key_i .. " is already an option"
    elseif not def_i  then
      return 1, "Missing option definition for " .. key_i
    end
    defs[key_i] = readonly_def(def_i)
    map [key_i] = key_i -- long -> long
    local short = def_i.short
    if short then
      if #short ~= 1 then
        return 1, short .. " must be 1 char long"
      elseif map[short] then
        return 1, short .. " is already a short option"
      end
      map[short] = key_i -- short -> long
    end
    return feed(...)
  end
  local error_level, msg = feed(...)
  if msg then error("!Error: " .. msg) end
  return error_level
end

declare_options( -- can be moved around and split
  "config", {
    desc  = "Sets the config(s) used for running tests",
    short = "c",
    type  = "table",
  },
  "date", {
    desc  = "Sets the date to insert into sources",
    type  = "string",
  },
  "debug", {
    desc = "Runs target in debug mode (not supported by all targets)",
    type = "boolean",
  },
  "dirty", {
    desc = "Skip cleaning up the test area",
    type = "boolean",
  },
  "dry-run", {
    desc = "Dry run for install",
    type = "boolean",
  },
  "email", {
    desc = "Email address of CTAN uploader",
    type = "string",
  },
  "engine", {
    desc  = "Sets the engine(s) to use for running test",
    short = "e",
    type  = "table",
  },
  "epoch", {
    desc  = "Sets the epoch for tests and typesetting",
    type  = "string",
  },
  "file", {
    desc  = "Take the upload announcement from the given file",
    short = "F",
    type  = "string",
  },
  "first", {
    desc  = "Name of first test to run",
    type  = "string",
  },
  "force", {
    desc  = "Force tests to run if engine is not set up",
    short = "f",
    type  = "boolean",
  },
  "full", {
    desc = "Install all files",
    type = "boolean",
  },
  "halt-on-error", {
    desc  = "Stops running tests after the first failure",
    short = "H",
    type  = "boolean",
  },
  "help", {
    desc  = "Print this message and exit",
    short = "h",
    type  = "boolean",
  },
  "last", {
    desc  = "Name of last test to run",
    type  = "string",
  },
  "message", {
    desc  = "Text for upload announcement message",
    short = "m",
    type  = "string",
  },
  "quiet", {
    desc  = "Suppresses TeX output when unpacking",
    short = "q",
    type  = "boolean",
  },
  "rerun", {
    desc  = "Skip setup: simply rerun tests",
    type  = "boolean",
  },
  "show-log-on-error", {
    desc  = "If 'halt-on-error' stops, show the full log of the failure",
    type  = "boolean",
  },
  "shuffle", {
    desc  = "Shuffle order of tests",
    type  = "boolean",
  },
  "texmfhome", {
    desc = "Location of user texmf tree",
    type = "string",
  },
  "version", {
    desc = "Print version information and exit",
    type = "boolean",
    short = "v", -- why no short before
  }
)

---Parse the cli call into a table
---@param arg table For example the `arg` global variable.
---@return table
---@usage local options = arguments.parse(arg)
local function parse(arg)
  local ans = {}
  -- arg[1] is a special case:
  -- *) a target
  -- *) "-v"|"--version"
  local i = 1 -- counter of the arg index
  local target = arg[i]
  if target == "--version" or target == "-v" then
    return { target = "version" }
  elseif target then
    -- No other options are allowed in position 1, so filter those out
    if target:match("^%-") then
      return ans
    end
  else
    return ans
  end
  -- Examine all other arguments
  -- Use a while loop rather than for as this makes it easier
  -- to grab arg for optionals where appropriate
  local names  = {} -- to collect trailing non option arguments
  local function terminate(str, ...)
    error('!Error: ' .. str:format(...), 2)
  end
  -- start
  while i < #arg do
    i = i + 1
    local arg_i = arg[i]    -- consumed at the end of the loop
    ::consume_arg_i::
    local one, two = arg_i:match("^(%-)(%-?)")
    if one then             -- one dash: an option
      local key, value      -- `--key=value` or `-kvalue`
      if #two then          -- two dashes: long option
        if #arg_i > 2 then  -- more than `--`
          local n = arg_i:find("=", 4, true)
          if n then         -- `--key=value`
            key   = arg_i:sub(3, n - 1)
            value = arg_i:sub(n + 1)
          else              -- `--key`
            key   = arg_i:sub(3)
          end
        else                -- arg_i is `--`
          break             -- remaining arguments are trailing names
        end
      else                  -- short option
        key = arg_i:sub(2, 2)
        if #arg_i > 2 then
          value = arg_i:sub(3)
        end
      end
      -- Now check that the option is valid and sort out the argument
      -- if required
      local long = map[key]
      if not long then
        terminate("Unsupported option -%s%s", two, key)
      end
      local def = defs[long]    -- logically ~= nil
      local type = def.type
      if type == "boolean" then -- lookup special values, sugar
        local b = true          -- default
        if value == "true" or value == "on" or value == "yes" then
          ;
        elseif value == "false" or value == "off" or value == "no" then
          b = false
        elseif value then
          terminate("Unsupported value %s for option -%s%s",
                    value, two, key)
        else -- next argument may be special
          i = i + 1
          arg_i = arg[i]
          if arg_i == "true" or arg_i == "on" or arg_i == "yes" then
            ;
          elseif arg_i == "false" or arg_i == "off" or arg_i == "no" then
            b = false
          else -- nothing special
            ans[long] = b
            if arg_i then -- nothing special, loop to consume
              goto consume_arg_i
            else
              break
            end
          end
        end
        ans[long] = b
      else -- not a "boolean", require a value
        if not value then
          i = i + 1
          value = arg[i]
          if not value then
            terminate("Missing value for option -%s%s", two, key)
          end
        end
        if type == "string" then
          ans[long] = value
        else -- type == "table"
          local t = ans[long] or {}
          for hit in value:gmatch("([^,%s]+)") do
            append(t, hit)
          end
          ans[long] = t
        end
        -- arg[i] is consumed
      end
    else  -- Not an option
      append(names, arg_i) -- consumed
      break
    end
  end
  -- Success: collect the remaining arguments
  while i < #arg do
    i = i + 1
    append(names, arg[i])
  end
  if names[1] then
    ans.names = names -- may conflict with `--names`
  end
  ans.target = target -- may conflict with `--target`
  return ans
end

---@export
return {
  _TYPE     = "module",
  _NAME     = "arguments",
  _VERSION  = "2021/01/28",
  argparse        = argparse,
  old_option_list = option_list,
  option_list     = defs,
  parse           = parse,
  declare_options = declare_options,
}
