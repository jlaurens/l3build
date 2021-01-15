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

local pairs            = pairs
local print            = print

local open             = io.open

local attributes       = lfs.attributes -- lfs is a global variable
local Vars.currentdir       = lfs.Vars.currentdir
local chdir            = lfs.chdir
local lfs_dir          = lfs.dir

local execute          = os.execute
local exit             = os.exit
local getenv           = os.getenv
local remove           = os.remove

local match            = string.match
local sub              = string.sub
local gmatch           = string.gmatch
local gsub             = string.gsub

local insert           = table.insert

local FS = {}

-- Convert a file glob into a pattern for use by e.g. string.gsub
-- Based on https://github.com/davidm/lua-glob-pattern
-- Simplified substantially: "[...]" syntax not supported as is not
-- required by the file patterns used by the team. Also note style
-- changes to match coding approach in rest of this file.
--
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

function FS.glob_to_pattern(glob)

  local pattern = "^" -- pattern being built
  local i = 0 -- index in glob
  local char -- char at index i in glob

  -- escape pattern char
  local function escape(chr)
    return match(chr, "^%w$") and chr or "%" .. chr
  end

  -- Convert tokens.
  while true do
    i = i + 1
    char = sub(glob, i, i)
    if char == "" then
      pattern = pattern .. "$"
      break
    elseif char == "?" then
      pattern = pattern .. "."
    elseif char == "*" then
      pattern = pattern .. ".*"
    elseif char == "[" then
      -- Ignored
      print("[...] syntax not supported in globs!")
    elseif char == "\\" then
      i = i + 1
      char = sub(glob, i, i)
      if char == "" then
        pattern = pattern .. "\\$"
        break
      end
      pattern = pattern .. escape(char)
    else
      pattern = pattern .. escape(char)
    end
  end
  return pattern
end

-- Deal with the fact that Windows and Unix use different path separators
local function unix_to_win(path)
  return gsub(path, "/", "\\")
end

function FS.normalize_path(path)
  if OS.type == "windows" then
    return unix_to_win(path)
  end
  return path
end

-- Return an absolute path from a relative one
function FS.abspath(path)
  local oldpwd = Vars.currentdir()
  chdir(path)
  local result = Vars.currentdir()
  chdir(oldpwd)
  return FS.escape_path(gsub(result, "\\", "/"))
end

-- For cleaning out a directory, which also ensures that it exists
function FS.cleandir(dir)
  local errorlevel = FS.mkdir(dir)
  if errorlevel ~= 0 then
    return errorlevel
  end
  return FS.rm(dir, "**")
end

-- Copy files 'quietly'
FS.cp = function (glob, source, dest)
  local errorlevel
  for i, _ in pairs(FS.tree(source, glob)) do
    local source = source .. "/" .. i
    if OS.type == "windows" then
      if attributes(source)["mode"] == "directory" then
        errorlevel = execute(
          'xcopy /y /e /i "' .. unix_to_win(source) .. '" "'
             .. unix_to_win(dest .. '/' .. i) .. '" > nul'
        )
      else
        errorlevel = execute(
          'xcopy /y "' .. unix_to_win(source) .. '" "'
             .. unix_to_win(dest .. '/') .. '" > nul'
        )
      end
    else
      errorlevel = execute("cp -RLf '" .. source .. "' '" .. dest .. "'")
    end
    if errorlevel ~=0 then
      return errorlevel
    end
  end
  return 0
end

-- OS-dependent test for a directory
FS.direxists = function (dir)
  local errorlevel
  if OS.type == "windows" then
    errorlevel =
      execute("if not exist \"" .. unix_to_win(dir) .. "\" exit 1")
  else
    errorlevel = execute("[ -d '" .. dir .. "' ]")
  end
  if errorlevel ~= 0 then
    return false
  end
  return true
end

FS.fileexists = function (file)
  local f = open(file, "r")
  if f ~= nil then
    f:close()
    return true
  else
    return false
  end
end

-- Generate a table containing all file names of the given glob or all files
-- if absent
FS.filelist = function (path, glob)
  local files = {}
  local pattern
  if glob then
    pattern = FS.glob_to_pattern(glob)
  end
  if FS.direxists(path) then
    for entry in lfs_dir(path) do
      if pattern then
        if match(entry, pattern) then
          insert(files, entry)
        end
      else
        if entry ~= "." and entry ~= ".." then
          insert(files, entry)
        end
      end
    end
  end
  return files
end

function FS.mkdir(dir)
  if OS.type == "windows" then
    -- Windows (with the extensions) will automatically make directory trees
    -- but issues a warning if the dir already exists: avoid by including a test
    dir = unix_to_win(dir)
    return execute(
      "if not exist "  .. dir .. "\\nul " .. "mkdir " .. dir
    )
  else
    return execute("mkdir -p " .. dir)
  end
