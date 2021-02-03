--[[

File l3build-unit.lua Copyright (C) 2018-2020 The LaTeX3 Project

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

-- This is a main script file not to be required.

local lfs   = require("lfs")
local boot  = require("l3build-boot")

local append = table.insert

local short_defs = {
  d = {
    on_parsed = function (unit, value)
      unit.test_dir = value
    end
  },
  r = {
    on_parsed = function (unit, value)
      unit.run_test = value
    end
  },
  t = {
    on_parsed = function (unit, value)
      for v in value:gmatch("[^,]+") do
        append(unit.tests, v)
      end
    end
  },
}
local long_defs = {
  run = short_defs.r,
  test = short_defs.t,
  dir = short_defs.d,
}

---Parse the command line arguments.
---@param self table, mainly the unit
---@param arg table, the list of command line arguments
local function parse(self, arg)
  while arg[1] do
    -- print("arg[1]", arg[1])
    local key, value = arg[1]:match("^%-%-([^=]*)=(.*)$")
    if key then
      local def = long_defs[key]
      if def then
        -- print(key, value)
        def.on_parsed(self, value)
        boot.shift_left(arg, 1)
        goto continue
      end
      error("Unsupported option " .. key, 0)
    end
    key = arg[1]:match("^%-%-(.*)$")
    if key then
      local def = long_defs[key]
      if def then
        if arg[2] then
          -- print("arg[2]", arg[2])
          def.on_parsed(self, arg[2])
          boot.shift_left(arg, 2)
          goto continue
        end
        error('Missing value for ' .. key)
      end
      error('Unsupported option ' .. key)
    end
    key, value = arg[1]:match("^%-(.)(.+)$")
    if key then
      local def = short_defs[key]
      if def then
        def.on_parsed(self, value)
        boot.shift_left(arg, 1)
        goto continue
      end
      error("Unsupported option " .. key, 0)
    end
    key = arg[1]:match("^%-(.)$")
    if key then
      local def = short_defs[key]
      if def then
        if arg[2] then
          -- print("arg[2]", arg[2])
          def.on_parsed(self, arg[2])
          boot.shift_left(arg, 2)
          goto continue
        end
        error('Missing value for ' .. key, 0)
      end
      error("Unsupported option " .. key, 0)
    end
    ::continue::
  end
end

---Main function.
---@param self table, the unit module
---@param arg any, the list of command line arguments
---@return integer
local function run(self, arg)
  -- print("l3build in unit mode")
  -- prepare the tests
  self.tests = {}
  parse(self, arg)
  if self.run_test then
    -- allow to look for modules in the parent directory
    -- and the test directory
    -- before the TDS
    boot.more_search_path = function (name)
      print("more_search_path", name, self.test_dir)
      local ans = boot.parent_search_path(name)
      if ans then
        return ans
      end
      name = name:match("^.*%.lua$") or name .. ".lua"
      print(name)
      return package.searchpath("", self.test_dir .. name)
    end
    print("Testing " .. self.run_test)
    assert(
      package.searchpath("", self.run_test),
      "Unreachable path " .. self.run_test
    )
    -- load the library
    al = require("l3build-assert")
    -- load the file
    dofile(self.run_test)
    -- terminate
    os.exit(al.run())
    return 0
  end
  if not next(self.tests) then
    error("Missing test name", 0)
  end
  -- Set up the test directory name
  self.test_dir = self.tesdir and self.test_dir:match("^.*/$") -- given on the command line
    or self.tesdir and self.tesdir .. "/"
    or boot.launch_dir and boot.launch_dir .. "test_units/" -- default location relative to the launch directory if any 
    or "test_units/" -- default location relative to the current path

  ---Return the path of the test with the given name in the given directory
  ---@param name string
  ---@param dir string, path of a directory, must end with "/" when not empty
  ---@return string? the path when found, nil otherwise
  local test_search_path = function (name, dir)
    return dir and package.searchpath(name , dir .. "?.test.lua")
  end
  -- TODO: NEXT SHOULD BE REMOVED
  local pseudo_test_search_path = function (name, dir)
    return dir and package.searchpath(name , dir .. "?.pseudo-test.lua")
  end
  -- Check if all the given test exist
  -- associate a path to a test
  local test_names = {}
  local test_paths = {}
  for _, name in ipairs(self.tests) do
    local path = pseudo_test_search_path(name, "")
              or pseudo_test_search_path(name, self.test_dir)
              or test_search_path(name, "")
              or test_search_path(name, self.test_dir)
    if path then
      append(test_names, name)
      test_paths[name] = path
    end
  end

  if #test_names == 0 then
    error("Unreachable tests, nothing to do.", 0)
  else
    for _, name in ipairs(test_names) do
      local path = test_paths[name]
      local cmd = arg[0]:match("%.lua$") and "texlua " .. arg[0] or arg[0]
      cmd = cmd .. " --unit"
      cmd = cmd .. " --run=\"" .. path .. "\""
      cmd = cmd .. " --dir=\"" .. self.test_dir .. "\""
      local ok, msg, code = os.execute(cmd)
      if not ok then
        print("Error while testing " .. name, msg, code)
      end
    end
  end

  os.exit(0)

  boot.trace.require = true

  -- test of preload

  require("l3build-variables")

  -- test "./l3build-variables.lua"

  print("kspe_dir", boot.kpse_dir)

  --require('bar')

  print(lfs.currentdir())

  require('barx')

  print("DONE")
  return 0
end


return {
  _TYPE     = "module",
  _NAME     = "l3build-unit",
  _VERSION  = "dev", -- the dev must be replaced by a release date
  run = run,
  parse = parse,
}
