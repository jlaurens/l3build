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

--[=[ Usage:
---@type oslib_t
local oslib       = require("l3b.oslib")
local cmd_concat  = oslib.cmd_concat
local run         = oslib.run
local quoted_path = oslib.quoted_path
--]=]

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
local utlib       = require("l3b.utillib")
local extend_with = utlib.extend_with
local items       = utlib.items

-- Detect the operating system in use
-- Support items are defined here for cases where a single string can cover
-- both Windows and Unix cases: more complex situations are handled inside
-- the support functions
if os_type == "windows" then
  if tonumber(luatex_version) < 100
  or (tonumber(luatex_version) == 100 and tonumber(luatex_revision) < 4)
  then
    os_newline = "\r\n"
  else
    os_newline = "\n"
  end
  os_pathsep = ";"
  os_concat  = "&"
  os_null    = "nul"
  os_ascii   = "@echo."
  os_cmpexe  = getenv("cmpexe") or "fc /b"
  os_cmpext  = getenv("cmpext") or ".cmp"
  os_diffexe = getenv("diffexe") or "fc /n"
  os_diffext = getenv("diffext") or ".fc"
  os_grepexe = "findstr /r"
  os_setenv  = "set"
  os_yes     = "for /l %I in (1,1,300) do @echo y"
else
  os_pathsep = ":"
  os_newline = "\n"
  os_concat  = ";"
  os_null    = "/dev/null"
  os_ascii   = "echo \"\""
  os_cmpexe  = getenv("cmpexe") or "cmp"
  os_cmpext  = getenv("cmpext") or ".cmp"
  os_diffexe = getenv("diffexe") or "diff -c --strip-trailing-cr"
  os_diffext = getenv("diffext") or ".diff"
  os_grepexe = "grep"
  os_setenv  = "export"
  os_yes     = "printf 'y\\n%.0s' {1..300}"
end

---Concat the given string with `os_concat`
---@vararg string ...
local function cmd_concat(...)
  local t = {}
  for item in items({ ... }) do
    if #item > 0 then
      append(t, item)
    end
  end
  return concat(t, os_concat)
end

---Run a command in a given directory
---@param dir string
---@param cmd string
---@return boolean?  suc
---@return exitcode? exitcode
---@return integer?  code
local function run(dir, cmd)
  return execute(cmd_concat("cd " .. dir, cmd))
end

---Return a quoted version or properly escaped
---@param path string
---@return string
local function quoted_path(path)
  if os_type == "windows" then
    if match(path, " ") then
      return '"' .. path .. '"'
    end
    return path
  else
    path = gsub(path, "\\ ", "\0")
    path = gsub(path, " ", "\\ ")
    return (gsub(path, "\0", "\\ "))
  end
end

-- this is the map to export function symbols to the global space
local global_symbol_map = {
  run = run,
  escapepath = quoted_path,
}

--[=[ Export function symbols ]=]
extend_with(_G, global_symbol_map)
-- [=[ ]=]

---@class oslib_t
---@field cmd_concat fun(...): string
---@field run fun(dir: string, cmd: string): boolean|nil, nil|string, nil|integer
---@field quoted_path fun(path: string): string

return {
  global_symbol_map = global_symbol_map,
  cmd_concat = cmd_concat,
  run = run,
  quoted_path = quoted_path,
}
