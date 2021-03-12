--[[

File l3build-tagging.lua Copyright (C) 2018-2020 The LaTeX Project

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
local chooser       = utlib.chooser
local entries       = utlib.entries
local values        = utlib.keys
local unique_items  = utlib.unique_items
local read_content  = utlib.read_content
local write_content = utlib.write_content

---@type wklib_t
local wklib       = require("l3b-walklib")
local dir_name    = wklib.dir_name
local base_name   = wklib.base_name

---@type fslib_t
local fslib       = require("l3b-fslib")
local rename      = fslib.rename
local remove_tree = fslib.remove_tree
local tree        = fslib.tree

---@type l3build_t
local l3build = require("l3build")

---@type l3b_vars_t
local l3b_vars  = require("l3build-variables")
---@type Main_t
local Main      = l3b_vars.Main
---@type Xtn_t
local Xtn       = l3b_vars.Xtn
---@type Dir_t
local Dir       = l3b_vars.Dir
---@type Files_t
local Files     = l3b_vars.Files

---@type l3b_aux_t
local l3b_aux = require("l3build-aux")
local call    = l3b_aux.call

--[=[ Package implementation ]=]

---@class l3b_tagging_vars_t
---@field tag_hook    fun(tag_name: string, tag_date: string): error_level_n
---@field update_tag  fun(file_name: string, content: string, tag_name: string, tag_date: string): string

---@type l3b_tagging_vars_t
local Vars = chooser({
  global = _G,
  default = {
    tag_hook = function (tag_name, tag_date)
      return 0
    end,
    update_tag = function(file_name, content, tag_name, tag_date)
      return content
    end,
  },
})

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
  local updated_content = Vars.update_tag(file_name, content, tag_name, tag_date)
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
---@param tag_names string_list_t|nil
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
  return Vars.tag_hook(tag_name, tag_date)
end

---Target tag
---@param tag_names string_list_t|nil, singleton list
---@return error_level_n
local function bundle_tag(tag_names)
  local error_level = call(Main.modules, "tag")
  -- Deal with any files in the bundle dir itself
  if error_level == 0 then
    error_level = tag(tag_names)
  end
  return error_level
end

---@class l3b_tagging_t
---@field tag_impl target_impl_t

return {
  tag_impl = {
    run = tag,
    bundle_run = bundle_tag,
  },
}
