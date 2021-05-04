--[[

File l3build-pathlib.lua Copyright (C) 2018-2020 The LaTeX Project

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

---Path utilities
--[===[
This module implements path facilities over strings.
It only depends on the  `object` module.

# Forbidden characters in file paths

From [micrososft documentation](https://docs.microsoft.com/en-us/windows/win32/fileio/naming-a-file)

* < (less than)
* > (greater than)
* : (colon)
* " (double quote)
* / (forward slash)
* \ (backslash)
* | (vertical bar or pipe)
* ? (question mark)
* * (asterisk)

---]===]
---@module pathlib

-- Safeguards and shortcuts

local append    = table.insert
local unappend  = table.remove
local concat    = table.concat
local move      = table.move

local Object = require("l3b-object")

local lpeg  = require("lpeg")
local P     = lpeg.P
local C     = lpeg.C
local V     = lpeg.V
local Cc    = lpeg.Cc
local Ct    = lpeg.Ct

-- The Path objects are implementation details
-- private to this module
---@class Path: Object
---@field public up           string[]
---@field public down         string[]
---@field public is_absolute  boolean
---@field public is_void      boolean
---@field public as_string    string
---@field public copy         fun(self: Path): Path
---@field public append_component fun(self: Path, component: string)

local Path = Object:make_subclass("Path")

if _ENV.during_unit_testing then
  _ENV.Path = Path
end

---comment
---@param self Path
---@param component string
function Path:append_component(component)
  if component == ".." then
    if not unappend(self.down) then
      append(self.up, component)
    end
  else
    if self.down[#self.down] == "" then
      unappend(self.down)
    end
    append(self.down, component)
  end
end

local path_p = P({
    V("is_absolute")
  * ( V("component")
    * ( V("separator")
      * V("component") -- expect the ending dot
    )^0
    + P(0)
  )
  * V("suffix"),
  is_absolute =
      P("/")^1  * Cc(true)    -- leading '/', true means absolute
    + P("./")^0 * Cc(false),  -- leading './'
  component = C( ( P(1) - "/" )^1 ) - P(".") * P(-1), -- a non void string with no "/" but the last "." component if any
  separator = ( P("/") * P("./")^0 )^1,
  suffix = ( P("/")^1 * Cc("") + P(".") )^-1,
})

---Initialize a newly created Path object with a given string.
---@param str any
function Path:__initialize(str)
  self.is_absolute  = self.is_absolute or false
  self.up           = self.up or {}   -- ".." path components
  self.down         = self.down or {} -- down components
  if not str then
    return
  end
  local m = Ct(path_p):match(str)
  if not m then
    return
  end
  self.is_absolute  = m[1]
  for i = 2, #m do
    self:append_component(m[i])
  end
  assert(not self.is_absolute or #self.up == 0, "Unexpected path ".. str )
end

function Path:__tostring()
  return self.as_string
end

function Path.__instance_table:is_void()
  return #self.up + #self.down == 0
end

function Path.__instance_table:extension()
  return self.base_name:match("%.([^%.])$")
end

function Path.__instance_table:as_string()
  local result
  if self.is_absolute then
    result = '/' .. concat(self.down, '/')
  elseif #self.up > 0 then
    local t = {}
    move(self.up, 1, #self.up, 1, t)
    move(self.down, 1, #self.down, #t + 1, t)
    result = concat(t, '/')
  else
    result = concat(self.down, '/')
  end
  self.as_string = result -- now this is a property of self
  return result
end

function Path.__instance_table:base_name()
  local result =
        self.down[#self.down]
    or  self.up[#self.up]
    or ""
  self.base_name = result
  return result
end

function Path.__instance_table:core_name()
  local result = self.base_name
  result = result:match("^(.*)%.") or result
  self.core_name = result
  return result
end

function Path.__instance_table:dir_name()
  local function no_tail(t)
    return #t>0 and { unpack(t, 1, #t - 1) } or nil
  end
  local down = no_tail(self.down)
  local up = down and self.up or no_tail(self.up)
  local result
  if self.is_absolute then
    result = '/' .. concat(down, '/')
  elseif down then
    local t = { unpack(up or {}) }
    move(down, 1, #down, #t + 1, t)
    result = concat(t, "/")
  elseif up then
    result = concat( up, "/")
  else
    result = "."
  end
  if result == "" then
    result = "."
  end
  self.dir_name = result
  return result
end

function Path:copy()
  return Path(self.as_string)
end

---comment
---@param self Path
---@param r Path
---@return Path
function Path:__div(r)
  assert(
    not r.is_absolute or self.is_void,
    "Unable to merge with an absolute path ".. r.as_string
  )
  if self.is_void then
    ---@type Path
    local result = r:copy()
    result.is_absolute = true
    return result
  end
  if r.is_void then
    ---@type Path
    local result = self:copy()
    append(result.down, "")
    return result
  end
  ---@type Path
  local result = self:copy()
  for i = 1, #r.up do
    result:append_component(r.up[i])
  end
  for i = 1, #r.down do
    result:append_component(r.down[i])
  end
  assert(not result.is_absolute or #result.up == 0)
  return result
end

---Split the given string into its path components
---@function path_components
---@param str string
local path_properties = setmetatable({}, {
  __mode = "k",
  __call = function (self, k)
    local result = self[k]
    if result then
      return result
    end
    result = Path(k)
    self[k] = result
    local normalized = result.as_string
    if k ~= normalized then
      self[normalized] = result
    end
    return result
  end,
})

do
  -- implement the / operator for string as path merger
  local string_MT = getmetatable("")

  function string_MT.__div(a, b)
    local path_a = path_properties(a)
    local path_b = path_properties(b)
    local result = path_a / path_b
    local normalized = result.as_string
    path_properties[normalized] = result
    return normalized
  end

end

---Split a path into its base and directory components.
---The base part includes the file extension if any.
---The dir part does not contain the trailing '/'.
---@param path string
---@return string @dir is the part before the last '/' if any, "." otherwise.
---@return string
local function dir_base(path)
  local p = path_properties(path)
  return p.dir_name, p.base_name
end

---Arguably clearer names
---@param path string
---@return string
local function base_name(path)
  return path_properties(path).base_name
end

---Arguably clearer names
---@param path string
---@return string
local function dir_name(path)
  return path_properties(path).dir_name
end

---Strip the extension from a file name (if present)
---@param file string
---@return string
local function core_name(file)
  return path_properties(file).core_name
end

---Return the extension, may be nil.
---@param path string
---@return string | nil
local function extension(path)
  return path_properties(path).extension
end

---Sanitize the path by removing unecessary parts.
---@param path string
---@return string | nil
local function sanitize(path)
  return path_properties(path).as_string
end

---@class pathlib_t
---@field public dir_base  fun(path: string): string, string
---@field public dir_name  fun(path: string): string
---@field public base_name fun(path: string): string
---@field public job_name  fun(path: string): string
---@field public core_name fun(path: string): string
---@field public extension fun(path: string): string

return {
  dir_base  = dir_base,
  dir_name  = dir_name,
  base_name = base_name,
  core_name = core_name,
  extension = extension,
  job_name  = core_name,
  sanitize  = sanitize,
}
