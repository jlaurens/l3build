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

-- local safe guards

local pairs            = pairs
local open             = io.open
local remove           = os.remove

local currentdir       = lfs.currentdir -- lfs is a global variable
local attributes       = lfs.attributes
local chdir            = lfs.chdir
local lfs_dir          = lfs.dir

local L3B = L3B

-- global tables

local OS = L3B.require(OS)

-- Module

local FS = L3B.provide(FS)

FS.dir = {
  -- Directory structure for the build system
  -- Use Unix-style path separators
  current = "./",
  main    = "./",
  -- Substructure for file locations
  docfile    = "./",
  sourcefile = "./",
  textfile   = "./",
  testfile   = "./testfiles/",
  enable_cache = function (self, yorn)
    self.cache_enabled__ = yorn
  end
}

-- dependant paths. When not provided by the global environment,
-- build the path
setmetatable(FS.dir, {
  __index = function (t, key)
    local ans = _ENV[key .. 'dir']
    if ans then
      ;
    elseif key == "support" then
      ans = t.main .. key
    elseif key == "texmf" then
      ans = t.main .. key
    -- Structure within a development area
    elseif key == "build" then
      ans = t.main .. key
    elseif key == "distrib" then
      ans = t.build .. key
    elseif key == "local" then
      ans = t.build .. key
    elseif key == "result" then
      ans = t.build .. key
    elseif key == "test" then
      ans = t.build .. key
    elseif key == "doc" then
      ans = t.build .. key
    elseif key == "unpacked" then
      ans = t.build .. key
    -- Substructure for CTAN release material
    elseif key == "ctan" then
      ans = t.distrib .. key
    elseif key == "tds" then
      ans = t.distrib .. key
    -- special and aliases
    elseif key == "test_support" then
      ans = t.testfile .. "/support"
    elseif key == "testsupp" then
      ans = t.test_support
    elseif key == "unpack" then
      ans = t.unpacked
    elseif key == "typeset" then
      ans = t.doc
    end
    if ans and t.cache_enabled__ then
      t.key = ans -- next time ans will be found
    end
    return ans
  end
})
-- Convert a file glob into a pattern for use by e.g. string.gsub
-- Based on https://github.com/davidm/lua-glob-pattern
-- No more simplification because third party may use it.
-- Support for `**`.
-- License for original globtopattern
--[[

   (c) 2008-2011 David Manura.  Licensed under the same terms as Lua (MIT).

  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in
  all copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
  THE SOFTWARE.
  (end license)

--]]

---Lua pattern from a glob.
---@param glob string
---@return string
function FS.glob_to_pattern(glob)
  local pattern = "^" -- pattern being built
  local i = 0 -- index in glob
  -- escape pattern char
  local function escape(char)
    return char:match("^%w$") and char or "%" .. char
  end
  local function push(s)
    pattern = pattern .. s
  end
  -- Convert tokens.
  local star = false
  while true do
    i = i + 1
    local char = glob:sub(i, i)
    ::will_if_char::
    if char == "" then
      push("$")
      break
    elseif char == "?" then
      push(".")
    elseif char == "*" then
      i = i + 1
      char = glob:sub(i, i)
      if char == "*" then
        if star then
          L3B.error("`**` syntax not supported in simple globs!")
        end
      end
      push(".*")
      goto will_if_char
    elseif char == "/" then
      -- Ignored
      L3B.error("`/` syntax not supported in simple globs!")
    elseif char == "[" then
      -- Ignored
      L3B.error("`[...]` syntax not supported in simple globs!")
    elseif char == "\\" then
      i = i + 1
      char = glob:sub(i, i)
      if char == "" then
        push("\\$")
        break
      end
      push(escape(char))
    else
      push(escape(char))
    end
  end
  return pattern
end

