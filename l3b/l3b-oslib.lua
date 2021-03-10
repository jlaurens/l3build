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

local match           = string.match
local gsub            = string.gsub

local append          = table.insert
local concat          = table.concat

---@type utlib_t
local utlib       = require("l3b-utillib")
local items       = utlib.items
local first_of    = utlib.first_of

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
if os_type == "windows" then
  if tonumber(luatex_version) < 100
  or (tonumber(luatex_version) == 100 and tonumber(luatex_revision) < 4)
  then
    _G.os_newline = "\r\n"
  else
    _G.os_newline = "\n"
  end
  _G.os_pathsep = ";"
  _G.os_concat  = "&"
  _G.os_null    = "nul"
  _G.os_ascii   = "@echo."
  _G.os_cmpexe  = getenv("cmpexe") or "fc /b"
  _G.os_cmpext  = getenv("cmpext") or ".cmp"
  _G.os_diffexe = getenv("diffexe") or "fc /n"
  _G.os_diffext = getenv("diffext") or ".fc"
  _G.os_grepexe = "findstr /r"
  _G.os_setenv  = "set"
  _G.os_yes     = "for /l %I in (1,1,300) do @echo y"
else
  _G.os_pathsep = ":"
  _G.os_newline = "\n"
  _G.os_concat  = ";"
  _G.os_null    = "/dev/null"
  _G.os_ascii   = "echo \"\""
  _G.os_cmpexe  = getenv("cmpexe") or "cmp"
  _G.os_cmpext  = getenv("cmpext") or ".cmp"
  _G.os_diffexe = getenv("diffexe") or "diff -c --strip-trailing-cr"
  _G.os_diffext = getenv("diffext") or ".diff"
  _G.os_grepexe = "grep"
  _G.os_setenv  = "export"
  _G.os_yes     = "printf 'y\\n%.0s' {1..300}"
end

---Concat the given string with `_G.os_concat`
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
    result = concat(t, _G.os_concat)
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
  return execute(cmd)
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
    path = gsub(path, "\\ ", "\0")
    path = gsub(path, " ", "\\ ")
    return first_of(gsub(path, "\0", "\\ "))
  end
end

---@class oslib_t
---@field Vars        oslib_vars_t
---@field cmd_concat  fun(...): string
---@field run         fun(dir: string, cmd: string): boolean|nil, nil|string, nil|integer
---@field quoted_path fun(path: string): string

return {
  Vars        = Vars,
  cmd_concat  = cmd_concat,
  run         = run,
  quoted_path = quoted_path,
}
