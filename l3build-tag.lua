--[[

File l3build-tag.lua Copyright (C) 2018-2020 The LaTeX Project

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

local os_date = os.date
local exit    = os.exit

---@type utlib_t
local utlib         = require("l3b-utillib")
local entries       = utlib.entries
local unique_items  = utlib.unique_items

---@type pathlib_t
local pathlib       = require("l3b-pathlib")
local dir_name    = pathlib.dir_name
local base_name   = pathlib.base_name

---@type oslib_t
local oslib         = require("l3b-oslib")
local read_content  = oslib.read_content
local write_content = oslib.write_content

---@type fslib_t
local fslib       = require("l3b-fslib")
local rename      = fslib.rename
local remove_tree = fslib.remove_tree
local tree        = fslib.tree

---@type l3build_t
local l3build = require("l3build")

---@type l3b_globals_t
local l3b_globals = require("l3build-globals")
---@type G_t
local G     = l3b_globals.G
---@type Xtn_t
local Xtn   = l3b_globals.Xtn
---@type Dir_t
local Dir   = l3b_globals.Dir
---@type Files_t
local Files = l3b_globals.Files

---@type l3b_aux_t
local l3b_aux = require("l3build-aux")
local call    = l3b_aux.call

--[=[ Package implementation ]=]

---@alias tag_hook_f    fun(tag_name: string, tag_date: string): error_level_n
---@alias update_tag_f  fun(file_name: string, content: string, tag_name: string, tag_date: string): string

---@type tag_hook_f
local function tag_hook(tag_name, tag_date)
  return 0
end

---@type update_tag_f
local function update_tag(file_name, content, tag_name, tag_date)
  return content
end

---Update the tag.
---@param file_path string
---@param tag_name string
---@param tag_date string
---@return error_level_n
local function update_file_tag(file_path, tag_name, tag_date)
  local file_name = base_name(file_path)
  print("Tagging  ".. file_name)
  local content = assert(read_content(file_path, true))
  -- Deal with Unix/Windows line endings
  content = content .. (content:match("\n$") and "" or "\n")
  local updated_content = G.update_tag(file_name, content, tag_name, tag_date)
  if content == updated_content then
    return 0
  end
  local dir_path = dir_name(file_path)
  rename(dir_path, file_name, file_name .. Xtn.bak)
  write_content(file_path, updated_content)
  remove_tree(dir_path, file_name .. Xtn.bak)
  return 0
end

---Target tag
---@param tag_names string[]|nil
---@return error_level_n
local function tag(tag_names)
  if tag_names and #tag_names > 1 then
    print("No more that one tag name")
    exit(1)
  end
  local options = l3build.options
  local tag_date = options.date or os_date("%Y-%m-%d")
  local tag_name = tag_names and tag_names[1]
  local error_level = 0
  for dir in unique_items(Dir.work, Dir.sourcefile, Dir.docfile) do
    for glob in entries(Files.tag) do
      for p in tree(dir, glob) do
        local file = p.wrk
        error_level = update_file_tag(file, tag_name, tag_date)
        if error_level ~= 0 then
          return error_level
        end
      end
    end
  end
  return G.tag_hook(tag_name, tag_date)
end

---Target tag
---@param tag_names string[]|nil, @singleton list
---@return error_level_n
local function bundle_tag(tag_names)
  local error_level = call(G.modules, "tag")
  -- Deal with any files in the bundle dir itself
  if error_level == 0 then
    error_level = tag(tag_names)
  end
  return error_level
end

---@class l3b_tag_t
---@field public tag_impl    target_impl_t
---@field public update_tag  update_tag_f
---@field public tag_hook    tag_hook_f

return {
  tag_hook    = tag_hook,
  update_tag  = update_tag,
  tag_impl    = {
    run         = tag,
    run_bundle  = bundle_tag,
  },
}
