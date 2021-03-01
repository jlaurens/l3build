--[[

File l3build-manifest.lua Copyright (C) 2028-2020 The LaTeX Project

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


--[[
      L3BUILD MANIFEST
      ================
      If desired this entire function can be replaced; if not, it uses a number of
      auxiliary functions which are included in this file.

      Additional setup can be performed by replacing the functions lists in the file
      `l3build-manifest-setup.lua`.
--]]

---@type utlib_t
local utlib       = require("l3b.utillib")
local entries     = utlib.entries
local items       = utlib.items
local keys        = utlib.keys
local extend_with = utlib.extend_with

---@type fslib_t
local fslib      = require("l3b.fslib")
local all_files = fslib.all_files
local file_list = fslib.file_list

---@type l3b_manifest_setup_t
local stp = require("l3b.manifest-setup")
local extract_filedesc        = stp.extract_filedesc
local sort_within_match       = stp.sort_within_match
local sort_within_group       = stp.sort_within_group
local write_opening           = stp.write_opening
local write_heading           = stp.write_heading
local write_group_file_descr  = stp.write_group_file_descr
local write_group_file        = stp.write_group_file
local setup                   = stp.setup

local MT = {}
---comment
---@param entry table
---@param this_file string
---@return table
function MT:build_file(entry, this_file)
  if entry.rename then
    this_file = this_file:gsub(entry.rename[1], entry.rename[2])
  end
  if not entry.excludes[this_file] then
    entry.N = entry.N+1
    if not(entry.matches[this_file]) then
      entry.matches[this_file] = true -- store the file name
      entry.files_ordered[entry.N] = this_file -- store the file order
      entry.Nchar_file = math.max(entry.Nchar_file, this_file:len())
    end
    if not entry.skipfiledescription then
      local fh = assert(io.open(entry.dir .. "/" .. this_file, "r"))
      local extractor = _G.manifest_extract_filedesc or extract_filedesc
      local this_descr = extractor(fh, this_file)
      fh:close()
      if this_descr and this_descr ~= "" then
        entry.descr[this_file] = this_descr
        entry.ND = entry.ND+1
        entry.Nchar_descr = math.max(entry.Nchar_descr, this_descr:len())
      end
    end
  end
  return entry
end

---Build table
---@param entry table
---@return manifest_entry_t
function MT:build_init(entry)
  -- copy default options to each group if necessary
  -- currently these aren't customisable; I guess they could be?
  local defaults = {
    skipfiledescription  = false            ,
    rename               = false            ,
    dir                  = maindir          ,
    exclude              = { excludefiles } ,
    flag                 = true             ,
  }
  for kk, ll in pairs(defaults) do
    if entry[kk] == nil then
      entry[kk] = ll
    end
    -- can't use "entry[kk] = entry[kk] or ll" because false/nil are indistinguishable!
  end
  -- internal data added to each group in the table that needs to be initialised
  local init = {
    N             = 0  , -- # matched files
    ND            = 0  , -- # descriptions
    matches       = {} ,
    excludes      = {} ,
    files_ordered = {} ,
    descr         = {} ,
    Nchar_file    = 4  , -- TODO: generalise
    Nchar_descr   = 11 , -- TODO: generalise
  }
  -- initialisation for internal data
  for kk, ll in pairs(init) do
    entry[kk] = ll
  end
  -- allow nested tables by requiring two levels of nesting
  if type(entry.files[1]) == "string" then
    entry.files = { entry.files }
  end
  if type(entry.exclude[1]) == "string" then
    entry.exclude = { entry.exclude }
  end
  return entry
end

---Internal Manifest functions: build_list
---@param entry manifest_entry_t
---@return manifest_entry_t
function MT:build_list(entry)
  if not entry.subheading then
    entry = self:build_init(entry)
    -- build list of excluded files
    for glob_list in entries(entry.exclude) do
      for this_glob in entries(glob_list) do
        for this_file in all_files(maindir, this_glob) do
          entry.excludes[this_file] = true
        end
      end
    end
    -- build list of matched files
    local match_sort = _G.manifest_sort_within_match or sort_within_match
    local group_sort = _G.manifest_sort_within_group or sort_within_group
    for glob_list in entries(entry.files) do
      for this_glob in entries(glob_list) do
        local these_files = file_list(entry.dir, this_glob)
        these_files = match_sort(these_files)
        for this_file in entries(these_files) do
          entry = self:build_file(entry, this_file)
        end
        entry.files_ordered = group_sort(entry.files_ordered)
      end
    end
	end
  return entry
end

---comment
---@param fh table
---@param entry table
function MT:write_group(fh, entry)
  local writer = _G.manifest_write_group_heading or write_heading
  writer(fh, entry.name, entry.description)
  if entry.ND > 0 then
    writer = _G.manifest_write_group_file_descr or write_group_file_descr
    for ii, file in ipairs(entry.files_ordered) do
      local descr = entry.descr[file] or ""
      ---@type manifest_param_t
      local param = {
        dir         = entry.dir         ,
        count       = ii                ,
        filemaxchar = entry.Nchar_file  ,
        descmaxchar = entry.Nchar_descr ,
        ctanfile    = self.ctanfiles[file]   ,
        tdsfile     = self.tdsfiles[file]    ,
        flag        = false             ,
      }
      if entry.flag then
        param.flag = "    "
	  		if self.tdsfiles[file] and not self.ctanfiles[file] then
	  			param.flag = "†   "
	  		elseif self.ctanfiles[file] then
	  			param.flag = "‡   "
	  		end
			end
			if ii == 1 then
        -- header of table
        -- TODO: generalise
				local p = {}
				for k, v in pairs(param) do p[k] = v end
				p.count = -1
				p.flag = p.flag and "Flag"
        writer(fh, "File", "Description", p)
				p.flag = p.flag and "--- "
        writer(fh, "---", "---", p)
      end
      writer(fh, file, descr, param)
    end

  else

    writer = _G.manifest_write_group_file or write_group_file
    for ii, file in ipairs(entry.files_ordered) do
      local param = {
        dir         = entry.dir         ,
      	count       = ii                ,
      	filemaxchar = entry.Nchar_file  ,
        ctanfile    = self.ctanfiles[file]   ,
        tdsfile     = self.tdsfiles[file]    ,
      }
      if entry.flag then
        param.flag = ""
	  		if self.tdsfiles[file] and not self.ctanfiles[file] then
	  			param.flag = "†"
	  		elseif self.ctanfiles[file] then
	  			param.flag = "‡"
	  		end
			end
      writer(fh, file, param)
    end

  end

end

---comment
---@param manifest_entries table
function MT:write(manifest_entries)
  local fh = assert(io.open(manifestfile, "w"))
  write_opening(fh)
  local wrt_subheading = _G.manifest_write_subheading or write_heading
  for entry in entries(manifest_entries) do
    if entry.subheading then
      wrt_subheading(fh, entry.subheading, entry.description) -- TODO BAD API: remove that fh!
    elseif entry.N > 0 then
      self:write_group(fh, entry)
    end
  end
  fh:close()
end

function MT:manifest()
  -- build list of ctan files
  self.ctanfiles = {}
  for f in all_files(ctandir.."/"..ctanpkg, "*.*") do
    self.ctanfiles[f] = true
  end
  self.tdsfiles = {}
  for subdir in items("/doc/", "/source/", "/tex/") do
    for f in all_files(tdsdir..subdir..moduledir, "*.*") do
      self.tdsfiles[f] = true
    end
  end

  local manifest_entries = (_G.manifest_setup or setup)()

  for ii in keys(manifest_entries) do
    manifest_entries[ii] = self:build_list(manifest_entries[ii])
  end

  self:write(manifest_entries)

  local footer = "Manifest written to " .. manifestfile
  local alt_footer = footer:gsub(".", "*")
  print(alt_footer)
  print(footer)
  print(alt_footer)

end

local function manifest()
  ---Create a wrapper to shared data
  local helper = setmetatable({}, MT)
  helper:manifest()
end

-- this is the map to export function symbols to the global space
local global_symbol_map = {
  manifest = manifest,
}

--[=[ Export function symbols ]=]
extend_with(_G, global_symbol_map)
-- [=[ ]=]

---@class l3b_manifest_t
---@field manifest function

return {
  global_symbol_map = global_symbol_map,
  manifest = manifest,
}
