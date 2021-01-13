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

FF = {}

-- Convert a file glob into a pattern for use by e.g. string.gsub
-- Based on https://github.com/davidm/lua-glob-pattern
-- Simplified substantially: "[...]" syntax not supported as is not
-- required by the file patterns used by the teaFF. Also note style
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
FF.glob_to_pattern = function (glob)

  local pattern = "^" -- pattern being built
  local i = 0 -- index in glob
  local char -- char at index i in glob

  -- escape pattern char
  local function escape(char)
    return char:match("^%w$") and char or "%" .. char
  end

  -- Convert tokens.
  while true do
    i = i + 1
    char = glob:sub(i, i)
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
      char = glob:sub(i, i)
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

-- Detect the operating system in use
-- Support items are defined here for cases where a single string can cover
-- both Windows and Unix cases: more complex situations are handled inside
-- the support functions
FF.os_concat  = ";"
FF.os_null    = "/dev/null"
FF.os_pathsep = ":"
FF.os_setenv  = "export"
FF.os_yes     = "printf 'y\\n%.0s' {1..300}"

FF.os_ascii   = "echo \"\""
FF.os_cmpexe  = os.getenv("cmpexe") or "cmp"
FF.os_cmpext  = os.getenv("cmpext") or ".cmp"
FF.os_diffext = os.getenv("diffext") or ".diff"
FF.os_diffexe = os.getenv("diffexe") or "diff -c --strip-trailing-cr"
FF.os_grepexe = "grep"
FF.os_newline = "\n"

if os.type == "windows" then
  FF.os_ascii   = "@echo."
  FF.os_cmpexe  = os.getenv("cmpexe") or "fc /b"
  FF.os_cmpext  = os.getenv("cmpext") or ".cmp"
  FF.os_concat  = "&"
  FF.os_diffext = os.getenv("diffext") or ".fc"
  FF.os_diffexe = os.getenv("diffexe") or "fc /n"
  FF.os_grepexe = "findstr /r"
  FF.os_newline = "\n"
  if tonumber(status.luatex_version) < 100 or
     (tonumber(status.luatex_version) == 100
       and tonumber(status.luatex_revision) < 4) then
    FF.os_newline = "\r\n"
  end
  FF.os_null    = "nul"
  FF.os_pathsep = ";"
  FF.os_setenv  = "set"
  FF.os_yes     = "for /l %I in (1,1,300) do @echo y"
end

-- Deal with the fact that Windows and Unix use different path separators
local function unix_to_win(path)
  return path:gsub("/", "\\")
end

function FF.normalize_path(path)
  if os.type == "windows" then
    return unix_to_win(path)
  end
  return path
end

-- Return an absolute path from a relative one
function FF.abspath(path)
  local oldpwd = L3.lfs.currentdir()
  L3.lfs.chdir(path)
  local result = L3.lfs.currentdir()
  L3.lfs.chdir(oldpwd)
  return FF.escapepath(result:gsub("\\", "/"))
end

function FF.escapepath(path)
  if os.type == "windows" then
    local path,count = path:gsub('"','')
    if count % 2 ~= 0 then
      print("Unbalanced quotes in path")
      os.exit(0)
    else
      if path:match(" ") then
        return '"' .. path .. '"'
      end
      return path
    end
  else
    path = path:gsub("\\ ","[PATH-SPACE]")
    path = path:gsub(" ","\\ ")
    return path:gsub("%[PATH-SPACE%]","\\ ")
  end
end

-- For cleaning out a directory, which also ensures that it exists
FF.cleandir = function (dir)
  local errorlevel = FF.mkdir(dir)
  if errorlevel ~= 0 then
    return errorlevel
  end
  return FF.rm(dir, "**")
end

-- Copy files 'quietly'
FF.cp = function (glob, source, dest)
  local errorlevel
  for i,_ in pairs(FF.tree(source, glob)) do
    local source = source .. "/" .. i
    if os.type == "windows" then
      if L3.lfs.attributes(source).mode == "directory" then
        errorlevel = os.execute(
          'xcopy /y /e /i "' .. unix_to_win(source) .. '" "'
             .. unix_to_win(dest .. '/' .. i) .. '" > nul'
        )
      else
        errorlevel = os.execute(
          'xcopy /y "' .. unix_to_win(source) .. '" "'
             .. unix_to_win(dest .. '/') .. '" > nul'
        )
      end
    else
      errorlevel = os.execute("cp -RLf '" .. source .. "' '" .. dest .. "'")
    end
    if errorlevel ~=0 then
      return errorlevel
    end
  end
  return 0
end

-- OS-dependent test for a directory
FF.direxists = function (dir)
  local errorlevel
  if os.type == "windows" then
    errorlevel =
      os.execute("if not exist \"" .. unix_to_win(dir) .. "\" exit 1")
  else
    errorlevel = os.execute("[ -d '" .. dir .. "' ]")
  end
  return errorlevel == 0
