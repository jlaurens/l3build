--[[

File l3build-oslib.lua Copyright (C) 2018-2020 The LaTeX Project

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

local execute          = os.execute
local getenv           = os.getenv
local os_type          = os["type"]

local status          = require("status")
local luatex_revision = status.luatex_revision
local luatex_version  = status.luatex_version

local append      = table.insert
local concat      = table.concat

local time        = os.time
local difftime    = os.difftime

---@type utlib_t
local utlib       = require("l3b-utillib")
local items       = utlib.items
local first_of    = utlib.first_of
local print_diff_time = utlib.print_diff_time

---@class oslib_vars_t
---@field debug flag_table_t

local Vars = setmetatable({
  debug = {}
}, {
  __newindex = function (t, k, v) -- only for new keys
    error("`Vars` are readonly")
  end
})

-- Detect the operating system in use
-- Support items are defined here for cases where a single string can cover
-- both Windows and Unix cases: more complex situations are handled inside
-- the support functions

---@class OS_t
---@field pathsep string
---@field concat  string
---@field null    string
---@field ascii   string
---@field cmpexe  string
---@field cmpext  string
---@field diffexe string
---@field diffext string
---@field grepexe string
---@field setenv  string
---@field yes     string

---@type OS_t
local OS
if os_type == "windows" then
  OS = {
    pathsep = ";",
    concat  = "&",
    null    = "nul",
    ascii   = "@echo.",
    cmpexe  = getenv("cmpexe") or "fc /b",
    cmpext  = getenv("cmpext") or ".cmp",
    diffexe = getenv("diffexe") or "fc /n",
    diffext = getenv("diffext") or ".fc",
    grepexe = "findstr /r",
    setenv  = "set",
    yes     = "for /l %I in (1,1,300) do @echo y",
  }
  if tonumber(luatex_version) < 100
  or (tonumber(luatex_version) == 100 and tonumber(luatex_revision) < 4)
  then
    OS.newline = "\r\n"
  else
    OS.newline = "\n"
  end
else
  OS = {
    pathsep = ":",
    newline = "\n",
    concat  = ";",
    null    = "/dev/null",
    ascii   = "echo \"\"",
    cmpexe  = getenv("cmpexe") or "cmp",
    cmpext  = getenv("cmpext") or ".cmp",
    diffexe = getenv("diffexe") or "diff -c --strip-trailing-cr",
    diffext = getenv("diffext") or ".diff",
    grepexe = "grep",
    setenv  = "export",
    yes     = "printf 'y\\n%.0s' {1..300}",
  }
end

---Concat the given string with `OS.concat`
---@vararg string ...
local function cmd_concat(...)
  local t = {}
  for item in items( ... ) do
    if #item > 0 then
      append(t, item)
    end
  end
  local result
  local success = pcall (function()
    result = concat(t, OS.concat)
  end)
  if success then
    return result
  end
  for i, v in ipairs({ ... }) do
    print("i, ...", i, v)
  end
  for i, v in ipairs(t) do
    print("i, v  ", i, v)
  end
  print(debug.traceback())
  error("Cannot build command from components")
end

---Run a command in a given directory
---@param dir string
---@param cmd string
---@return boolean?  suc
---@return exitcode? exitcode
---@return integer?  code
local function run(dir, cmd)
  cmd = cmd_concat("cd " .. dir, cmd)
  if Vars.debug.run then
    print("DEBUG run: ".. cmd)
  end
  local start_time = time()
  local succ, msg, code = execute(cmd)
  local diff = difftime(time(), start_time)
  print_diff_time("Done in: %s", diff)
  return succ, msg, code
end

---Return a quoted version or properly escaped
---@param path string
---@return string
local function quoted_path(path)
  if os_type == "windows" then
    if path:match(" ") then
      return '"' .. path .. '"'
    end
    return path
  else
    return first_of(path:gsub("\\ ", "\0")
                        :gsub(" ", "\\ ")
                        :gsub("\0", "\\ "))
  end
end

---@class oslib_t
---@field osdate      OS_t
---@field Vars        oslib_vars_t
---@field cmd_concat  fun(...): string
---@field run         fun(dir: string, cmd: string): boolean?, exitcode?, integer?
---@field quoted_path fun(path: string): string

return {
  Vars        = Vars,
  OS          = OS,
  cmd_concat  = cmd_concat,
  run         = run,
  quoted_path = quoted_path,
}
