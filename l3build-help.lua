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
local append = table.insert

---@type utlib_t
local utlib           = require("l3b-utillib")
local sorted_entries  = utlib.sorted_entries

---@type fslib_t
local fslib = require("l3b-fslib")
local absolute_path = fslib.absolute_path

---@type l3build_t
local l3build = require("l3build")

---@type l3b_vars_t
local l3b_vars = require("l3build-variables")
---@type Main_t
local Main  = l3b_vars.Main
---@type Dir_t
local Dir   = l3b_vars.Dir
local guess_bundle_module = l3b_vars.guess_bundle_module

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
  local get_all_info = require("l3b-targets").get_all_info
  for info in get_all_info() do
    if #info.name > width then
      width = #info.name
    end
  end
  for info in get_all_info() do
    local filler = (" "):rep(width - #info.name + 1)
    print("   " .. info.name .. filler .. info.description)
  end
  print("")
  print("Valid options are:")
  width = 0
  get_all_info = require("l3b-options").get_all_info
  for info in get_all_info() do
    if #info.long > width then
      width = #info.long
    end
  end
  for info in get_all_info() do
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

local function status_run()
  local work_dir = l3build.work_dir
  local main_dir = l3build.main_dir
  if not work_dir then
    print("No status inforation available")
  end
  print("Status information:")
  local bundle, module = guess_bundle_module()
  if not l3build.in_document then
    if main_dir == work_dir then
      local modules = Main.modules
      if #modules > 0 then
        -- this is a top bundle
        print("  bundle: ".. (bundle or ""))
        print("  path:   ".. absolute_path(Dir.work))
        local mm = {}
        for m in sorted_entries(modules) do
          append(mm, ("%s (./%s)"):format(m:lower(), m))
        end
        if #modules > 1 then
          print("  modules: ".. concat(mm, ", "))
        else
          print("  module: ".. mm[1])
        end
      else
        -- this is a standalone module (not in a bundle).
        print("  module: ".. (module or ""))
        print("  path:   ".. absolute_path(Dir.work))
      end
    else
      -- a module inside a bundle
      print("  bundle: ".. (bundle or ""))
      print("  module: ".. (module or ""))
      print("  path:   ".. absolute_path(Dir.work))
    end
    print("  start:  ".. l3build.start_dir)
    print("  launch: ".. l3build.launch_dir)
  end
  print()
  if l3build.options.debug then
    ---@type l3b_globals_t
    local l3b_globals = require("l3build-globals")
    l3b_globals.print_status()
  end
end

---Prepare data for status command
---@return error_level_n
local function status_prepare()
  if l3build.options.debug then
    ---@type l3b_globals_t
    local l3b_globals = require("l3build-globals")
    l3b_globals.prepare_print_status()
  end
  return 0
end

---@class l3b_help_t
---@field version     fun()
---@field help        fun()
---@field status_impl target_impl_t

return {
  version     = version,
  help        = help,
  status_impl = {
    prepare = status_prepare,
    run     = status_run,
  },
}
