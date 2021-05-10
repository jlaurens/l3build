#!/usr/bin/env texlua
--[[
  This is a test file for l3build package.
  It is only intending for development and should appear in any distribution of the l3build package.
  For help, run `texlua ../l3build.lua test -h`
--]]

local expect  = _ENV.expect

---@type oslib_t
local oslib = require("l3b-oslib")
local OS    = oslib.OS

---@type utlib_t
local utlib = require("l3b-utillib")

local function test_base()
  expect(oslib).NOT(nil)
end


local function test_OS()
  expect(OS).NOT(nil)
end

local function test_cmd_concat()
  local cmd_concat = oslib.cmd_concat
  expect(cmd_concat()).is("")
  expect(cmd_concat("")).is("")
  expect(cmd_concat("a")).is("a")
  expect(cmd_concat("a", "")).is("a")
  expect(cmd_concat("a", nil)).is("a")
  expect(cmd_concat(nil, "a", nil)).is("")
  local old = OS.concat
  OS.concat = "<concat>"
  local cc = cmd_concat("a", "b")
  expect(cc).equals("a<concat>b")
  cc = cmd_concat("a", 1)
  expect(cc).equals("a<concat>1")
  OS.concat = old
  expect(function () cmd_concat({}, "b") end).error()
end

local function test_run()
  -- create a temporary file
  -- retrive the base and directory names
  -- remove it with a command from the terminal
  local name = os.tmpname()
  local base_name = name:match("[^/]+$")
  local dir_name = name:sub(1, #name - #base_name - 1)
  expect(dir_name .."/".. base_name).is(name)
  local lfs = require("lfs")
  local before = false
  for file_name in lfs.dir(dir_name) do
    if file_name == base_name then
      before = true
    end
  end
  expect(before).is(true)
  local cmd
  if os["type"] == "windows" then
    cmd = "del"
  else
    cmd = "rm"
  end
  oslib.run(dir_name, cmd .." ".. name)
  before = false
  for file_name in lfs.dir(dir_name) do
    if file_name == base_name then
      before = true
    end
  end
  -- THIS DOES NOT WORK ON WINDOWS 
  expect(before).is(false)
end

local function test_content()
  -- write some textual content to a temporary file
  -- read it back and compare to the original
  local name = os.tmpname()
  local t = {}
  for i = 1, 10 do
    table.insert(t, math.random(1000))
  end
  local s = table.concat(t, "\n")
  oslib.write_content(name, s)
  local ss = oslib.read_content(name)
  expect(ss).is(s)
  -- remove this temporary file
  -- its content is nil
  os.remove(name)
  ss = oslib.read_content(name)
  expect(ss).is(nil)
end

local function test_read_command()
  local name = os.tmpname()
  local base_name = name:match("[^/]+$")
  local dir_name = name:sub(1, #name - #base_name - 1)
  local special_name = "TEST".. tostring(math.random(100000000))
  local special_path = dir_name .."/".. special_name
  require("lfs").mkdir(special_path)
  local ans = oslib.read_command("ls ".. utlib.to_quoted_string(dir_name))
  expect(ans:match(special_name)).NOT(nil)
  os.remove(name)
end

return {
  test_base         = test_base,
  test_OS           = test_OS,
  test_cmd_concat   = test_cmd_concat,
  test_run          = test_run,
  test_content      = test_content,
  test_read_command = test_read_command,
}