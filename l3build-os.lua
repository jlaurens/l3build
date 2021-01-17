--[[

File l3build-file-functions.lua Copyright (C) 2018-2020 The LaTeX3 Project

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

local getenv   = os.getenv
local execute  = os.execute

local Status   = status

-- Detect the operating system in use
-- Support items are defined here for cases where a single string can cover
-- both Windows and Unix cases: more complex situations are handled inside
-- the support functions
local OS = OS or {}

OS.type = os.type

OS.concat  = ";"
OS.null    = "/dev/null"
OS.pathsep = ":"
OS.setenv  = "export"
OS.yes     = "printf 'y\\n%.0s' {1..300}"

OS.ascii   = "echo \"\""
OS.cmpexe  = getenv("cmpexe") or "cmp"
OS.cmpext  = getenv("cmpext") or ".cmp"
OS.diffext = getenv("diffext") or ".diff"
OS.diffexe = getenv("diffexe") or "diff -c --strip-trailing-cr"
OS.grepexe = "grep"
OS.newline = "\n"

if OS.type == "windows" then
  OS.ascii   = "@echo."
  OS.cmpexe  = getenv("cmpexe") or "fc /b"
  OS.cmpext  = getenv("cmpext") or ".cmp"
  OS.concat  = "&"
  OS.diffext = getenv("diffext") or ".fc"
  OS.diffexe = getenv("diffexe") or "fc /n"
  OS.grepexe = "findstr /r"
  OS.newline = "\n"
  if tonumber(Status.luatex_version) < 100 or
     (tonumber(Status.luatex_version) == 100
       and tonumber(Status.luatex_revision) < 4) then
    OS.newline = "\r\n"
  end
  OS.null    = "nul"
  OS.pathsep = ";"
  OS.setenv  = "set"
  OS.yes     = "for /l %I in (1, 1, 300) do @echo y"
end

-- Run a command in a given directory
OS.run = function (dir, cmd, ...)
  local error_n = execute("cd " .. dir .. OS.concat .. cmd:format(...))
  if error_n ~= 0 then
    return error_n
  end
end

-- Expose as global only what is documented.
OS.exposition = {
  os_concat = "concat",
  os_null = "null",
  os_pathsep = "pathsep",
  os_setenv = "setenv",
  os_yes = "yes",
  run = "run"
}

return OS