end

FF.fileexists = function (file)
  local f = io.open(file, "r")
  if f ~= nil then
    f:close()
    return true
  else
    return false
  end
end

-- Generate a table containing all file names of the given glob or all files
-- if absent
function FF.filelist(path, glob)
  local files = { }
  local pattern
  if glob then
    pattern = FF.glob_to_pattern(glob)
  end
  if FF.direxists(path) then
    for entry in L3.lfs.dir(path) do
      if pattern then
        if entry:match(pattern) then
          files[#files+1] = entry
        end
      else
        if entry ~= "." and entry ~= ".." then
          files[#files+1] = entry
        end
      end
    end
  end
  return files
end

-- Does what filelist does, but can also glob subdirectories. In the returned
-- table, the keys are paths relative to the given starting path, the values
-- are their counterparts relative to the current working directory.
function FF.tree(path, glob)
  local function cropdots(path)
    return path:gsub("^%./", ""):gsub("/%./", "/")
  end
  local function always_true()
    return true
  end
  local function is_dir(file)
    return L3.lfs.attributes(file).mode == "directory"
  end
  local dirs = {["."] = cropdots(path)}
  for pattern, criterion in cropdots(glob):gmatch("([^/]+)(/?)") do
    local criterion = criterion == "/" and is_dir or always_true
    local function fill(path, dir, table)
      for _, file in ipairs(FF.filelist(dir, pattern)) do
        local fullpath = path .. "/" .. file
        if file ~= "." and file ~= ".." and
          fullpath ~= builddir
        then
          local fulldir = dir .. "/" .. file
          if criterion(fulldir) then
            table[fullpath] = fulldir
          end
        end
      end
    end
    local newdirs = {}
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
      for path, dir in pairs(dirs) do
        fill(path, dir, newdirs)
      end
    end
    dirs = newdirs
  end
  return dirs
end

FF.remove_duplicates = function (a)
  -- Return array with duplicate entries removed from input array `a`.
  local uniq = {}
  local hash = {}
  for _,v in ipairs(a) do
    if (not hash[v]) then
      hash[v] = true
      uniq[#uniq+1] = v
    end
  end
  return uniq
end

FF.mkdir = function (dir)
  if os.type == "windows" then
    -- Windows (with the extensions) will automatically make directory trees
    -- but issues a warning if the dir already exists: avoid by including a test
    local dir = unix_to_win(dir)
    return os.execute(
      "if not exist "  .. dir .. "\\nul " .. "mkdir " .. dir
    )
  else
    return os.execute("mkdir -p " .. dir)
  end
end

-- Rename
FF.ren = function (dir, source, dest)
  local dir = dir .. "/"
  if os.type == "windows" then
    local source = source:gsub("^%.+/", "")
    local dest = dest:gsub("^%.+/", "")
    return os.execute("ren " .. unix_to_win(dir) .. source .. " " .. dest)
  else
    return os.execute("mv " .. dir .. source .. " " .. dir .. dest)
  end
end

-- Remove file(s) based on a glob
FF.rm = function (source, glob)
  for i,_ in pairs(FF.tree(source, glob)) do
    FF.rmfile(source,i)
  end
  return 0
end

-- Remove file
FF.rmfile = function (source, file)
  os.remove(source .. "/" .. file)
  -- os.remove doesn't give a sensible errorlevel
  return 0
end

-- Remove a directory tree
FF.rmdir = function (dir)
  -- First, make sure it exists to avoid any errors
  FF.FF.mkdir(dir)
  if os.type == "windows" then
    return os.execute("rmdir /s /q " .. unix_to_win(dir))
  else
    return os.execute("rm -r " .. dir)
  end
end

-- Run a command in a given directory
FF.run = function (dir, cmd)
  return os.execute("cd " .. dir .. FF.os_concat .. cmd)
end

-- Split a path into file and directory component
FF.splitpath = function (file)
  local path, name = file:match("^(.*)/([^/]*)$")
  if path then
    return path, name
  else
    return ".", file
  end
end

-- Arguably clearer names
FF.basename = function (file)
  return select(2, FF.splitpath(file))
end

FF.dirname = function (file)
  return select(1, FF.splitpath(file))
end

-- Strip the extension from a file name (if present)
FF.jobname = function (file)
  local name = FF.basename(file):match("^(.*)%.")
  return name or file
end

-- Look for files, directory by directory, and return the first existing
FF.locate = function (dirs, names)
  for _,i in ipairs(dirs) do
    for _,j in ipairs(names) do
      local path = i .. "/" .. j
      if FF.fileexists(path) then
        return path
      end
    end
  end
end

return FF