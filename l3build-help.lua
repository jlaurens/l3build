--[[

File l3build-help.lua Copyright (C) 2028-2020 The LaTeX Project

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

local concat = table.concat
local push   = table.insert
local write  = io.write

---@type utlib_t
local utlib            = require("l3b-utillib")
local entries          = utlib.entries
local keys              = utlib.keys
local compare_ascending = utlib.compare_ascending
local sorted_pairs      = utlib.sorted_pairs

---@type fslib_t
local fslib = require("l3b-fslib")
local absolute_path = fslib.absolute_path

---@type l3build_t
local l3build = require("l3build")

---@type l3b_globals_t
local l3b_globals = require("l3build-globals")
---@type G_t
local G     = l3b_globals.G
---@type Dir_t
local Dir   = l3b_globals.Dir
local get_vanilla_globals = l3b_globals.get_vanilla
local all_global_entries  = l3b_globals.all_entries

---@type l3b_targets_t
local l3b_targets = require("l3b-targets")
local CONTINUE = l3b_targets.CONTINUE

local function version()
  print(
    "\n" ..
    "l3build: A testing and building system for LaTeX\n\n" ..
    "Release " .. release_date .. "\n" ..
    "Copyright (C) 2014-2020 The LaTeX Project"
  )
end

local function help()
  local scriptname = "l3build"
  if not (arg[0]:match("l3build%.lua$") or arg[0]:match("l3build$")) then
    scriptname = arg[0]
  end
  print("usage: " .. scriptname .. " <target> [<options>] [<names>]")
  print("")
  print("Valid targets are:")
  local width = 0
  local get_all_infos = require("l3b-targets").get_all_infos
  for info in get_all_infos() do
    if #info.name > width then
      width = #info.name
    end
  end
  for info in get_all_infos() do
    local filler = (" "):rep(width - #info.name + 1)
    print("   " .. info.name .. filler .. info.description)
  end
  print("")
  print("Valid options are:")
  width = 0
  get_all_infos = require("l3b-options").get_all_infos
  for info in get_all_infos() do
    if #info.long > width then
      width = #info.long
    end
  end
  for info in get_all_infos() do
    local filler = (" "):rep(width - #info.long + 1)
    if info.short then
      print("   --" .. info.long .. "|-" .. info.short .. filler .. info.description)
    else
      print("   --" .. info.long .. "   " .. filler .. info.description)
    end
  end
  print("")
  print("Full manual available via 'texdoc l3build'.")
  print("")
  print("Repository  : https://github.com/latex3/l3build")
  print("Bug tracker : https://github.com/latex3/l3build/issues")
  print("Copyright (C) 2014-2020 The LaTeX Project")
end

---Print status for global function and hooks,
---for global variables as well.
local function print_status()
  local l3b_functions = {
    "bundlectan",
    "typeset",
    "bibtex",
    "biber",
    "makeindex",
    "tex",
    "checkinit_hook",
    "runtest_tasks",
    "update_tag",
    "tag_hook",
    "typeset_demo_tasks",
    "docinit_hook",
    "manifest_setup",
    "manifest_sort_within_match",
    "manifest_sort_within_group",
    "manifest_extract_filedesc",
    "manifest_write_opening",
    "manifest_write_subheading",
    "manifest_write_group_heading",
    "manifest_write_group_file",
    "manifest_write_group_file_descr",
    "call",
    "runcmd",
    "abspath",
    "dirname",
    "basename",
    "cleandir",
    "cp",
    "direxists",
    "fileexists",
    "filelist",
    "glob_to_pattern",
    "jobname",
    "mkdir",
    "ren",
    "rm",
    "run",
    "splitpath",
    "normalize_path",
  }
  print("Hooks and functions, (*) for custom ones")
  local width = 0
  for entry in all_global_entries(function (e)
    return e.type ~= "function"
  end) do
    if #entry.name > width then
      width = #entry.name
    end
  end
  for entry in all_global_entries(function (e)
    return e.type ~= "function"
  end) do
    local filler = (" "):rep(width - #entry.name)
    local is_custom = entry.vanilla_value ~= G[entry.name]
    print("  ".. entry.name .. filler .. (is_custom and " (*)" or ""), entry.type)
  end

  ---Display the list of exported variables
  local variables = {}
  local variables_n = 0
  for entry in all_global_entries(function (e)
    return e.type == "function"
  end) do
    variables[entry.name] = G[entry.name]
    if variables[entry.name] ~= nil then
      variables_n = variables_n + 1
    end
  end
  print("")
  print(("Global variables (%d), (*) for custom ones"):format(variables_n))
-- Print anything - including nested tables
  local function pretty_print(tt, dflt, indent, done)
    dflt = dflt or {}
    done = done or {}
    indent = indent or 0
    if type(tt) == "table" then
      local w = 0
      local has_custom = false
      for k in keys(tt) do
        local l = #tostring(k)
        if l > w then
          w = l
        end
        has_custom = has_custom or tt[k] ~= dflt[k]
      end
      for k, v in sorted_pairs(tt) do
        local after_equals
        if has_custom then
          after_equals = v == dflt[k] and "    " or "(*) "
        else
          after_equals = ""
        end
        local filler = (" "):rep(w - #tostring(k))
        write((" "):rep(indent)) -- indent it
        if type(v) == "table" and not done[v] then
          done[v] = true
          if next(v) then
            write(('["%s"]%s = %s{\n'):format(tostring(k), filler, after_equals))
            pretty_print(v, dflt[k], indent + w + 7, done)
            write((" "):rep( indent + w + 5)) -- indent it
            write("}\n")
          else
            write(('["%s"]%s = %s{}\n'):format(tostring(k), filler, after_equals))
          end
        elseif type(v) == "string" then
          write(('["%s"]%s = %s"%s"\n'):format(
              tostring(k), filler, after_equals, tostring(v)))
        else
          write(('["%s"]%s = %s%s\n'):format(
              tostring(k), filler, after_equals, tostring(v)))
        end
      end
    else
      write(tostring(tt) .. (tt ~= dflt and "(*)" or '') .."\n")
    end
  end
  pretty_print(variables, get_vanilla_globals())
end

---High level status runner
---@param options options_t
---@return error_level_n?
local function status_high(options)
  local name = options.get_main_variable
  if name then
    return l3b_globals.handle_get_main_variable(name, options.config)
  end
  return CONTINUE
end

---Display status information.
local function status_run()
  local work_dir = l3build.work_dir
  if not work_dir then
    print("No status information available")
  end
  print("Status information:")
  local bundle, module = G.bundle, G.module
  if not l3build.in_document then
    if G.is_standalone then
      print(  "  module: ".. module)
      print(  "  path:  ".. absolute_path(Dir.work))
    elseif G.at_bundle_top then
      -- this is a top bundle
      print(  "  bundle: ".. bundle)
      print(  "  path:  ".. absolute_path(Dir.work))
      local modules = G.modules
      if #modules > 0 then
        local mm = {}
        for m in entries(modules, { compare = compare_ascending}) do
          push(mm, ("%s (./%s)"):format(m:lower(), m))
        end
        if #modules > 1 then
          print("  modules: ".. concat(mm, ", "))
        else
          print("  module: ".. mm[1])
        end
      end
    else
      -- a module inside a bundle
      print(    "  bundle: ".. bundle)
      print(    "  module: ".. module)
      print(    "  path:  ".. absolute_path(Dir.work))
    end
    print(      "  start: ".. l3build.start_dir / '.')
    print(      "  launch: ".. l3build.launch_dir / '.')
  end
  print()
  if l3build.options.debug then
    print("Command: ".. concat(arg, " ", 0))
    print()
    print_status()
  end
end

---@class l3b_help_t
---@field public version     fun()
---@field public help        fun()
---@field public status_impl target_impl_t

return {
  version     = version,
  help        = help,
  status_impl = {
    run_high    = status_high,
    run         = status_run,
    run_bundle  = status_run,
  },
}
