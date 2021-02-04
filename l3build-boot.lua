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
-- This makes sense if we do not know in advance where
-- modules and scripts are installed, which is the case when
-- 1) l3build itself is being developed
-- 2) we require modules that are not installed, for example while testing
-- Some attributes and methods are defined to be used
-- very early.

-- local safe guards and shortcuts

local currentdir  = require("lfs").currentdir
local kpse        = require("kpse")
local insert      = table.insert
local remove      = table.remove
local execute     = os.execute

-- module name
local _NAME = "l3build-boot"

-- reentrancy
local boot = package.loaded[_NAME]
if boot then
  return boot
end

-- base module attributes
boot = boot or {} -- some attributes may be defined upwind

boot._TYPE     = "module"
boot._NAME     = _NAME
boot._VERSION  = "dev" -- the "dev" must be replaced by a release date
boot.PATH  = {} -- unique key
boot.trace = {}
boot.trace_prompt = "**"
boot.trace_level = 0

---To make the difference between "a variable is defined but contains
---nothing" and "a variable was never defined"
---No use case yet...
---@const NONE
boot.NONE = {}

-- ensure that next `require("l3build-boot"")` returns `boot`.
-- because a `dofile` was certainly used at first because
-- lua cannot guess yet the location of the package.

package.loaded[_NAME] = boot

-- next code chunk may be used in many places.
-- it defines the locations where `require` should also look for `l3build` modules
boot.current_dir = currentdir() .. "/"
kpse.set_program_name("kpsewhich")
boot.kpse_dir = kpse.lookup("l3build.lua"):match(".*/") -- either TDS or current directory
boot.launch_dir = arg[0]:match("^(.*/).*%.lua$") or "./"
boot.script_dir = boot.launch_dir .. "script/" -- hard coded
-- Remark: What about l3b.kpse_dir == l3b.launch_dir possibility ?
-- Is there something to save, memory or time?

-- * Naming convention *:
-- all "foo_dir" and "foodir" variables contain a path to a directory
-- when non void the former includes the trailing "/" but not the latter.

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

---search the path of the module with the given name.
---@param name string
---@return string
function boot.search_path(name)
  local long = name:match("^.*%.lua$") or name .. ".lua"
  local path
  local function search(p)
    return package.searchpath("", p)
  end
  if name:match("^l3build") then
    path = search(boot.launch_dir .. long)
        or search(boot.script_dir .. long)
        or boot.parent_search_path(name, boot.current_dir)
        or search(boot.kpse_dir .. long)
  else
    path = search(boot.current_dir .. long)
        or search(boot.launch_dir .. long)
        or boot.more_search_path(name)
        or search(boot.kpse_dir .. long)
  end
  return path
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
  local path = boot.search_path(name)
  if path then
    boot.trace_show("require", "module found at: " .. path)
    return loader, path
  end
  return "\n        [l3build searcher] file not found: '" .. name .. "'"
end

---Install the l3build dedicated searcher
function boot.install_searcher()
  boot.uninstall_searcher() -- if any
  -- We insert a new searcher after the first default searcher.
  insert(package.searchers, 2, searcher)
end

function boot.uninstall_searcher()
  -- Find the index, then remove when found
  for i,s in ipairs(package.searchers) do
    if s == searcher then
      remove(package.searchers, i)
      return
    end
  end
end

-- only install the searcher when no in legacy mode
-- `boot.legacy` must be true prior to importing the boot module.
-- It is always possible to uninstall the searcher afterwards.
if not boot.legacy then
  boot.install_searcher()
end

-- Some os specific strings
boot.directory_separator = package.config:sub(1,1)
boot.template_separator  = package.config:match("^.-[\r\n]+([^\r\n]+)")
boot.substitution_mark   = package.config:match("^.-[\r\n]+.-[\r\n]+([^\r\n]+)")
assert( boot.directory_separator
    and boot.template_separator
    and boot.substitution_mark,
  "bad package.config match:" .. package.config
)

---Scans the parents of the current directory.
---@param name string
---@return string or nil + an error message
function boot.parent_search_path(name, dir)
  -- what is the mark for substitution points? is it relevant to ask?
  local mark = boot.substitution_mark
  local pattern = name:match("%.lua$") and mark or mark .. ".lua"
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

-- Module dependency management
-- In TL 2020 at least, all the different parts of l3build are loaded
-- at once such that any part depends virtually on the others.
-- Separating the codes between modules gives more control on object lifetime.
-- This is particularly sensible in a scripting language where everything
-- is defined at least with nil.

boot.PROXY_NAME = {} -- unique key

---The module will be loaded only when the usage requires it,
---unless someone else has already required it.
---This is interesting when a module does not need the contents of a module
---until run time, after all the setup and configuration processes are performed.
---Of course `boot.future_load('l3build-boot')` does not make any sense.
---@param name string|table
---@return table|boolean
function boot.delay_require(name)
  name = name:match("^(.*)%.lua") or name -- normalize name
  local loaded = package.loaded[name]
  if loaded then -- already required
    return loaded
  end
  -- return a proxy to a void table
  assert(boot.search_path(name), "module not found " .. name)
  return setmetatable({
    [boot.PROXY_NAME] = name,
  }, {
    __index = function(t, k) -- on the first (unknonw) field requirement,
      local m = require(t[boot.PROXY_NAME]) -- load the package
      setmetatable(t, {
        __index    = m, -- next time, all unknown key requests are formarded to the package.
        __newindex = m,
      })
      return m[k]
    end,
    __newindex = function(t, k, v)
      if k == boot.PROXY_NAME then
        error("boot.PROXY_NAME field is readonly")
      end
      local m = require(t[boot.PROXY_NAME]) -- load the package
      setmetatable(t, {
        __index    = m, -- next time, all unknown key requests are formarded to the package.
        __newindex = m,
      })
      m[k] = v
    end,
  })
end

-- Low level utility functions, they belong here because of their early use

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

---Execute the command given in a printf like format.
---@param cmd string
---@param opt_1 any
---@param opt_n any
---@return any
function boot.execute(cmd, ...)
  return execute(cmd:format(...))
end

return boot
