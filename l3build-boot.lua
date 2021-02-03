--[[

File l3build-boot.lua Copyright (C) 2018-2020 The LaTeX Project

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

-- the purpose of the booting process is to setup
-- the `require` mechanism according to
-- http://www.lua.org/manual/5.3/manual.html#6.3
-- Due to the fact that `l3build` is not installed
-- where `lua` looks for, we must teach `lua` to do so.
-- Some attributes and methods are defined to be used
-- very early.

-- local safe guards and shortcuts

local currentdir  = lfs.currentdir
local kpse = kpse

-- module name
local _NAME = "l3build-boot"

-- reentrancy
local boot = package.loaded[_NAME]
if boot then
  return boot
end

-- base module attributes
boot = {
  _TYPE     = "module",
  _NAME     = _NAME,
  _VERSION  = "dev", -- the "dev" must be replaced by a release date
  PATH  = {}, -- unique key
  trace = {},
  trace_prompt = "**",
  trace_level = 0,
}

-- ensure that next `require("l3build-boot"")` returns `boot`.
-- because a `dofile` was certainly used at first because
-- lua cannot guess yet the location of the package.

package.loaded[_NAME] = boot

-- next code chunk may be used in many places.
-- it defines the locations where `require` should also look for `l3build` modules
boot.current_dir = currentdir()
kpse.set_program_name("kpsewhich")
boot.kpse_dir = kpse.lookup("l3build.lua"):match(".*/") -- either TDS or current directory
boot.launch_dir = arg[0]:match("^(.*/).*%.lua$") or "./"
-- Remark: What about l3b.kpse_dir == l3b.launch_dir possibility ?
-- Is there something to save, memory or time?

-- If we are looking for a `l3build` module, we want `require` to
-- look into the `launch_dir`, then `kpse_dir` and after that standard locations.
-- If we are looking for other modules, we want `require` to
-- look into the initial currentdir, the `launch_dir`, then `kpse_dir` and after that other standard locations.
-- When in unit testing mode, supplemental trials may be necessary before `kpse_dir`,
-- hence the `more_search_path` method.

---Load the module with the given name at the given path.
---To be used only by the searcher below.
---When an object, a module will store its own path.
---@param name string
---@param path string
---@return table|boolean
local function loader(name, path)
  local ans = dofile(path)
  if type(ans) == "table" then
    -- Set the path of the given module.
    ans[boot.PATH] = path
  end
  package.loaded[name] = ans
  return ans
end

---Searcher to be inserted in the searchers list.
---@param name string
---@return function
---@return string
local function searcher(name)
  boot.trace_show(
    "require",
    "module required: " .. name
  )
  local long = name:match("^.*%.lua$") or name .. ".lua"
  local path
  if name:match("^l3build") then
    path = package.searchpath(
      "?", boot.launch_dir .. long
    )  or boot.parent_search_path(
      name, boot.current_dir
    )  or package.searchpath(
      "?", boot.kpse_dir .. long
    )
  else
    path = package.searchpath(
      "?", boot.current_dir .. long
    )  or package.searchpath(
      "?", boot.launch_dir .. long
    )  or boot.more_search_path(
      name
    )  or package.searchpath(
      "?", boot.kpse_dir .. long
    )
  end
  if path then
    boot.trace_show("require", "module found at: " .. path)
    return loader, path
  end
  return "\n        [l3build searcher] file not found: '" .. name .. "'"
end

-- We insert a new searcher after the first default searcher.
table.insert(package.searchers, 2, searcher)

-- from now on, 

---Scans the parents of the current directory.
---@param name string
---@return string or nil + an error message
function boot.parent_search_path(name, dir)
  local pattern = name:match("%.lua$") and "?" or "?.lua"
  for _ in boot.current_dir:gmatch(".*/") do
    dir = dir .. "../"
    local path = package.searchpath(dir .. name, pattern)
    if path then
      return path
    end
  end
end

---Hook to find more search files.
---@name l3b.more_search_path
---@param name string
---@return string? the full path of the module when found, nil otherwise
-- For example, in upwind caller do
--[[```
l3b.more_search_path = function (name)
  return l3b.parent_search_path(name, boot.current_dir)
end
```]]
function boot.more_search_path(name) end

-- Utility functions, do not belong here but lays here for the moment

---Goody to show some execution trace.
---@param key string optional when level is provided, print only when `3b.trace[key]` is true
---@param level number optional when key is provided, print only when the trace level is greater than this level
---@param fmt string
---@param nil ...
function boot.trace_show(key, level, fmt, ...)
  local next_arg
  if type(key) == "number" then
    key, level, fmt, next_arg = nil, key, level, fmt
    if level > boot.trace_level then
      print(boot.trace_prompt .. fmt:format(next_arg, ...))
      return
    end
  end
  if type(level) == "number" then
    if level > boot.trace_level or boot.trace[key] then
      print(boot.trace_prompt .. fmt:format(...))
    end
  else
    level, fmt, next_arg = nil, level, fmt
    if boot.trace[key] then
      print(boot.trace_prompt .. fmt:format(next_arg, ...))
    end
  end
end

---Consumes elements 1, 2, ... k of the given table.
---Element 0 is untouched
---Used for example when testing the real argument parsing.
---Whereas a standard call may be `l3build tag "foo"`,
---a test call might be `l3build --test --unit bla tag foo`
---In the second call, 3 arguments are consumed: --test --unit and bla
---in order to have the global arg like in the first call.
---In that test context we have consumed all the heading arguments
---that are only dedicated to testing.
---@param t table a sequence
---@param k number
---@return table t the modified table which is still a sequence
function boot.shift_left(t, k)
  if k>0 then
    for i = 1, #t do
      t[i] = t[i+k]
    end
    -- instead of table.remove(t, 1) k times
  end
  return t
end

return boot