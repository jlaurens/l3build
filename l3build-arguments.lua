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

-- local safe guards

local stderr = io.stderr

-- module

local Args = Provide(Args)

-- deep copy of arg

Args.arg = {}

-- Parse command line options

Args.option_list = {
  config = {
    desc  = "Sets the config(s) used for running tests",
    short = "c",
    type  = "table"
  },
  date = {
    desc  = "Sets the date to insert into sources",
    type  = "string"
  },
  debug = {
    desc = "Runs target in debug mode (not supported by all targets)",
    type = "boolean"
  },
  dirty = {
    desc = "Skip cleaning up the test area",
    type = "boolean"
  },
  ["dry-run"] = {
    desc = "Dry run for install",
    type = "boolean"
  },
  email = {
    desc = "Email address of CTAN uploader",
    type = "string"
  },
  engine = {
    desc  = "Sets the engine(s) to use for running test",
    short = "e",
    type  = "table"
  },
  epoch = {
    desc  = "Sets the epoch for tests and typesetting",
    type  = "string"
  },
  file = {
    desc  = "Take the upload announcement from the given file",
    short = "F",
    type  = "string"
  },
  first = {
    desc  = "Name of first test to run",
    type  = "string"
  },
  force = {
    desc  = "Force tests to run if engine is not set up",
    short = "f",
    type  = "boolean"
  },
  full = {
    desc = "Install all files",
    type = "boolean"
  },
  ["halt-on-error"] = {
    desc  = "Stops running tests after the first failure",
    short = "H",
    type  = "boolean"
  },
  help = {
    desc  = "Print this message and exit",
    short = "h",
    type  = "boolean"
  },
  last = {
    desc  = "Name of last test to run",
    type  = "string"
  },
  message = {
    desc  = "Text for upload announcement message",
    short = "m",
    type  = "string"
  },
  quiet = {
    desc  = "Suppresses TeX output when unpacking",
    short = "q",
    type  = "boolean"
  },
  rerun = {
    desc  = "Skip setup: simply rerun tests",
    type  = "boolean"
  },
  ["show-log-on-error"] = {
    desc  = "If 'halt-on-error' stops, show the full log of the failure",
    type  = "boolean"
  },
  shuffle = {
    desc  = "Shuffle order of tests",
    type  = "boolean"
  },
  texmfhome = {
    desc = "Location of user texmf tree",
    type = "string"
  },
  version = {
    desc = "Print version information and exit",
    short = "v",
    type = "boolean"
  }
}

-- This is done as a function (rather than do ... end) as it allows early
-- termination (break)
-- On success, `t` contains a deep copy of `arg`.
Args.argparse = function (t, arg)
  -- arg[1] is a special case: either a command or "-v"/"--version"
  local arg_1 = arg[1]
  if arg_1 == "--version" or arg_1 == "-v" then
    return { target = "version" }
  elseif arg_1 then
    -- No options are allowed in position 1, so filter those out
    if arg_1:match("^%-") then
      return { target = "help" }
    end
  else
    return { target = "help" }
  end
  -- make a deep copy first
  t.arg = {}
  for i = 1, #arg do
    t.arg[i] = arg[i]
  end
  local result = {
    target = arg_1
  }
  local opts =  {}
  local unik = {}
  -- Turn long/short options into two lookup tables
  for k, v in pairs(t.option_list) do
    if v.short then
      assert(not unik[v.short])
      unik[v.short] = true
      opts[v.short] = k
    end
    assert(not unik[k])
    unik[k] = true
    opts[k] = k
  end
  -- An auxiliary to grab all file names into a table
  local function remainder(num)
    local ans = {}
    for i = num, #arg do
      ans[#ans+1] = arg[i]
    end
    return ans
  end
  -- Examine all other arguments
  -- Use a while loop rather than for as this makes it easier
  -- to grab arg for optionals where appropriate
  local names  = {}
  local i = 2
  while i <= #arg do
    local arg_i = arg[i]
    -- Terminate search for options
    if arg_i == "--" then
      names = remainder(i + 1)
      break
    end
    -- Look for optionals
    local opt
    local opt_arg
    -- Look for and option and get it into a variable
    if arg_i:match("^%-") then
      local is_long = arg_i:match("^%-%-")
      if is_long then
        local n = arg_i:find("=", 1, true)
        if n then
          opt    = arg_i:sub(3, n - 1)
          opt_arg = arg_i:sub(n + 1)
        else
          opt = arg_i:sub(3)
        end
      else
        opt  = arg_i:sub(2, 2)
        -- Only set optarg if it is there
        if #arg_i > 2 then
          opt_arg = arg_i:sub(3)
        end
      end
      -- Now check that the option is valid and sort out the argument
      -- if required
      local opt_name = opts[opt]
      if not opt_name then
        stderr:write("Unknown option " .. arg_i .."\n")
        return { target = "help" }
      end
      -- Tidy up arguments
      if t.option_list[opt_name].type == "boolean" then
        if opt_arg then
          opt = (is_long and "--" or "-") .. opt
          stderr:write("Value not allowed for option " .. opt .."\n")
          return { target = "help" }
        end
      elseif not opt_arg then
        i = i + 1
        opt_arg = arg[i]
        if not opt_arg then
          stderr:write("Missing value for option " .. arg_i .."\n")
          return { target = "help" }
        end
      end
      -- Store the result
      if opt_arg then
        if t.option_list[opt_name].type == "string" then
          result[opt_name] = opt_arg
        else
          local opt_args = result[opt_name] or {}
          for hit in opt_arg:gmatch("([^,%s]+)") do
            opt_args[#opt_args+1] = hit
          end
          result[opt_name] = opt_args
        end
      else
        result[opt_name] = true
      end
      i = i + 1
    else
      names = remainder(i)
      break
    end
  end
  if names[1] then
   result.names = names
  end
  return result
end

return Args
