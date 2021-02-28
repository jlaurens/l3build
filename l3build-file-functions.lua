--[[

File l3build-file-functions.lua Copyright (C) 2018-2020 The LaTeX Project

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

--[=[

local fifu        = require("l3b.file-functions")
local cmd_concat = fifu.cmd_concat
local run = fifu.run
local glob_to_pattern = fifu.glob_to_pattern
local to_host = fifu.to_host
local quoted_path = fifu.quoted_path
local abspath = fifu.abspath
local make_directory = fifu.make_directory
local directory_exists = fifu.directory_exists
local file_exists = fifu.file_exists
local file_list = fifu.file_list
local all_files = fifu.all_files
local tree = fifu.tree
local remove_file = fifu.remove_file
local remove_tree = fifu.remove_tree
local make_clean_directory = fifu.make_clean_directory
local copy_tree = fifu.copy_tree
local rename = fifu.rename
local remove_directory = fifu.remove_directory
local dir_base = fifu.dir_base
local dir_name = fifu.dir_name
local base_name = fifu.base_name
local job_name = fifu.job_name
local locate = fifu.locate

--]=]
local pairs            = pairs
local print            = print

local open             = io.open

local attributes       = lfs.attributes
local currentdir       = lfs.currentdir
local chdir            = lfs.chdir
local lfs_dir          = lfs.dir

local execute          = os.execute
local exit             = os.exit
local getenv           = os.getenv
local remove           = os.remove
local os_type          = os.type

local status           = require("status")
local luatex_revision  = status.luatex_revision
local luatex_version   = status.luatex_version

local match            = string.match
local sub              = string.sub
local gmatch           = string.gmatch
local gsub             = string.gsub

local insert           = table.insert
local tbl_concat       = table.concat

local util    = require("l3b.util")
local entries = util.entries
local keys    = util.keys

-- Convert a file glob into a pattern for use by e.g. string.gub
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
local function glob_to_pattern(glob)

  local pattern = "^" -- pattern being built
  local i = 0 -- index in glob
  local char -- char at index i in glob

  -- escape pattern char
  local function escape(char)
    return match(char, "^%w$") and char or "%" .. char
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

-- Detect the operating system in use
-- Support items are defined here for cases where a single string can cover
-- both Windows and Unix cases: more complex situations are handled inside
-- the support functions
os_concat  = ";"
os_null    = "/dev/null"
os_pathsep = ":"
os_setenv  = "export"
os_yes     = "printf 'y\\n%.0s' {1..300}"

os_ascii   = "echo \"\""
os_cmpexe  = getenv("cmpexe") or "cmp"
os_cmpext  = getenv("cmpext") or ".cmp"
os_diffext = getenv("diffext") or ".diff"
os_diffexe = getenv("diffexe") or "diff -c --strip-trailing-cr"
os_grepexe = "grep"
os_newline = "\n"

if os_type == "windows" then
  os_ascii   = "@echo."
  os_cmpexe  = getenv("cmpexe") or "fc /b"
  os_cmpext  = getenv("cmpext") or ".cmp"
  os_concat  = "&"
  os_diffext = getenv("diffext") or ".fc"
  os_diffexe = getenv("diffexe") or "fc /n"
  os_grepexe = "findstr /r"
  os_newline = "\n"
  if tonumber(luatex_version) < 100 or
     (tonumber(luatex_version) == 100
       and tonumber(luatex_revision) < 4) then
    os_newline = "\r\n"
  end
  os_null    = "nul"
  os_pathsep = ";"
  os_setenv  = "set"
  os_yes     = "for /l %I in (1,1,300) do @echo y"
end

---Concat the given string with `os_concat`
---@vararg nil ...
local function cmd_concat(...)
  return tbl_concat({ ... }, os_concat)
end

---Run a command in a given directory
---@param dir string
---@param cmd string
---@return string
local function run(dir, cmd)
  return execute(cmd_concat("cd " .. dir, cmd))
end

-- Deal with the fact that Windows and Unix use different path separators
local function unix_to_win(cmd)
  return (gsub(cmd, "/", "\\"))
end

---Convert to host directory separator
---@param cmd string
---@return string
local function to_host(cmd)
  if os_type == "windows" then
    return unix_to_win(cmd)
  end
  return cmd
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

---Return a quoted absolute path from a relative one
---Due to chdir, path must exist and be accessible.
---@param path string
---@return string
local function abspath(path)
  local oldpwd = currentdir()
  local ok, msg = chdir(path)
  if ok then
    local result = currentdir()
    chdir(oldpwd)
    return quoted_path(gsub(result, "\\", "/"))
  end
  error(msg)
end

local function make_directory(dir)
  if os_type == "windows" then
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

---Whether there is a directory at the given path
---@param path string
---@return boolean
local function directory_exists(path)
  return attributes(path, "mode") == "directory"
--[=[ Original implementation
  local errorlevel
  if os_type == "windows" then
    errorlevel =
      execute("if not exist \"" .. unix_to_win(path) .. "\" exit 1")
  else
    errorlevel = execute("[ -d '" .. path .. "' ]")
  end
  if errorlevel ~= 0 then
    return false
  end
  return true
--]=]
end

---Whether there is a file at the given path
---@param path string
---@return boolean
local function file_exists(path)
  return attributes(path, "mode") == "file"
--[=[ Original implementation
  local f = open(file, "r")
  if f ~= nil then
    f:close()
    return true
  else
    return false -- also file exits and is not readable
  end
--]=]
end


---Generate a table containing all file names of the given glob
---or all files if absent
---@param src_path string
---@param glob string|nil
---@return table<integer, string>
local function file_list(src_path, glob)
  local files = {}
  local pattern
  if glob then
    pattern = glob_to_pattern(glob)
  end
  if directory_exists(src_path) then
    for entry in lfs_dir(src_path) do
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

---Return an iterator of the files at path matching the given glob.
---@param path string
---@param glob string
---@return fun(): string
local function all_files(path, glob)
  return entries(file_list(path, glob))
end

---Does what filelist does, but can also glob subdirectories.
---In the returned table, the keys are paths relative to the given source path,
---the values are their counterparts relative to the current working directory.
---@param src_path string
---@param glob string
---@return table<string, string>
local function tree(src_path, glob)
  local function cropdots(path)
    return (gsub(gsub(path, "^%./", ""), "/%./", "/"))
  end
  src_path = cropdots(src_path)
  glob = cropdots(glob)
  local function always_true()
    return true
  end
  local function is_dir(file)
    return attributes(file, "mode") == "directory"
  end
  local result = { ["."] = src_path }
  for glob_part, sep in gmatch(glob, "([^/]+)(/?)/*") do
    local accept = sep == "/" and is_dir or always_true
    ---Feeds the given table according to `glob_part`
    ---@param p_src string path relative to `src_path`
    ---@param p_cwd string path counterpart relative to the current working directory
    ---@param table table
    local function fill(p_src, p_cwd, table)
      for file in all_files(p_cwd, glob_part) do
        local p_src_file = p_src .. "/" .. file
        if file ~= "." and file ~= ".." and
        p_src_file ~= builddir -- TODO: ensure that `builddir` is properly formatted
        then
          local p_cwd_file = p_cwd .. "/" .. file
          if accept(p_cwd_file) then
            table[p_src_file] = p_cwd_file
          end
        end
      end
    end
    local new_result = {}
    if glob_part == "**" then
      while true do
        local p_src, p_cwd = next(result)
        if not p_src then
          break
        end
        result[p_src] = nil
        new_result[p_src] = p_cwd
        fill(p_src, p_cwd, result)
      end
    else
      for p_src, p_cwd in pairs(result) do
        fill(p_src, p_cwd, new_result)
      end
    end
    result = new_result
  end
  return result
end

---Remove the file with the given name at the given location.
---@param source string
---@param name string
---@return integer
local function remove_file(source, name)
  remove(source .. "/" .. name)
  -- os.remove doesn't give a sensible errorlevel
  -- TODO: Is it an error to remove a file that does not exist?
  return 0
end





---Remove the files matching glob starting at source
---Empties directories but do not remove them.
---@param source string
---@param glob string
---@return integer
local function remove_tree(source, glob)
  for i in keys(tree(source, glob)) do
    remove_file(source, i)
  end
  -- os.remove doesn't give a sensible errorlevel
  return 0
end

-- For cleaning out a directory, which also ensures that it exists
local function make_clean_directory(dir)
  local errorlevel = make_directory(dir)
  if errorlevel ~= 0 then
    return errorlevel
  end
  return remove_tree(dir, "**")
end

---Copy files 'quietly'.
---@param glob string
---@param source string
---@param dest string
---@return integer
local function copy_tree(glob, source, dest)
  local errorlevel
  for p_src, p_cwd in pairs(tree(source, glob)) do
    -- p_src is a path relative to `source` whereas
    -- p_cwd is the counterpart relative to the current working directory
    if os_type == "windows" then
      if attributes(p_cwd, "mode") == "directory" then
        errorlevel = execute(
          'xcopy /y /e /i "' .. unix_to_win(p_cwd) .. '" "'
             .. unix_to_win(dest .. '/' .. p_src) .. '" > nul'
        )
      else
        errorlevel = execute(
          'xcopy /y "' .. unix_to_win(p_cwd) .. '" "'
             .. unix_to_win(dest .. '/') .. '" > nul'
        )
      end
    else
      errorlevel = execute("cp -RLf '" .. p_cwd .. "' '" .. dest .. "'")
    end
    if errorlevel ~=0 then
      return errorlevel
    end
  end
  return 0
end

---Rename. Whether paths are properly escaped is another story...
---@param dir string
---@param source string
---@param dest string
---@return boolean|nil
---@return nil|string
---@return nil|integer
local function rename(dir, source, dest)
  dir = dir .. "/"
  if os_type == "windows" then
    source = gsub(source, "^%./", "")
    dest = gsub(dest, "^%./", "")
    return execute("ren " .. unix_to_win(dir) .. source .. " " .. dest)
  else
    return execute("mv " .. dir .. source .. " " .. dir .. dest)
  end
end

---Remove a directory tree.
---@param dir string Must be properly escaped.
---@return boolean|nil
---@return nil|string
---@return nil|integer
local function remove_directory(dir)
  -- First, make sure it exists to avoid any errors
  if os_type == "windows" then
    make_directory(dir)
    return execute("rmdir /s /q " .. unix_to_win(dir))
  else
    return execute("rm -rf " .. dir)
  end
end

---Split a path into file and directory components.
---The dir part does not contain the trailing '/'.
---@param file any
---@return string dir is the part before the last '/' if any, "." otherwise.
---@return string
local function dir_base(file)
  local dir, base = match(file, "^(.*)/([^/]*)$")
  if dir then
    return dir, base
  else
    return ".", file
  end
end

-- Arguably clearer names
local function base_name(file)
  return (select(2, dir_base(file)))
end

local function dir_name(file)
  return (select(1, dir_base(file))) -- () required
end

-- Strip the extension from a file name (if present)
local function job_name(file)
  local name = match(base_name(file), "^(.*)%.")
  return name or file
end

---Look for files, directory by directory, and return the first existing
---@param dirs any
---@param names any
---@return string
local function locate(dirs, names)
  for i in entries(dirs) do
    for j in entries(names) do
      local path = i .. "/" .. j
      if file_exists(path) then
        return path
      end
    end
  end
end

--[=[ Export function symbols

_G.run = run
_G.glob_to_pattern = glob_to_pattern
_G.to_host = to_host
_G.quoted_path = quoted_path
_G.abspath = abspath
_G.mkdir = make_directory
_G.directory_exists = directory_exists
_G.fileexists = file_exists
_G.filelist = file_list
-- _G.tree = tree
_G.rmfile = remove_file
_G.rm = remove_tree
_G.cleandir = make_clean_directory
_G.cp = copy_tree
_G.rmdir = remove_directory
_G.ren = rename
_G.splitpath = dir_base
_G.basename = base_name
_G.dirname = dir_name
_G.jobname = job_name
_G.locate = locate

-- [=[ ]=]

return {
  cmd_concat = cmd_concat,
  run = run,
  glob_to_pattern = glob_to_pattern,
  to_host = to_host,
  quoted_path = quoted_path,
  abspath = abspath,
  make_directory = make_directory,
  directory_exists = directory_exists,
  file_exists = file_exists,
  file_list = file_list,
  all_files = all_files,
  tree = tree,
  remove_file = remove_file,
  remove_tree = remove_tree,
  make_clean_directory = make_clean_directory,
  copy_deep_glob = copy_tree,
  rename = rename,
  remove_directory = remove_directory,
  dir_base = dir_base,
  dir_name = dir_name,
  base_name = base_name,
  job_name = job_name,
  locate = locate,
}
