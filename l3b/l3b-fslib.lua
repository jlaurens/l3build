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

local execute     = os.execute
local remove      = os.remove
local os_type     = os["type"]

local append      = table.insert
local unappend    = table.remove

local lfs         = require("lfs")
local attributes  = lfs.attributes
local get_current_directory     = lfs.currentdir
local change_current_directory  = lfs.chdir
local get_directory_content     = lfs.dir

---@type utlib_t
local utlib       = require("l3b-utillib")
local entries     = utlib.entries
local first_of    = utlib.first_of

---@type wklib_t
local wklib           = require("l3b-walklib")
local dir_base        = wklib.dir_base

---@type gblib_t
local gblib           = require("l3b-globlib")
local to_glob_match = gblib.to_glob_match

---@type oslib_t
local oslib       = require("l3b-oslib")
local quoted_path = oslib.quoted_path

-- implementation

---@class fslib_vars_t
---@field debug     flag_table_t

---@type fslib_vars_t
local Vars = setmetatable({
  debug = {}
}, {
  __index = function (t, k)
    if k == "working_directory" then
      print(debug.traceback())
      error("Missing set_working_directory.", 2)
    end
  end
})
-- Deal with the fact that Windows and Unix use different path separators
local function unix_to_win(cmd)
  return first_of(cmd:gsub( "/", "\\"))
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
  if not path then
    print(debug.traceback())
    error("MISSING PATH")
  end
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

---Whether there is a directory at the given path
---@param path string
---@return boolean
local function directory_exists(path)
  return attributes(path, "mode") == "directory"
--[===[ Original implementation
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
--]===]
end

---Whether there is a file at the given path
---@param path string
---@return boolean
local function file_exists(path)
  return attributes(path, "mode") == "file"
--[===[ Original implementation
  local f = open(file, "r")
  if f ~= nil then
    f:close()
    return true
  else
    return false -- also file exits and is not readable
  end
--]===]
end

--[==[ Current directory business ]==]

---@type string_list_t
local cwd_list = {}

---Save the current directory to the top of the
---current directory stack then change the
---current directory to the given one.
---@param dir string path of the directory to switch to
---@return boolean ok true means success
---@return string msg error message
local function push_current_directory(dir)
  if not directory_exists(dir) then
    print(debug.traceback())
  end
  assert(directory_exists(dir), "No directory at ".. tostring(dir))
  append(cwd_list, get_current_directory())
  return change_current_directory(dir)
end

---Remove the top entry from the directory stack,
---then change back current directory to this removed value and return it.
---@return string|nil dir the new current directory on success, nil on error
---@return nil|string msg nil on success, error message on error
local function pop_current_directory()
  local dir = unappend(cwd_list)
  if not dir then
    print(debug.traceback())
  end
  assert(dir)
  local ok, msg = change_current_directory(dir)
  return ok and dir or nil, msg
end

---Set the working directory. As soon as possible
---@param dir string
local function set_working_directory(dir)
  assert(not dir:match("^%."),
    "Absolute path required in set_working_directory, got "
    .. tostring(dir)
  )
  Vars.working_directory = dir
end

---Return an absolute path from a relative one.
---Due to chdir, path must exist and be accessible.
---If `is_current` is true, the given path is relative
---to the current directory when not absolute.
---If `is_current` is false, the given path is relative
---to the working directory when not absolute.
---@see `set_working_directory`.
---@param path string
---@param is_current boolean whether `path` is relative to the current directory
---@return string
local function absolute_path(path, is_current)
  local dir, base = dir_base(path)
  if not is_current then
    push_current_directory(Vars.working_directory)
  end
  local result
  local ok, msg = push_current_directory(dir)
  if ok then
    result = get_current_directory()
    pop_current_directory()
  end
  if not is_current then
    pop_current_directory()
  end
  if ok then
    result = result:gsub("\\", "/")
    local candidate = result .."/".. base
    if attributes(candidate, "mode") then
      return candidate
    end
    return path
  end
  error(msg)
end

