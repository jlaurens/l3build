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

local MODE = "unit"
local KEY  = "--" .. MODE

local lfs   = require("lfs")
local kpse  = require("kpse")

local insert = table.insert
local append = table.insert
local remove = table.remove
local concat = table.concat

-- load the booter:
kpse.set_program_name("kpsewhich")
local kpse_dir = kpse.lookup("l3build.lua"):match("^.*/")
local launch_dir = arg[0]:match("^(.*/).*%.lua$") or "./"
local path = package.searchpath(
  "?", launch_dir .. "l3build-boot.lua"
)   or kpse_dir   .. "l3build-boot.lua"

local boot = dofile(path)

-- Dealing with the CLI
local short_defs = { -- short options
  d = { -- specify the unit test directory
    on_parsed = function (opts, value)
      opts.test_dir = value
    end
  },
  r = { -- the full path of a single test to run
    on_parsed = function (opts, value)
      opts.run_test = value
    end
  },
  t = { -- cumulative names of test files to run
    on_parsed = function (opts, value)
      for v in value:gmatch("[^,]+") do
        append(opts.tests, v)
      end
    end
  },
  p = { -- pattern to select only some tests.
    on_parsed = function (opts, value)
      append(opts.patterns, value)
    end
  },
}
local long_defs = { -- long options
  run = short_defs.r,
  test = short_defs.t,
  dir = short_defs.d,
  pattern = short_defs.p,
}

local unit = {}

---Parse the command line arguments.
---@param arg table, the list of command line arguments
function unit:parse(arg)
  -- turn `arg` into a stack in revert order
  local args = {}
  local min = arg[1] == KEY and 2 or 1
  for i = #arg, min, -1 do
    append(args, arg[i])
  end
  -- consume each argument
  while #args > 0 do
    local r = remove(args)
    -- print("arg[1]", arg[1])
    local key, value = r:match("^%-%-([^=]*)=(.*)$")
    if key then
      local def = long_defs[key]
      if def then
        -- print(key, value)
        def.on_parsed(self, value)
        goto continue
      end
      error("Unsupported option " .. key, 0)
    end
    key = r:match("^%-%-(.*)$")
    if key then
      local def = long_defs[key]
      if def then
        if #args > 0 then
          r = remove(args)
          def.on_parsed(self, r)
          goto continue
        end
        error('Missing value for ' .. key)
      end
      error('Unsupported option ' .. key)
    end
    key, value = r:match("^%-(.)(.+)$")
    if key then
      local def = short_defs[key]
      if def then
        def.on_parsed(self, value)
        goto continue
      end
      error("Unsupported option " .. key, 0)
    end
    key = r:match("^%-(.)$")
    if key then
      local def = short_defs[key]
      if def then
        if #args > 0 then
          r = remove(args)
          def.on_parsed(self, r)
          goto continue
        end
        error('Missing value for ' .. key, 0)
      end
      error("Unsupported option " .. key, 0)
    end
    break
    ::continue::
  end
end

---Run one test.
---@return boolean whether a test has been performed
function unit:run_one_test()
  if self.run_test then
    -- allow to look for modules in the parent directory
    -- and the test directory
    -- before the TDS
    boot.more_search_path = function (name)
      -- print("more_search_path", name, self.test_dir)
      local ans = boot.parent_search_path(name, lfs.currentdir())
      if ans then
        return ans
      end
      name = name:match("^.*%.lua$") or name .. ".lua"
      return package.searchpath("", self.test_dir .. name)
    end
    assert(
      package.searchpath("", self.run_test),
      "Unreachable path " .. self.run_test
    )
    -- load the library
    af = require("l3build-assert")
    -- install the patterns
    local match = ""
    for _,p in ipairs(self.patterns) do
      insert(arg, 1, p)
      insert(arg, 1, "-p")
      match = match .. p .. ", "
    end
    if #match > 0 then
      print("Testing " .. self.run_test .. " (match: " .. match .. "\8\8)")
    else
      print("Testing " .. self.run_test)
    end
    -- load the file
    dofile(self.run_test)
    -- terminate
    return true, af.run()
  end
end

---Main function.
---@param arg any, the list of command line arguments
---@return integer
function unit:run(arg)
  -- print("l3build in unit mode")
  -- prepare the tests
  self.tests = {}
  self.patterns = {}
  self:parse(arg)

  local ok, exit = self:run_one_test()
  if ok then
    return exit
  end

  if not next(self.tests) then
    error("Missing test name", 0)
  end
  -- Set up the test directory name
  self.test_dir = self.tesdir and self.test_dir:match("^.*/$") -- given on the command line
    or self.tesdir and self.tesdir .. "/"
    or boot.launch_dir and boot.launch_dir .. "unit_tests/" -- default location relative to the launch directory if any 
    or "unit_tests/" -- default location relative to the current path

  ---Return the path of the test with the given name in the given directory
  ---@param name string
  ---@param dir string, path of a directory, must end with "/" when not empty
  ---@return string? the path when found, nil otherwise
  local test_search_path = function (name, dir)
    return dir and package.searchpath("?" , dir .. name .. ".test.lua")
  end
  -- Check if all the given tests exist
  -- associate a test path to a test name
  local test_names = {} -- ordered test names
  local test_paths = {} -- name -> path
  -- search in the current directory then in the test directory
  local function search_path(name)
    return test_search_path(name, "")
        or test_search_path(name, self.test_dir)
  end
  for _, name in ipairs(self.tests) do
    local p = search_path(name)
           or search_path("l3build-" .. name)
    if p then
      append(test_names, name)
      test_paths[name] = p
    end
  end
  if #test_names == 0 then
    error("Unreachable tests, nothing to do.", 0)
  end
  -- Do the tests one after the other
  for _, name in ipairs(test_names) do
    local p = test_paths[name]
    local cmd = {}
    if arg[0]:match("%.lua$") then
      append(cmd, "texlua")
    end
    append(cmd, arg[0])
    append(cmd, "--unit")
    append(cmd, "--run=\"" .. p .. "\"")
    append(cmd, "--dir=\"" .. self.test_dir .. "\"")
    for _,p in ipairs(self.patterns) do
      append(cmd, "--pattern=\"" .. p .. "\"")
    end
    local ok, msg, code = os.execute(concat(cmd, " "))
    if not ok then
      print("Error while testing " .. name, msg, code)
    end
  end
  return 0
end

os.exit(unit:run(arg))