---Lua pattern from a subset of unix globs. See above.
---@param g string
---@return string
function FS.unix_glob_to_pattern(g)
  g =  g:gsub("^%./", "")
        :gsub("/%./", "/")
        :gsub("[^/+]/%.%./", "")
        :gsub("//", "/")

  local p = "^"  -- pattern being built
  local i = 0    -- index in g

  -- unescape glob char
  local function unescape(c)
    if c == '\\' then
      i = i + 1; c = g:sub(i,i)
      if c == '' then
        p = '[^]'
        return false
      end
    end
    return true
  end

  -- escape pattern char
  local function escape(c)
    return c:match("^%w$") and c or '%' .. c
  end

  -- Convert tokens at end of charset.
  local function charset_end(c)
    while 1 do
      if c == '' then
        p = '[^]'
        return false
      elseif c == ']' then
        p = p .. ']'
        break
      else
        if not unescape(c) then break end
        local c1 = c
        i = i + 1; c = g:sub(i,i)
        if c == '' then
          p = '[^]'
          return false
        elseif c == '-' then
          i = i + 1; c = g:sub(i,i)
          if c == '' then
            p = '[^]'
            return false
          elseif c == ']' then
            p = p .. escape(c1) .. '%-]'
            break
          else
            if not unescape(c) then break end
            p = p .. escape(c1) .. '-' .. escape(c)
          end
        elseif c == ']' then
          p = p .. escape(c1) .. ']'
          break
        else
          p = p .. escape(c1)
          i = i - 1 -- put back
        end
      end
      i = i + 1; c = g:sub(i,i)
    end
    return true
  end

  -- Convert tokens in charset.
  local function charset(c)
    i = i + 1; c = g:sub(i,i)
    if c == '' or c == ']' then
      p = '[^]'
      return false
    elseif c == '^' or c == '!' then
      i = i + 1; c = g:sub(i,i)
      if c == ']' then
        -- ignored
      else
        p = p .. '[^'
        if not charset_end(c) then return false end
      end
    else
      p = p .. '['
      if not charset_end(c) then return false end
    end
    return true
  end

  -- Convert tokens.
  while 1 do
    i = i + 1; local c = g:sub(i,i)
    ::if_c::
    if c == '' then
      p = p .. '$'
      break
    elseif c == '?' then
      p = p .. '[^/]'
    elseif c == '*' then
      i = i + 1; c = g:sub(i,i)
      if c == '*' then
        p = p .. '.*'
      else
        p = p .. '[^/]*'
        goto if_c
      end
    elseif c == '[' then
      if not charset(c) then break end
    elseif c == '\\' then
      i = i + 1; c = g:sub(i,i)
      if c == '' then
        p = p .. '\\$'
        break
      end
      p = p .. escape(c)
    else
      p = p .. escape(c)
    end
  end
  return p
end

-- Deal with the fact that Windows and Unix use different path separators
-- necessary at least on command line
local function win_path(path)
  return path:gsub("/", "\\")
end

function FS.normalize_path(path)
  if OS.type == "windows" then
    return win_path(path)
  end
  return path
end

-- Return an absolute path from a relative one
function FS.abspath(path)
  local cwd = currentdir()
  chdir(path)
  local ans = currentdir()
  chdir(cwd)
  return FS.escape_path(ans:gsub("\\", "/"))
end

---For cleaning out a directory, which also ensures that it exists
---@param dir string
---@return number on error nil otherwise
function FS.cleandir(dir)
  local error_n = FS.mkdir(dir)
  if error_n ~= 0 then
    return error_n
  end
  return FS.rm(dir, "**")
end

---Copy files 'quietly'
---@param glob string
---@param source string path directory
---@param dest string path directory
---@return number code error code or nil when ok
FS.cp = function (glob, source, dest)
  for i, _ in pairs(FS.tree(source, glob)) do
    local source_i = source .. "/" .. i
    local cmd
    if OS.type == "windows" then
      if attributes(source_i).mode == "directory" then
        cmd = 'xcopy /y /e /i "' .. win_path(source_i) .. '" "'
                .. win_path(dest .. '/' .. i) .. '" > nul'
      else
        cmd = 'xcopy /y "' .. win_path(source_i) .. '" "'
                .. win_path(dest .. '/') .. '" > nul'
      end
    else
      cmd = "cp -RLf '" .. source_i .. "' '" .. dest .. "'"
    end
    local error_n = L3B.execute(cmd)
    if error_n then
      return error_n
    end
  end
end

---OS-aware test for a directory
---@param dir string path
---@return boolean
FS.direxists = function (dir)
  local cmd
  if OS.type == "windows" then
    cmd = "if not exist \"" .. win_path(dir) .. "\" exit 1"
  else
    cmd = "[ -d '" .. dir .. "' ]"
  end
  return not L3B.execute(cmd)
end

---Whether the file exists
---@param file string
---@return boolean
FS.fileexists = function (file)
  local f = open(file, "r")
  if f then
    f:close()
    return true
  else
    return false
  end
end

