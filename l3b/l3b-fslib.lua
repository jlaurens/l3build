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
local os_rename   = os.rename

local push        = table.insert
local pop         = table.remove
local tbl_unpack  = table.unpack

local lfs         = require("lfs")
local attributes  = lfs.attributes
local get_current_directory     = lfs.currentdir
local change_current_directory  = lfs.chdir
local get_directory_content     = lfs.dir

---@type utlib_t
local utlib       = require("l3b-utillib")
local is_error    = utlib.is_error
local entries     = utlib.entries
local first_of    = utlib.first_of

---@type pathlib_t
local pathlib       = require("l3b-pathlib")
local dir_base      = pathlib.dir_base
local base_name     = pathlib.base_name
local path_matcher  = pathlib.path_matcher

---@type oslib_t
local oslib       = require("l3b-oslib")
local quoted_path = oslib.quoted_path

-- implementation

---@class fslib_vars_t
---@field public debug          flags_t
---@field public poor_man_rename boolean

---@type fslib_vars_t
local Vars = setmetatable({
  debug = {},
  poor_man_rename = false,
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
  return first_of(cmd:gsub("/", "\\"))
end

---Convert to host directory separator
---@param cmd string
---@return string
local function to_host(cmd)
  assert(cmd, "missing `to_host` cmd")
  if os_type == "windows" then
    return unix_to_win(cmd)
  end
  return cmd
end

---Make a directory at the given path
---@function make_directory
---@param path string
---@return error_level_n @code
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
---@function directory_exists
---@param path string
---@return boolean
local function directory_exists(path)
  if not path and not _ENV.during_unit_testing then
    print(debug.traceback())
  end
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
---@function file_exists
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

---@type string[]
local cwd_list = {}

---Save the current directory to the top of the
---current directory stack then change the
---current directory to the given one.
---@function push_current_directory
---@param dir string @path of the directory to switch to
---@return boolean @ok true means success
---@return string @msg error message
local function push_current_directory(dir)
  if not directory_exists(dir) and not _ENV.during_unit_testing then
    print(debug.traceback())
  end
  local cwd = get_current_directory()
  local ok, msg = change_current_directory(dir)
  if ok then
    push(cwd_list, cwd)
  end
  return ok, msg
end

---Remove the top entry from the directory stack,
---then change back current directory to this removed value and return it.
---@function pop_current_directory
---@return string|nil @dir the new current directory on success, nil on error
---@return nil|string @msg nil on success, error message on error
local function pop_current_directory()
  local dir = pop(cwd_list)
  if not dir and not _ENV.during_unit_testing then
    print(debug.traceback())
  end
  assert(dir ~= nil)
  if dir == nil then
    error("THIS IS AN ERROR")
  end
  local ok, msg = change_current_directory(dir)
  return ok and dir or nil, msg
end

---Push the current directory, runs `f` and pop it back.
---returns true followed by whatever f returns
---packed in one array. Clients will unpack the result before use.
---or false followed by an error message.
---@function push_pop_current_directory
---@param dir string @path of the directory to switch to
---@param f function @function to execute
---@vararg any       arguments passed to the function
---@return boolean @ok true means success
---@return string|table @msg error message or the packed result of f
local function push_pop_current_directory(dir, f, ...)
  push_current_directory(dir)
  local packed = { pcall(f, ...) }
  pop_current_directory()
  if packed[1] then
    return true, { tbl_unpack(packed, 2) }
  end
  return false, packed[2]
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
---to the current directory when not already absolute.
---If `is_current` is false, the given path is relative
---to the working directory when not already absolute.
---@see `set_working_directory`.
---@param path string
---@param is_current boolean @whether `path` is relative to the current directory
---@return string
local function absolute_path(path, is_current)
  if Vars.debug.absolute_path then
    print("DEBUG absolute_path", path, is_current)
  end
  local dir, base = dir_base(path)
  if Vars.debug.absolute_path then
    print("DEBUG absolute_path dir, base", dir, base)
  end
  if not is_current then
    push_current_directory(Vars.working_directory)
  end
  local result
  local ok, msg = push_current_directory(dir)
  if ok then
    result = get_current_directory()
    pop_current_directory()
  end
  if Vars.debug.absolute_path then
    print("DEBUG absolute_path result", result)
  end
  if not is_current then
    pop_current_directory()
  end
  if ok then
    result = result:gsub("\\", "/")
    local candidate = result / base
    if Vars.debug.absolute_path then
      print("DEBUG absolute_path candidate", candidate)
    end
    return candidate
  end
  error(msg)
end

---Return a quoted absolute path from a relative one
---Due to chdir, path must exist and be accessible.
---@function quoted_absolute_path
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
---@param dirs  string[]
---@param names string[]
---@return string
local function locate(dirs, names)
  for i in entries(dirs) do
    for j in entries(names) do
      local path = i / j
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
---@function file_list
---@param dir_path  string
---@param glob      string|nil
---@return string[]
local function file_list(dir_path, glob)
  local files = {}
  if directory_exists(dir_path) then
    local matcher = path_matcher(glob)
    if matcher then
      local ok, msg = pcall(function () get_directory_content(dir_path) end)
      if not ok then
        print(debug.traceback())
      end
      for entry in get_directory_content(dir_path) do
        if matcher(entry) then
          push(files, entry)
        end
      end
    else
      for entry in get_directory_content(dir_path) do
        if entry ~= "." and entry ~= ".." then
          push(files, entry)
        end
      end
    end
  end
  return files
end

---@alias string_iterator_f fun(): string|nil

---@class glob_exclude_kv_t
---@field public glob string
---@field public exclude exclude_f

---Return an iterator of the files and directories at path matching the given glob.
---If there is no directory at the given path, a void iterator is returned
---@function all_names
---@param path  string
---@param glob  string
---@return string_iterator_f
local function all_names(path, glob)
  return directory_exists(path)
    and entries(file_list(path, glob))
    or  function () end
end

---@alias string_exclude_f  fun(value: string): boolean

local tree_excluder = function (_name)
  return false
end

---Set the given function as tree excluder.
---Can be used to exclude the build directory.
---@function set_tree_excluder
---@param f string_exclude_f
local function set_tree_excluder(f)
  tree_excluder = f
end

---@class tree_entry_t
---@field public src string @path relative to the source directory
---@field public wrk string @path counterpart relative to the current working directory
---@field private is_directory boolean

---Tree entry enumerator.
---@param dir_path  string
---@param glob      string
---@param kv        iterator_kv_t
---@return fun(): tree_entry_t|nil
local function tree(dir_path, glob, kv)
  if Vars.debug.tree then
    print("DEBUG tree", "<"..dir_path..">", "<"..glob..">")
  end
  dir_path = pathlib.sanitize(dir_path)
  glob = pathlib.sanitize(glob, true)
  if Vars.debug.tree then
    print("DEBUG tree", "<"..dir_path..">", "<"..glob..">")
  end
  local function always_true()
    return true
  end
  local function is_dir(file)
    return attributes(file, "mode") == "directory"
  end
  ---@type tree_entry_t[]
  local result = { {
    src = ".",
    wrk = dir_path,
    is_directory = true, -- do not copy this at first
  } }
  for glob_part, sep in glob:gmatch("([^/]+)(/?)/*") do
    if Vars.debug.tree then
      print("DEBUG glob:gmatch", glob_part, sep)
    end
    local accept = sep == "/" and is_dir or always_true
    ---Feeds the given table according to `glob_part`
    ---@param p tree_entry_t @path counterpart relative to the current working directory
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
            src = p.src / file,
            wrk = p.wrk / file,
          }
          if not tree_excluder(pp.wrk) then
            if accept(pp.wrk) then
              if Vars.debug.tree then
                print("DEBUG tree fill ACCEPTED", pp.src, pp.wrk, p.src, p.wrk, file)
              end
              pp.is_directoy = is_dir(pp.wrk)
              push(table, pp)
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
      repeat
        local p = result[i]
        i = i + 1
        if not p then
          break
        end
        push(new_result, p)
        fill(p, result)
      until false
    else
      for p in entries(result) do
        fill(p, new_result)
      end
    end
    result = new_result
  end
  return entries(result, kv)
end

---Rename. Whether paths are properly escaped is another story...
---Implementation detail: For what reason `os.rename` is not used ?
---@param dir_path string
---@param source string @the base name of the source
---@param dest string @the base name of the destination
---@return error_level_n  @ 0 on success, 1 on failure
local function rename(dir_path, source, dest)
  if Vars.poor_man_rename then
    if os_type == "windows" then
      -- BEWARE: os.execute return value is not lua's original one!
      return execute("ren " .. unix_to_win(dir_path / source) .. " " .. base_name(dest) )
    else
      return execute("mv " .. dir_path / source .. " " .. dir_path / dest)
    end
  end
  source  = dir_path / source
  dest    = dir_path / dest
  local ok, msg = os_rename(source, dest)
  if not ok then
    print(("rename %s to %s: %s"):format(source, dest, msg))
  end
  return ok and 0 or 1
end

---Private function.
---@param dest string
---@param p_src any
---@param p_wrk string
---@return error_level_n
local function copy_core(dest, p_src, p_wrk)
  -- p_src was a path relative to some `source` whereas
  -- p_wrk was the counterpart relative to the current working directory
  -- when not absolute...
  local dir, base = dir_base(p_src)
  dest = dest / dir
  p_src = base
  local error_level = make_directory(dest)
  if error_level > 0 then
    return error_level
  end
  local cmd
  if os_type == "windows" then
    if attributes(p_wrk, "mode") == "directory" then
      cmd = 'xcopy /y /e /i "' .. unix_to_win(p_wrk) .. '" "'
            .. unix_to_win(dest / p_src) .. '" > nul'
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
  return execute(cmd)
end

---@class copy_name_kv_t @copy_file key/value arguments
---@field public name    string
---@field public source  string
---@field public dest    string

---Copy files 'quietly'.
---@function copy_file
---@param name copy_name_kv_t|string @base name of kv arguments
---@param source? string @path of the source directory, required when name is not a table
---@param dest? string @path of the destination directory, required when name is not a table
---@return error_level_n
local function copy_file(name, source, dest)
  if type(name) == "table" then
    ---@type copy_name_kv_t
    local kv = name
    name, source, dest = kv.name, kv.source, kv.dest
  end
  local p_src = name
  local p_wrk = source / name
  return copy_core(dest, p_src, p_wrk)
end

---Copy files 'quietly'.
---@param glob    string_iterator_f|string[]|string
---@param source  string
---@param dest    string
---@return error_level_n
local function copy_tree(glob, source, dest)
  if Vars.debug.copy_tree then
    print("DEBUG copy_tree", glob, source, dest)
  end
  local error_level = 0
  local function helper(g)
    for p in tree(source, g) do
      error_level = copy_core(dest, p.src, p.wrk)
      if is_error(error_level) then
        return
      end
    end
  end
  if type(glob) == "function" then
    -- @type string[]
    if Vars.debug.copy_tree then
      print("DEBUG copy_tree function iterator")
    end
    for g in glob do
      if Vars.debug.copy_tree then
        print("DEBUG copy_tree", "<"..g..">")
      end
      helper(g)
      if is_error(error_level) then
        return error_level
      end
    end
  elseif type(glob) == "table" then
  -- @type string[]
    for g in entries(glob) do
      helper(g)
      if is_error(error_level) then
        return error_level
      end
    end
  else
    helper(glob)
  end
  return error_level
end

---Remove the file or void directory with the given name at the given location.
---@param dir_path string
---@param name string
---@return error_level_n
local function remove_name(dir_path, name)
  remove(dir_path / name)
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
  return 0
end

---For cleaning out a directory, which also ensures that it exists
---Only files are cleaned.
---The best way to completely clean out a directory with all its contents
---is to remove then recreate it.
---@param path string
---@return error_level_n
local function make_clean_directory(path)
  local error_level = make_directory(path)
  if is_error(error_level) then
    return error_level
  end
  return remove_tree(path, "**")
end

---Remove a directory tree.
---@param path string @Must be properly escaped.
---@return error_level_n  @code
local function remove_directory(path)
  if os_type == "windows" then
    -- First, make sure it exists to avoid any errors
    -- this is a weird coding style
    make_directory(path)
    return execute("rmdir /s /q " .. unix_to_win(path))
  else
    return execute("rm -rf " .. path)
  end
end

---@class fslib_t
---@field public Vars                       fslib_vars_t
---@field public to_host                    fun(cmd: string):  string
---@field public absolute_path              fun(path: string): string
---@field public quoted_absolute_path       fun(path: string): string
---@field public make_directory             fun(path: string): boolean, exitcode, integer
---@field public directory_exists           fun(path: string): boolean
---@field public file_exists                fun(path: string): boolean
---@field public locate                     fun(dirs: string[], names: string[]): string
---@field public file_list                  fun(dir_path: string, glob: string|nil): string[]
---@field public all_names                  fun(path: string, glob: string): fun(): string
---@field public set_tree_excluder          fun(f: string_exclude_f)
---@field public tree                       fun(dir_path: string, glob: string): tree_entry_t
---@field public rename                     fun(dir_path: string, source: string, dest: string): integer
---@field public copy_file                  fun(file: string, source: string, dest: string): integer
---@field public copy_tree                  fun(glob: string, source: string, dest: string): integer
---@field public make_clean_directory       fun(path: string): integer
---@field public remove_name                fun(dir_path: string, name: string): integer
---@field public remove_tree                fun(source: string, glob: string): integer
---@field public remove_directory           fun(path: string): boolean?, exitcode?, integer?
---@field public set_working_directory      fun(path: string)
---@field public get_current_directory      fun(): string
---@field public change_current_directory   fun(dir: string) raises if dir does not exist
---@field public push_current_directory     fun(dir: string): string
---@field public pop_current_directory      fun(): string
---@field public push_pop_current_directory fun(dir:string, f: function, ...): boolean, any

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
  tree2                 = tree,
  rename                = rename,
  copy_file             = copy_file,
  copy_tree             = copy_tree,
  make_clean_directory  = make_clean_directory,
  remove_name           = remove_name,
  remove_tree           = remove_tree,
  remove_directory      = remove_directory,
  set_working_directory       = set_working_directory,
  get_current_directory       = get_current_directory,
  change_current_directory    = change_current_directory,
  push_current_directory      = push_current_directory,
  pop_current_directory       = pop_current_directory,
  push_pop_current_directory  = push_pop_current_directory,
},
---@class __fslib_t
---@field private unix_to_win fun(s: string): string
---@field private cwd_list string[]
---@field private copy_core fun(dest: string, p_src: string, p_wrk: string): integer
_ENV.during_unit_testing and {
  unix_to_win = unix_to_win,
  cwd_list    = cwd_list,
  copy_core   = copy_core,
}
