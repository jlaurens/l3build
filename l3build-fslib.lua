--[[

File l3build-fslib.lua Copyright (C) 2018-2020 The LaTeX Project

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
---@type fslib_t
local fslib                 = require("l3b.fslib")
local to_host               = fslib.to_host
local absolute_path         = fslib.absolute_path
local make_directory        = fslib.make_directory
local directory_exists      = fslib.directory_exists
local file_exists           = fslib.file_exists
local locate                = fslib.locate
local file_list             = fslib.file_list
local all_files             = fslib.all_files
local tree                  = fslib.tree
local rename                = fslib.rename
local copy_tree             = fslib.copy_tree
local make_clean_directory  = fslib.make_clean_directory
local remove_file           = fslib.remove_file
local remove_tree           = fslib.remove_tree
local remove_directory      = fslib.remove_directory
--]=]
local pairs            = pairs

local lfs              = require("lfs")
local attributes       = lfs.attributes
local currentdir       = lfs.currentdir
local chdir            = lfs.chdir
local lfs_dir          = lfs.dir

local execute          = os.execute
local remove           = os.remove
local os_type          = os["type"]

local match            = string.match
local gmatch           = string.gmatch
local gsub             = string.gsub

local append           = table.insert

---@type utlib_t
local utlib       = require("l3b.utillib")
local entries     = utlib.entries
local keys        = utlib.keys
local first_of    = utlib.first_of
local extend_with = utlib.extend_with

---@type gblib_t
local gblib           = require("l3b.globlib")
local glob_to_pattern = gblib.glob_to_pattern

---@type oslib_t
local oslib       = require("l3b.oslib")
local quoted_path = oslib.quoted_path

-- Deal with the fact that Windows and Unix use different path separators
local function unix_to_win(cmd)
  return first_of(gsub(cmd, "/", "\\"))
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

---Return a quoted absolute path from a relative one
---Due to chdir, path must exist and be accessible.
---@param path string
---@return string
local function absolute_path(path)
  local oldpwd = currentdir()
  local ok, msg = chdir(path)
  if ok then
    local result = currentdir()
    chdir(oldpwd)
    return quoted_path(gsub(result, "\\", "/"))
  end
  error(msg)
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

---Generate a table containing all names matching the given glob
---or all names if absent. The return value includes files,
---directories and whatever `lfs.dir` returns.
---Returns an empty list if there is no directory at the given path.
---@param dir_path string
---@param glob string|nil
---@return string_list_t
local function file_list(dir_path, glob)
  local files = {}
  local pattern
  if glob then
    pattern = glob_to_pattern(glob)
  end
  if directory_exists(dir_path) then
    for entry in lfs_dir(dir_path) do
      if pattern then
        if match(entry, pattern) then
          append(files, entry)
        end
      else
        if entry ~= "." and entry ~= ".." then
          append(files, entry)
        end
      end
    end
  end
  return files
end

---Return an iterator of the files and directories at path matching the given glob.
---@param path string
---@param glob string
---@return fun(): string
local function all_files(path, glob)
  return entries(file_list(path, glob))
end

---Does what filelist does, but can also glob subdirectories.
---In the returned table, the keys are paths relative to the given source path,
---the values are their counterparts relative to the current working directory.
---@param dir_path string
---@param glob string
---@return table<string, string>
local function tree(dir_path, glob)
  local function cropdots(path)
    return first_of(gsub(gsub(path, "^%./", ""), "/%./", "/"))
  end
  dir_path = cropdots(dir_path)
  glob = cropdots(glob)
  local function always_true()
    return true
  end
  local function is_dir(file)
    return attributes(file, "mode") == "directory"
  end
  local result = { ["."] = dir_path }
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

---Rename. Whether paths are properly escaped is another story...
---@param dir_path string
---@param source string the base name of the source
---@param dest string the base name of the destination
---@return boolean?  suc
---@return exitcode? exitcode
---@return integer?  code
local function rename(dir_path, source, dest)
  dir_path = dir_path .. "/"
  if os_type == "windows" then
    source = gsub(source, "^%./", "")
    dest = gsub(dest, "^%./", "")
    return execute("ren " .. unix_to_win(dir_path) .. source .. " " .. dest)
  else
    return execute("mv " .. dir_path .. source .. " " .. dir_path .. dest)
  end
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

---Remove the file with the given name at the given location.
---@param dir_path string
---@param name string
---@return integer
local function remove_file(dir_path, name)
  remove(dir_path .. "/" .. name)
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

---Remove a directory tree.
---@param dir string Must be properly escaped.
---@return boolean?  suc
---@return exitcode? exitcode
---@return integer?  code
local function remove_directory(dir)
  -- First, make sure it exists to avoid any errors
  if os_type == "windows" then
    make_directory(dir)
    return execute("rmdir /s /q " .. unix_to_win(dir))
  else
    return execute("rm -rf " .. dir)
  end
end

-- this is the map to export function symbols to the global space
local global_symbol_map = {
  abspath = absolute_path,
  direxists = directory_exists,
  fileexists = file_exists,
  locate = locate,
  filelist = file_list,
  ren = rename,
  cp = copy_tree,
  mkdir = make_directory,
  cleandir = make_clean_directory,
  -- tree = tree,
  rmfile = remove_file,
  rm = remove_tree,
  rmdir = remove_directory,
}

--[=[ Export function symbols ]=]
extend_with(_G, global_symbol_map)
-- [=[ ]=]

---@class fslib_t
---@field to_host function
---@field absolute_path function
---@field make_directory function
---@field directory_exists function
---@field file_exists function
---@field locate function
---@field file_list function
---@field all_files function
---@field tree function
---@field rename function
---@field copy_tree function
---@field make_clean_directory function
---@field remove_file function
---@field remove_tree function
---@field remove_directory function

return {
  global_symbol_map = global_symbol_map,
  to_host = to_host,
  absolute_path = absolute_path,
  make_directory = make_directory,
  directory_exists = directory_exists,
  file_exists = file_exists,
  locate = locate,
  file_list = file_list,
  all_files = all_files,
  tree = tree,
  rename = rename,
  copy_tree = copy_tree,
  make_clean_directory = make_clean_directory,
  remove_file = remove_file,
  remove_tree = remove_tree,
  remove_directory = remove_directory,
}
