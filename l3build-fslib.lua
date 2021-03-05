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
local all_names             = fslib.all_names
local tree                  = fslib.tree
local rename                = fslib.rename
local copy_tree             = fslib.copy_tree
local make_clean_directory  = fslib.make_clean_directory
local remove_name           = fslib.remove_name
local remove_tree           = fslib.remove_tree
local remove_directory      = fslib.remove_directory
--]=]
local pairs            = pairs

local lfs              = require("lfs")
local attributes       = lfs.attributes
local current_dir      = lfs.currentdir
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
local to_glob_match = gblib.to_glob_match

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

---Make a directory at the given path
---@param path string
---@return boolean? suc
---@return exitcode? "exit"|"signal"
---@return integer? code
local function make_directory(path)
  if os_type == "windows" then
    -- Windows (with the extensions) will automatically make directory trees
    -- but issues a warning if the dir already exists: avoid by including a test
    path = unix_to_win(path)
    return execute(
      "if not exist "  .. path .. "\\nul " .. "mkdir " .. path
    )
  else
    return execute("mkdir -p " .. path)
  end
end

---Return a quoted absolute path from a relative one
---Due to chdir, path must exist and be accessible.
---@param path string
---@return string
local function absolute_path(path)
  local oldpwd = current_dir()
  local ok, msg = chdir(path)
  if ok then
    local result = current_dir()
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
---@param dirs  string_list_t
---@param names string_list_t
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
  if directory_exists(dir_path) then
    local glob_match = to_glob_match(glob)
    if glob_match then
      for entry in lfs_dir(dir_path) do
        if glob_match(entry) then
          append(files, entry)
        end
      end
    else
      for entry in lfs_dir(dir_path) do
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
local function all_names(path, glob)
  return entries(file_list(path, glob))
end

local tree_excluder = function (name) return false end

---Set the given function as tree excluder.
---Can be used to exclude the build directory.
---@param f fun(path_wrk: string): boolean
local function set_tree_excluder(f)
  tree_excluder = f
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
    ---@param p_wrk string path counterpart relative to the current working directory
    ---@param table table
    local function fill(p_src, p_wrk, table)
      for file in all_names(p_wrk, glob_part) do
        if file ~= "." and file ~= ".." then
          local p_cwd_file = p_wrk .. "/" .. file
          if not tree_excluder(p_cwd_file) then
            local p_src_file = p_src .. "/" .. file
            if accept(p_cwd_file) then
              table[p_src_file] = p_cwd_file
            end
          end
        end
      end
    end
    local new_result = {}
    if glob_part == "**" then
      while true do
        local p_src, p_wrk = next(result)
        if not p_src then
          break
        end
        result[p_src] = nil
        new_result[p_src] = p_wrk
        fill(p_src, p_wrk, result)
      end
    else
      for p_src, p_wrk in pairs(result) do
        fill(p_src, p_wrk, new_result)
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

local function copy_core(dest, p_src, p_wrk)
  local error_level
      -- p_src is a path relative to `source` whereas
    -- p_wrk is the counterpart relative to the current working directory
    if os_type == "windows" then
      if attributes(p_wrk, "mode") == "directory" then
        error_level = execute(
          'xcopy /y /e /i "' .. unix_to_win(p_wrk) .. '" "'
             .. unix_to_win(dest .. '/' .. p_src) .. '" > nul'
        )
      else
        error_level = execute(
          'xcopy /y "' .. unix_to_win(p_wrk) .. '" "'
             .. unix_to_win(dest .. '/') .. '" > nul'
        )
      end
    else
      error_level = execute("cp -RLf '" .. p_wrk .. "' '" .. dest .. "'")
    end
    if error_level ~=0 then
      return error_level
    end

end

---@class copy_name_kv -- copy_name key/value arguments
---@field name    string
---@field source  string
---@field dest    string

---Copy files 'quietly'.
---@param name string|copy_name_kv base name of kv arguments
---@param source? string path of the source directory, required when name is not a table
---@param dest? string path of the destination directory, required when name is not a table
---@return error_level_t
local function copy_name(name, source, dest)
  if type(name) == "table" then
    name, source, dest = name.name, name.source, name.dest
  end
  local p_src = source  .."/".. name
  local p_wrk = dest    .."/".. name
  return copy_core(dest, p_src, p_wrk)
end

---Copy files 'quietly'.
---@param glob string
---@param source string
---@param dest string
---@return integer
local function copy_tree(glob, source, dest)
  local error_level
  for p_src, p_wrk in pairs(tree(source, glob)) do
    error_level = copy_core(dest, p_src, p_wrk)
    if error_level ~=0 then
      return error_level
    end
  end
  return 0
end

---Remove the file or void directory with the given name at the given location.
---@param dir_path string
---@param name string
---@return error_level_t
local function remove_name(dir_path, name)
  remove(dir_path .. "/" .. name)
  -- TODO: Is it an error to remove a file that does not exist?
  return 0
end

---Remove the files matching glob starting at source
---Empties directories but do not remove them.
---@param source string
---@param glob string
---@return error_level_t
local function remove_tree(source, glob)
  for i in keys(tree(source, glob)) do
    remove_name(source, i)
  end
  -- os.remove doesn't give a sensible errorlevel
  return 0
end

---For cleaning out a directory, which also ensures that it exists
---@param path string
---@return error_level_t
local function make_clean_directory(path)
  local error_level = make_directory(path)
  if error_level ~= 0 then
    return error_level
  end
  return remove_tree(path, "**")
end

---Remove a directory tree.
---@param path string Must be properly escaped.
---@return boolean?  suc
---@return exitcode? exitcode
---@return integer?  code
local function remove_directory(path)
  -- First, make sure it exists to avoid any errors
  if os_type == "windows" then
    make_directory(path)
    return execute("rmdir /s /q " .. unix_to_win(path))
  else
    return execute("rm -rf " .. path)
  end
end

---@class fslib_t
---@field to_host           fun(cmd: string):   string
---@field absolute_path     fun(path: string):  string
---@field make_directory    fun(path: string):  boolean, exitcode, integer
---@field directory_exists  fun(path: string): boolean
---@field file_exists       fun(path: string): boolean
---@field locate      fun(dirs: string_list_t, names: string_list_t): string
---@field file_list   fun(dir_path: string, glob: string|nil): string_list_t
---@field all_names   fun(path: string, glob: string): fun(): string
---@field set_tree_excluder fun(f: fun(path_wrk: string): boolean)
---@field tree        fun(dir_path: string, glob: string): table<string, string>)
---@field rename      fun(dir_path: string, source: string, dest: string):  boolean?, exitcode?, integer?
---@field copy_name   fun(file: string, source: string, dest: string): integer
---@field copy_tree   fun(glob: string, source: string, dest: string): integer
---@field make_clean_directory fun(path: string): integer
---@field remove_name fun(dir_path: string, name: string): integer
---@field remove_tree fun(source: string, glob: string): integer
---@field remove_directory fun(path: string): boolean?, exitcode?, integer?

return {
  to_host = to_host,
  absolute_path = absolute_path,
  make_directory = make_directory,
  directory_exists = directory_exists,
  file_exists = file_exists,
  locate = locate,
  file_list = file_list,
  all_names = all_names,
  set_tree_excluder = set_tree_excluder,
  tree = tree,
  rename = rename,
  copy_name = copy_name,
  copy_tree = copy_tree,
  make_clean_directory = make_clean_directory,
  remove_name = remove_name,
  remove_tree = remove_tree,
  remove_directory = remove_directory,
}
