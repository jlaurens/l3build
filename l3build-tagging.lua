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

local open    = io.open
local os_date = os.date
local match   = string.match
local gsub    = string.gsub

---@type utlib_t
local utlib         = require("l3b.utillib")
local entries       = utlib.entries
local values        = utlib.keys
local unique_items  = utlib.unique_items
local first_of    = utlib.first_of
local extend_with   = utlib.extend_with

---@type wklib_t
local wklib       = require("l3b.walklib")
local dir_name    = wklib.dir_name
local base_name   = wklib.base_name

---@type fslib_t
local fslib       = require("l3b.fslib")
local rename      = fslib.rename
local remove_tree = fslib.remove_tree
local tree        = fslib.tree

---@type l3build_t
local l3build = require("l3build")

---@type l3b_vars_t
local l3b_vars  = require("l3b.variables")
---@type Xtn_t
local Xtn   = l3b_vars.Xtn
---@type Dir_t
local Dir   = l3b_vars.Dir
---@type Files_t
local Files   = l3b_vars.Files

---@alias tag_hook_t fun(tag_name: string, tag_date: string): integer

---Update the tag.
---@param file_path string
---@param tag_name string
---@param tag_date string
---@return integer
local function update_file_tag(file_path, tag_name, tag_date)
  local file_name = base_name(file_path)
  print("Tagging  ".. file_name)
  local fh = assert(open(file_path, "rb"))
  local content = fh:read("a")
  fh:close()
  -- Deal with Unix/Windows line endings
  content = gsub(content .. (match(content, "\n$") and "" or "\n"),
    "\r\n", "\n")
  local updated_content = _G.update_tag
    and _G.update_tag(file_name, content, tag_name, tag_date)
    or content
  if content == updated_content then
    return 0
  end
  local dir_path = dir_name(file_path)
  rename(dir_path, file_name, file_name .. Xtn.bak)
  fh = assert(open(file_path, "w"))
  -- Convert line ends back if required during write
  -- Watch for the second return value!
  fh:write(first_of(gsub(updated_content, "\n", os_newline)))
  fh:close()
  remove_tree(dir_path, file_name .. Xtn.bak)
  return 0
end

---Target tag
---@param tag_names table
---@return integer
local function tag(tag_names)
  local options = l3build.options
  local tag_date = options["date"] or os_date("%Y-%m-%d")
  local tag_name = nil
  if tag_names then
    tag_name = tag_names[1]
  end
  local error_level = 0
  for dir in unique_items(Dir.current, Dir.sourcefile, Dir.docfile) do
    for filetype in entries(Files.tag) do
      for file in values(tree(dir, filetype)) do
        error_level = update_file_tag(file, tag_name, tag_date)
        if error_level ~= 0 then
          return error_level
        end
      end
    end
  end
  ---@type tag_hook_t
  local tag_hook = _G.tag_hook
  return tag_hook and tag_hook(tag_name, tag_date) or 0
end

-- this is the map to export function symbols to the global space
local global_symbol_map = {
  tag = tag,
}

--[=[ Export function symbols ]=]
extend_with(_G, global_symbol_map)
-- [=[ ]=]

---@class l3b_tagging_t
---@field tag fun(tag_names: string_list_t): integer

return {
  global_symbol_map = global_symbol_map,
  tag = tag,
}
