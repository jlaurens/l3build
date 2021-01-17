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

local Args = L3B.provide('Args')

-- deep copy of arg

Args.arg = {}

-- Definitions of command line options
-- This is `target` agnostic.
-- Some options provided may be useless at runtime.

Args.defs = {
  configs = {
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
  engines = {
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
    desc  = "Print this help message or a topic message and exit",
    short = "h",
    type  = "string",
    optional  = true
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
  },
  -- aliases plural forms are ok
  engine = {
    alias = "engines",
  }
}

---Recommanded usage `local target = Args:parse(arg, Opts)`
---Except for version query, the receiver will contain
---a deep copy of `arg`.
---Populate the `opts` table from `arg` contents.
---Does not remove previous `opt` contents. 
---@param self table For example `Args`
---@param arg table For example the `arg` global variable.
---@param opts table For example the `Opts` global variable.
---@return string the target, may be nil on bad command line input
Args.parse = function (self, arg, opts)
  -- arg[1] is a special case: either a command or "-v"|"--version"
  local target = arg[1]
  if target == "--version" or target == "-v" then
    return "version"
  elseif target then
    -- No other options are allowed in position 1, so filter those out
    if target:match("^%-") then
      return
    end
  else
    return
  end
  -- normalize short option to long: `f` or `foo` -> `foo`
  local opt_by_key = {}
  local alias = {}
  do
    local unik = {}
    for k, v in pairs(self.defs) do
      local a = v.alias
      if a then
        assert(self.defs[a])
        alias[v] = a
      else
        alias[v] = v
        local s = v.short
        if s then
          assert(not unik[s])
          unik[s] = true
          opt_by_key[s] = k
        end
        assert(not unik[k])
        unik[k] = true
        opt_by_key[k] = k
      end
    end
  end
  -- Examine all other arguments
  -- Use a while loop rather than for as this makes it easier
  -- to grab arg for optionals where appropriate
  local i = 1
  local l_opts
  ---next arguments are collected in a table named `names`.
  local function collect_remainder()
    local t  = {}
    while i < #arg do
      i = i + 1
      t[#t + 1] = arg[i]
    end
    if t[1] then
      l_opts.names = t
    end
  end
  -- start
  while i < #arg do
    i = i + 1
    local arg_i = arg[i]
    ::will_arg_i_match:: -- sometimes arg_i is already available
    local one, two = arg_i:match("^(%-)(%-?)")
    if one then -- this is an option
      ::did_if_one::
      local key, value -- `--key=value` or `-kvalue`
      if #two then
        if #arg_i > 2 then
          local n = arg_i:find("=", 4, true)
          if n then
            key   = arg_i:sub(3, n - 1)
            value = arg_i:sub(n + 1)
          else
            key   = arg_i:sub(3)
          end
        else -- arg_i is `--`
          collect_remainder()
          break
        end
      else
        key   = arg_i:sub(2, 2)
        value = arg_i:sub(3)
      end
      -- Now check that the option is valid and sort out the argument
      -- if required
      key = alias[key] or key
      local opt = opt_by_key[key]
      if opt then -- normalized known option
        local def = self.defs[opt] -- option definition
        local type = def.type
        if type == "boolean" then -- lookup special values
          local b = true -- default
          if value == "true" or value == "on" then
            ;
          elseif value == "false" or value == "off" then
            b = false
          elseif value then
            L3B:error("Unsupported value %s for option -%s%s",
                      value, two, key)
            return
          else -- next argument may be sepcail
            i = i + 1
            arg_i = arg[i]
            if arg_i == "true" or arg_i == "on" then
              ;
            elseif arg_i == "false" or arg_i == "off" then
              b = false
            else -- nothing special
              l_opts[opt] = b
              if arg_i then -- nothing special
                goto will_arg_i_match
              else
                break
              end
            end
          end
          l_opts[opt] = b
        elseif def.optional then -- optional string
          if not value then
            i = i + 1
            arg_i = arg[i]
            if arg_i then
              one, two = arg_i:match("^(%-)(%-?)")
              if one then
                l_opts[opt] = true -- "boolean"
                goto did_if_one
              end
              l_opts[opt] = arg_i
            else
              l_opts[opt] = true -- "boolean"
            end
          end
          l_opts[opt] = value
        else -- not a "boolean", require a value
          if not value then
            i = i + 1
            value = arg[i]
            if not value then
              L3B:error("Missing value for option -%s%s", two, key)
              return
            end
          end
          if type == "string" then
            l_opts[opt] = value
          else -- type == "table"
            local t = l_opts[opt] or {}
            for hit in value:gmatch("([^,%s]+)") do
              t[#t + 1] = hit
            end
            l_opts[opt] = t
          end
        end
      elseif #two then -- custom long option (new in 2021)
        if key:find("s$") then -- ending 's' for a "table"
          if not value then
            i = i + 1
            value = arg[i]
            if not value then
              L3B:error("Missing value for option --" .. key)
              return
            end
          end
          local t = l_opts[opt] or {}
          for hit in value:gmatch("([^,%s]+)") do
            t[#t + 1] = hit
          end
          l_opts[opt] = t
        else -- "string" or "boolean"
          if not value then
            i = i + 1
            arg_i = arg[i]
            if arg_i then
              one, two = arg_i:match("^(%-)(%-?)")
              if one then
                l_opts[opt] = true -- "boolean"
                goto did_if_one
              end
              value = arg_i
            else
              l_opts[opt] = true -- "boolean"
              break
            end
          end
          l_opts[opt] = value or true
        end
        L3B:info("Custom option --" .. key)
      else -- custom short options are not supported
        L3B:error("Unsupported option -", key)
        return
      end
    else -- Not an option
      collect_remainder()
      break
    end
  end
  -- Success: make a deep copy first
  self.arg = {}
  for j = 1, #arg do
    self.arg[j] = arg[j]
  end
  -- finally copy the local options to the `opts` argument
  for k, v in pairs(l_opts) do
    opts[k] = v
  end
  return target
end

return Args