end

-- Rename
function FS.ren(dir, source, dest)
  dir = dir .. "/"
  if OS.type == "windows" then
    source = gsub(source, "^%.+/", "")
    dest = gsub(dest, "^%.+/", "")
    return execute("ren " .. unix_to_win(dir) .. source .. " " .. dest)
  else
    return execute("mv " .. dir .. source .. " " .. dir .. dest)
  end
end

-- Remove file
local function rmfile(source, file)
  remove(source .. "/" .. file)
  -- os.remove doesn't give a sensible errorlevel
  return 0
end

-- Remove file(s) based on a glob
function FS.rm(source, glob)
  for i, _ in pairs(FS.tree(source, glob)) do
    rmfile(source, i)
  end
  -- os.remove doesn't give a sensible errorlevel
  return 0
end

-- Remove a directory tree
FS.rmdir = function (dir)
  -- First, make sure it exists to avoid any errors
  FS.mkdir(dir)
  if OS.type == "windows" then
    return execute("rmdir /s /q " .. unix_to_win(dir))
  else
    return execute("rm -r " .. dir)
  end
end

-- Split a path into file and directory component
FS.splitpath = function (file)
  local path, name = match(file, "^(.*)/([^/]*)$")
  if path then
    return path, name
  else
    return ".", file
  end
end

-- Arguably clearer names
FS.basename = function (file)
  return(select(2, FS.splitpath(file)))
end

FS.dirname = function (file)
  return(select(1, FS.splitpath(file)))
end

-- Strip the extension from a file name (if present)
FS.jobname = function (file)
  local name = match(FS.basename(file), "^(.*)%.")
  return name or file
end

-- Expose as global only what is documented.
FS.expose = function ()
  for k, v in pairs({
    glob_to_pattern = "glob_to_pattern",
    normalize_path = "normalize_path",
    abspath = "abspath",
    cleandir = "cleandir",
    cp = "cp",
    direxists = "direxists",
    fileexists = "fileexists",
    filelist = "filelist",
    mkdir = "mkdir",
    ren = "ren",
    rm = "rm",
    splitpath = "splitpath",
    basename = "basename",
    dirname = "dirname",
    jobname = "jobname",
  }) do
    _ENV[k] = FS[v]
  end
end

-- Does what filelist does, but can also glob subdirectories. In the returned
-- table, the keys are paths relative to the given starting path, the values
-- are their counterparts relative to the current working directory.
FS.tree = function (path, glob)
  local function cropdots(p)
    return gsub(gsub(p, "^%./", ""), "/%./", "/")
  end
  local function always_true()
    return true
  end
  local function is_dir(file)
    return attributes(file)["mode"] == "directory"
  end
  local dirs = {["."] = cropdots(path)}
  for pattern, criterion in gmatch(cropdots(glob), "([^/]+)(/?)") do
    local criterion = criterion == "/" and is_dir or always_true
    local function fill(p, dir, table)
      for _, file in ipairs(FS.filelist(dir, pattern)) do
        local fullpath = p .. "/" .. file
        if file ~= "." and file ~= ".." and fullpath ~= builddir then
          local fulldir = dir .. "/" .. file
          if criterion(fulldir) then
            table[fullpath] = fulldir
          end
        end
      end
    end
    local newdirs = {}
    local dir
    if pattern == "**" then
      while true do
        path, dir = next(dirs)
        if not path then
          break
        end
        dirs[path] = nil
        newdirs[path] = dir
        fill(path, dir, dirs)
      end
    else
      for p, d in pairs(dirs) do
        fill(p, d, newdirs)
      end
    end
    dirs = newdirs
  end
  return dirs
end

-- Return array with duplicate entries removed from input array `a`.
-- This may not belong here
FS.remove_duplicates = function (a)

  local uniq = {}
  local hash = {}

  for _, v in ipairs(a) do
    if (not hash[v]) then
      hash[v] = true
      uniq[#uniq+1] = v
    end
  end

  return uniq
end

function FS.escape_path(path)
  if OS.type == "windows" then
    local count
    path, count = gsub(path,'"','')
    if count % 2 ~= 0 then
      print("Unbalanced quotes in path")
      exit(0)
    else
      if match(path," ") then
        return '"' .. path .. '"'
      end
      return path
    end
  else
    path = gsub(path,"\\ ","[PATH-SPACE]")
    path = gsub(path," ","\\ ")
    return gsub(path,"%[PATH-SPACE%]","\\ ")
  end
end

-- Look for files, directory by directory, and return the first existing
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