---Return a quoted absolute path from a relative one
---Due to chdir, path must exist and be accessible.
---@param path string
---@return string
local function quoted_absolute_path(path)
  local result, msg = absolute_path(path)
  if result then
    return quoted_path(result)
  end
  return result, msg
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
      for entry in get_directory_content(dir_path) do
        if glob_match(entry) then
          append(files, entry)
        end
      end
    else
      for entry in get_directory_content(dir_path) do
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

---@class tree_entry_t
---@field src string path relative to the source directory
---@field wrk string path counterpart relative to the current working directory

---Does what filelist does, but can also glob subdirectories.
---In the returned table, the keys are paths relative to the given source path,
---the values are their counterparts relative to the current working directory.
---@param dir_path string
---@param glob string
---@return fun(): tree_entry_t|nil
local function tree(dir_path, glob)
  if Vars.debug.tree then
    print("DEBUG tree", dir_path, glob)
  end
  local function cropdots(path)
    return first_of(path:gsub( "^%./", ""):gsub("/%./", "/"))
  end
  dir_path = cropdots(dir_path)
  glob = cropdots(glob)
  local function always_true()
    return true
  end
  local function is_dir(file)
    return attributes(file, "mode") == "directory"
  end
  ---@type table<integer, tree_entry_t>
  local result = { {
    src = ".",
    wrk = dir_path,
  } }
  for glob_part, sep in glob:gmatch("([^/]+)(/?)/*") do
    local accept = sep == "/" and is_dir or always_true
    ---Feeds the given table according to `glob_part`
    ---@param p tree_entry_t path counterpart relative to the current working directory
    ---@param table table
    local function fill(p, table)
      if Vars.debug.tree then
        print("DEBUG tree fill", p.src, p.wrk)
      end
      for file in all_names(p.wrk, glob_part) do
        if Vars.debug.tree then
          print("DEBUG tree fill all_names", file)
        end
        if file ~= "." and file ~= ".." then
          local pp = {
            src = p.src .. "/" .. file,
            wrk = p.wrk .. "/" .. file,
          }
          if not tree_excluder(pp.wrk) then
            if accept(pp.wrk) then
              if Vars.debug.tree then
                print("DEBUG tree fill ACCEPTED", pp.src, pp.wrk)
              end
              append(table, pp)
            else
              if Vars.debug.tree then
                print("DEBUG tree fill REFUSED", pp.src, pp.wrk)
              end
            end
          else
            if Vars.debug.tree then
              print("DEBUG tree fill EXCLUDED", pp.src, pp.wrk)
            end
          end
        end
      end
    end
    local new_result = {}
    if glob_part == "**" then
      local i = 1
      repeat -- forever
        local p = result[i]
        i = i + 1
        if not p then
          break
        end
        append(new_result, p)
        fill(p, result)
      until false
    else
      for p in entries(result) do
        fill(p, new_result)
      end
    end
    result = new_result
  end
  return entries(result)
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
    source = source:gsub( "^%./", "")
    dest = dest:gsub( "^%./", "")
    return execute("ren " .. unix_to_win(dir_path) .. source .. " " .. dest)
  else
    return execute("mv " .. dir_path .. source .. " " .. dir_path .. dest)
  end
end

---Private function.
---@param dest string
---@param p_src any
---@param p_wrk string
---@return integer
local function copy_core(dest, p_src, p_wrk)
  -- p_src was a path relative to `source` whereas
  -- p_wrk was the counterpart relative to the current working directory
  local dir, base = dir_base(p_src)
  dest = dest ..'/'.. dir
  p_src = base
  make_directory(dest)
  local cmd
  if os_type == "windows" then
    if attributes(p_wrk, "mode") == "directory" then
      cmd = 'xcopy /y /e /i "' .. unix_to_win(p_wrk) .. '" "'
            .. unix_to_win(dest .. '/' .. p_src) .. '" > nul'
    else
      cmd = 'xcopy /y "' .. unix_to_win(p_wrk) .. '" "'
            .. unix_to_win(dest .. '/') .. '" > nul'
    end
  else
    cmd = "cp -RLf '" .. p_wrk .. "' '" .. dest .. "'"
  end
  if Vars.debug.copy_core then
    --print("make_directory '" .. dest .. "/'", directory_exists(dest))
    print("DEBUG: " .. cmd)
  end
