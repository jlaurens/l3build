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

local execute = os.execute
local getenv  = os.getenv
local exit    = os.exit
local os_type = os["type"]
local open    = io.open
local popen   = io.popen

local status          = require("status")
local luatex_revision = status.luatex_revision
local luatex_version  = status.luatex_version

local concat    = table.concat
local append    = table.insert

local time      = os.time
local difftime  = os.difftime

---@type utlib_t
local utlib             = require("l3b-utillib")
local to_quoted_string  = utlib.to_quoted_string
local items             = utlib.items
local first_of          = utlib.first_of
local print_diff_time   = utlib.print_diff_time

---@class oslib_vars_t
---@field public debug flags_t

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
---@field public pathsep string
---@field public concat  string
---@field public null    string
---@field public ascii   string
---@field public cmpexe  string
---@field public cmpext  string
---@field public diffexe string
---@field public diffext string
---@field public grepexe string
---@field public setenv  string
---@field public yes     string

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
  -- Next does not make sense because l3build is shipped
  -- with a more recent luatex
  local luatex_version_n = tonumber(luatex_version)
  if luatex_version_n < 100
  or (luatex_version_n == 100 and tonumber(luatex_revision) < 4)
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

---Concat the given strings with `OS.concat`
---@vararg string|number @ other input may cause error
local function cmd_concat(...)
  -- filter out void arguments
  local t = {}
  for item in items(...) do
    if type(item) == "number" or item and item:len() > 0 then
      append(t, item)
    end
  end
  local result
  local success = pcall(function()
    result = concat(t, OS.concat)
  end)
  if success then
    return result
  end
  for v, i in items(...) do
    print("i, v  ", i, v)
  end
  print(debug.traceback())
  error("Cannot build command from components")
end

---Run a command in a given directory
---@param dir string
---@param cmd string
---@return error_level_n
local function run(dir, cmd)
  cmd = cmd_concat("cd " .. to_quoted_string(dir), cmd)
  local start_time
  if Vars.debug.run then
    print("DEBUG run: ".. cmd)
    start_time = time()
  end
  local succ, msg, code = execute(cmd)
  if Vars.debug.run then
    local diff = difftime(time(), start_time)
    print_diff_time("Done run in: %s", diff)
  end
  if succ then
    return 0
  end
  if msg == "signal" then
    print("\nSignal sent ".. tostring(code))
    exit(code)
  end
  return code > 0 and code or 1
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


---if filename is non nil and file readable return contents otherwise nil.
---The content is converted to unix line ending when not binary.
---@function read_content
---@param file_path string
---@param is_binary boolean
---@return string? @content the content of the file
local function read_content(file_path, is_binary)
  if file_path then
    local fh = open(file_path, is_binary and "rb" or "r")
    if not fh then
      return
    end
    local content = fh:read("a")
    fh:close()
    return not is_binary and os_type == "windows"
      and content:gsub("\r\n?", "\n")
      or  content
  end
end

---if filename is non nil and file readable return contents otherwise nil
---Before write, the content is converted to host line ending.
---@function write_content
---@param file_path string
---@param content string
---@return error_level_n
local function write_content(file_path, content)
  if file_path then
    local fh = assert(open(file_path, "w"))
    if not fh then
      return 1
    end
    if os_type == "windows" then
      content = content:gsub("\n", OS.newline)
    end
    local error_level = fh:write(content) and 0 or 1
    fh:close()
    return error_level
  end
end

---Execute the given command and returns the output
---@param command string
---@return string
local function read_command(command)
---Return the result.
  local fh = assert(popen(command, "r"))
  local t  = assert(fh:read("a"))
  fh:close()
  return t
end

---@class oslib_t
---@field public OS             OS_t
---@field public Vars           oslib_vars_t
---@field public cmd_concat     fun(...): string
---@field public run            fun(dir: string, cmd: string): boolean?, exitcode?, integer?
---@field public quoted_path    fun(path: string): string
---@field public read_content   fun(file_path: string, is_binary: boolean): string|nil
---@field public write_content  fun(file_path: string, content: string): error_level_n
---@field public read_command   fun(command: string): string

return {
  Vars          = Vars,
  OS            = OS,
  cmd_concat    = cmd_concat,
  run           = run,
  quoted_path   = quoted_path,
  read_content  = read_content,
  write_content = write_content,
  read_command  = read_command,
}
