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

local util      = require("l3b.utilib")
local entries   = util.entries
local items     = util.items
local keys      = util.keys

local fifu      = require("l3b.file-functions")
local all_files = fifu.all_files
local file_list = fifu.file_list

manifest = manifest or function()

  -- build list of ctan files
  ctanfiles = {}
  for f in all_files(ctandir.."/"..ctanpkg, "*.*") do
    ctanfiles[f] = true
  end
  tdsfiles = {}
  for subdir in items("/doc/", "/source/", "/tex/") do
    for f in all_files(tdsdir..subdir..moduledir, "*.*") do
      tdsfiles[f] = true
    end
  end

  local manifest_entries = manifest_setup()

  for ii in keys(manifest_entries) do
    manifest_entries[ii] = manifest_build_list(manifest_entries[ii])
  end

  manifest_write(manifest_entries)

  printline = "Manifest written to " .. manifestfile
  print((printline:gsub(".", "*"))) -- the outer '()' is required
  print(printline)
  print((printline:gsub(".", "*")))

end

--[[
      Internal Manifest functions: build_list
      ---------------------------------------
--]]

manifest_build_list = function(entry)

  if not entry.subheading then

    entry = manifest_build_init(entry)

    -- build list of excluded files
    for glob_list in entries(entry.exclude) do
      for this_glob in entries(glob_list) do
        for this_file in all_files(maindir, this_glob) do
          entry.excludes[this_file] = true
        end
      end
    end

    -- build list of matched files
    for glob_list in entries(entry.files) do
      for this_glob in entries(glob_list) do

        local these_files = file_list(entry.dir, this_glob)
        these_files = manifest_sort_within_match(these_files)

        for this_file in entries(these_files) do
          entry = manifest_build_file(entry, this_file)
        end

        entry.files_ordered = manifest_sort_within_group(entry.files_ordered)

      end
    end

	end

  return entry

end


manifest_build_init = function(entry)

  -- currently these aren't customisable; I guess they could be?
  local manifest_group_defaults = {
    skipfiledescription  = false          ,
    rename               = false          ,
    dir                  = maindir        ,
    exclude              = { excludefiles } ,
    flag                 = true           ,
  }

  -- internal data added to each group in the table that needs to be initialised
  local manifest_group_init = {
    N             = 0  , -- # matched files
    ND            = 0  , -- # descriptions
    matches       = {} ,
    excludes      = {} ,
    files_ordered = {} ,
    descr         = {} ,
    Nchar_file    = 4  , -- TODO: generalise
    Nchar_descr   = 11 , -- TODO: generalise
  }

   -- copy default options to each group if necessary
  for kk, ll in pairs(manifest_group_defaults) do
    if entry[kk] == nil then
      entry[kk] = ll
    end
    -- can't use "entry[kk] = entry[kk] or ll" because false/nil are indistinguishable!
  end

  -- initialisation for internal data
  for kk, ll in pairs(manifest_group_init) do
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


manifest_build_file = function(entry, this_file)

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

    if not(entry.skipfiledescription) then

      local ff = assert(io.open(entry.dir .. "/" .. this_file, "r"))
      this_descr  = manifest_extract_filedesc(ff, this_file)
      ff:close()

      if this_descr and this_descr ~= "" then
        entry.descr[this_file] = this_descr
        entry.ND = entry.ND+1
        entry.Nchar_descr = math.max(entry.Nchar_descr, this_descr:len())
      end

    end
  end

  return entry

end

--[[
      Internal Manifest functions: write
      ----------------------------------
--]]

manifest_write = function(manifest_entries)

  local fh = assert(io.open(manifestfile, "w"))
  manifest_write_opening(fh)

  for entry in entries(manifest_entries) do
    if entry.subheading then
      manifest_write_subheading(fh, entry.subheading, entry.description)
    elseif entry.N > 0 then
      manifest_write_group(fh, entry)
    end
  end

  fh:close()

end


manifest_write_group = function(f, entry)

  manifest_write_group_heading(f, entry.name, entry.description)

  if entry.ND > 0 then

    for ii, file in ipairs(entry.files_ordered) do
      local descr = entry.descr[file] or ""
      local param = {
        dir         = entry.dir         ,
        count       = ii                ,
        filemaxchar = entry.Nchar_file  ,
        descmaxchar = entry.Nchar_descr ,
        ctanfile    = ctanfiles[file]   ,
        tdsfile     = tdsfiles[file]    ,
        flag        = false             ,
      }

      if entry.flag then
        param.flag = "    "
	  		if tdsfiles[file] and not(ctanfiles[file]) then
	  			param.flag = "†   "
	  		elseif ctanfiles[file] then
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
				manifest_write_group_file_descr(f, "File", "Description", p)
				p.flag = p.flag and "--- "
				manifest_write_group_file_descr(f, "---", "---", p)
      end

      manifest_write_group_file_descr(f, file, descr, param)
    end

  else

    for ii, file in ipairs(entry.files_ordered) do
      local param = {
        dir         = entry.dir         ,
      	count       = ii                ,
      	filemaxchar = entry.Nchar_file  ,
        ctanfile    = ctanfiles[file]   ,
        tdsfile     = tdsfiles[file]    ,
      }
      if entry.flag then
        param.flag = ""
	  		if tdsfiles[file] and not ctanfiles[file] then
	  			param.flag = "†"
	  		elseif ctanfiles[file] then
	  			param.flag = "‡"
	  		end
			end
      manifest_write_group_file(f, file, param)
    end

  end

end