return execute(cmd) and 0 or 1
end

---@class copy_name_kv -- copy_file key/value arguments
---@field name    string
---@field source  string
---@field dest    string

---Copy files 'quietly'.
---@param name copy_name_kv|string base name of kv arguments
---@param source? string path of the source directory, required when name is not a table
---@param dest? string path of the destination directory, required when name is not a table
---@return error_level_n
local function copy_file(name, source, dest)
  if type(name) == "table" then
    ---@type copy_name_kv
    local kv = name
    name, source, dest = kv.name, kv.source, kv.dest
  end
  local p_src = name
  local p_wrk = source .."/".. name
  return copy_core(dest, p_src, p_wrk)
end

---Copy files 'quietly'.
---@param glob string
---@param source string
---@param dest string
---@return integer
local function copy_tree(glob, source, dest)
  local error_level
  for p in tree(source, glob) do
    error_level = copy_core(dest, p.src, p.wrk)
    if error_level ~= 0 then
      return error_level
    end
  end
  return 0
end

---Remove the file or void directory with the given name at the given location.
---@param dir_path string
---@param name string
---@return error_level_n
local function remove_name(dir_path, name)
  remove(dir_path .. "/" .. name)
  -- TODO: Is it an error to remove a file that does not exist?
  return 0
end

---Remove the files matching glob starting at source
---Empties directories but do not remove them.
---@param source string
---@param glob string
---@return error_level_n
local function remove_tree(source, glob)
  for entry in tree(source, glob) do
    remove_name(source, entry.src)
  end
  -- os.remove doesn't give a sensible errorlevel
  return 0
end

---For cleaning out a directory, which also ensures that it exists
---@param path string
---@return error_level_n
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
---@field Vars              fslib_vars_t
---@field to_host           fun(cmd: string):   string
---@field absolute_path     fun(path: string):  string
---@field quoted_absolute_path fun(path: string):  string
---@field make_directory    fun(path: string):  boolean, exitcode, integer
---@field directory_exists  fun(path: string): boolean
---@field file_exists       fun(path: string): boolean
---@field locate      fun(dirs: string_list_t, names: string_list_t): string
---@field file_list   fun(dir_path: string, glob: string|nil): string_list_t
---@field all_names   fun(path: string, glob: string): fun(): string
---@field set_tree_excluder fun(f: fun(path_wrk: string): boolean)
---@field tree        fun(dir_path: string, glob: string): table<string, string>)
---@field rename      fun(dir_path: string, source: string, dest: string):  boolean?, exitcode?, integer?
---@field copy_file   fun(file: string, source: string, dest: string): integer
---@field copy_tree   fun(glob: string, source: string, dest: string): integer
---@field make_clean_directory      fun(path: string): integer
---@field remove_name fun(dir_path: string, name: string): integer
---@field remove_tree fun(source: string, glob: string): integer
---@field remove_directory          fun(path: string): boolean?, exitcode?, integer?
---@field set_working_directory     fun(path: string)
---@field get_current_directory     fun(): string
---@field change_current_directory  fun(dir: string) raises if dir does not exist
---@field push_current_directory    fun(dir: string): string
---@field pop_current_directory     fun(): string

return {
  Vars                  = Vars,
  to_host               = to_host,
  absolute_path         = absolute_path,
  quoted_absolute_path  = quoted_absolute_path,
  make_directory        = make_directory,
  directory_exists      = directory_exists,
  file_exists           = file_exists,
  locate                = locate,
  file_list             = file_list,
  all_names             = all_names,
  set_tree_excluder     = set_tree_excluder,
  tree                  = tree,
  rename                = rename,
  copy_file             = copy_file,
  copy_tree             = copy_tree,
  make_clean_directory  = make_clean_directory,
  remove_name           = remove_name,
  remove_tree           = remove_tree,
  remove_directory      = remove_directory,
  set_working_directory     = set_working_directory,
  get_current_directory     = get_current_directory,
  change_current_directory  = change_current_directory,
  push_current_directory    = push_current_directory,
  pop_current_directory     = pop_current_directory,
}