---Generate a table containing all file names of the given glob or all files
---if absent
---@param path string
---@param glob string
---@return table
function FS.filelist(path, glob)
  local ans = {}
  if FS.direxists(path) then
    local pattern = glob and FS.glob_to_pattern(glob)
    for entry in lfs_dir(path) do
      if pattern then
        if entry:match(pattern) then
          ans[#ans+1] = entry
        end
      elseif entry ~= "." and entry ~= ".." then
        ans[#ans+1] = entry
      end
    end
  end
  return ans
end

---comment
---@param dir string
---@return number
function FS.mkdir(dir)
  local cmd
  if OS.type == "windows" then
    -- Windows (with the extensions) will automatically make directory trees
    -- but issues a warning if the dir already exists: avoid by including a test
    dir = win_path(dir)
    cmd = "if not exist "  .. dir .. "\\nul " .. "mkdir " .. dir
  else
    cmd = "mkdir -p " .. dir
  end
  return L3B.execute(cmd)
end

-- Rename
---comment
---@param dir string
---@param source string
---@param dest string
---@return number code on error, nil otherwise
function FS.rename(dir, source, dest)
  dir = dir .. "/"
  local cmd
  if OS.type == "windows" then
    source = source:gsub("^%.+/", "") -- Why?
    dest   =   dest:gsub("^%.+/", "")
    cmd = "ren " .. win_path(dir) .. source .. " " .. dest
  else
    cmd = "mv " .. dir .. source .. " " .. dir .. dest
  end
  return L3B.execute(cmd)
end

FS.ren = FS.rename -- TODO remove transitional alias

---Remove a file
---@param dir string path
---@param file string path
local function rmfile(dir, file)
  remove(dir .. "/" .. file)
  -- os.remove doesn't give a sensible error code
  return
end

---Remove file(s) in `source` based on a glob
---@param source string
---@param glob string
function FS.rm(source, glob)
  for i, _ in pairs(FS.tree(source, glob)) do
    rmfile(source, i)
  end
end

-- Remove a directory tree
---comment
---@param dir string
---@return number code on error, nil otherwise
function FS.rmdir(dir)
  -- First, make sure it exists to avoid any errors
  FS.mkdir(dir)
  if OS.type == "windows" then
    return L3B.execute("rmdir /s /q " .. win_path(dir))
  else
    return L3B.execute("rm -r " .. dir)
  end
end

---Split a path into file and directory component
---@param path string
---@return any (dir name, base name)
function FS.splitpath(path)
  local dir, name = path:match("^(.*)/([^/]*)$")
  if dir then
    return dir, name
  else
    return ".", path
  end
end

---Base name of the given path
---@param path string
---@return string
function FS.basename(path)
  return(select(2, FS.splitpath(path)))
end

---Directory name of the given path, '.' at least.
---@param path string
---@return string
function FS.dirname(path)
  return(select(1, FS.splitpath(path)))
end

-- Strip the extension from a file name (if present)
function FS.jobname(path)
  return FS.basename(path):match("^(.*)%.") or path
end

-- Expose as global only what is documented.
FS.exposition = {
  glob_to_pattern = "glob_to_pattern",
  normalize_path = "normalize_path",
  abspath = "abspath",
  cleandir = "cleandir",
  cp = "cp",
  direxists = "direxists",
  fileexists = "fileexists",
  filelist = "filelist",
  mkdir = "mkdir",
  ren = "rename",
  rm = "rm",
  splitpath = "splitpath",
  basename = "basename",
  dirname = "dirname",
  jobname = "jobname",
}

---Does what filelist does, but can also glob subdirectories. In the returned
---table, the keys are paths relative to the given starting path, the values
---are their counterparts relative to the current working directory.
---@param path string
---@param glob string
---@return table
function FS.tree(path, glob)
  local pattern = FS.unix_glob_to_pattern(glob)
  path =  path:gsub("^%./", "")
              :gsub("/%./", "/")
              :gsub("[^/+]/%.%./", "")
              :gsub("//", "/")
  local ans = {}
  local dirs = {
    ['.'] = path
  }
  while #dirs do
    local deep = {}
    local path_p, cwd_p = next(dirs)
    for p in lfs_dir(cwd_p) do
      if p ~= "." and p ~= ".." then -- TODO: builddir did not make sense.
        local path_rel = path_p .. "/" .. p
        local cwd_rel  = cwd_p  .. "/" .. p
        if attributes(cwd_rel).mode == "directory" then
          deep[path_rel] = cwd_rel
        elseif path_rel:match(pattern) then
          ans [path_rel] = cwd_rel
        end
      end
    end
    dirs = deep
  end
  return ans
end

---Return array with duplicate entries removed from input array `a`.
---This may not belong here
---@param a table
---@return table
FS.without_duplicates = function (a)
  local ans = {}
  local set = {}
  for _, v in ipairs(a) do
    if (not set[v]) then
      set[v] = true
      ans[#ans+1] = v
    end
  end
  return ans
end

---Escape the unescaped space character.
---@param path string
---@return string
function FS.escape_path(path)
  if OS.type == "windows" then
    local ans, count = path:gsub('"','')
    if count % 2 ~= 0 then
      L3B.error("Unbalanced quotes in path " .. path)
    else
      if ans:match(" ") then
        return '"' .. ans .. '"'
      end
      return ans
    end
  else
    return  path:gsub("\\\\","\0")
                :gsub("\\ ","\1")
                :gsub(" ","\\ ")
                :gsub("\1","\\ ")
                :gsub("\0","\\\\")
  end
end

---Look for files, directory by directory, and return the first existing
---@param dirs table
---@param names table
---@return string
function FS.locate(dirs, names)
  for _, i in ipairs(dirs) do
    for _, j in ipairs(names) do
      local path = i .. "/" .. j
      if FS.fileexists(path) then
        return path
      end
    end
  end
end

return FS
