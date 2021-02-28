--[[

File l3build-unpack.lua Copyright (C) 2018-2020 The LaTeX Project

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

local util = require("l3b.util")
local entries = util.entries
local keys = util.keys

local fifu                = require("l3b.file-functions")
local cmd_concat          = fifu.cmd_concat
local copy_tree           = fifu.copy_tree
local make_directory      = fifu.make_directory
local make_clean_drectory = fifu.make_clean_drectory
local tree                = fifu.tree
local absolute_path       = fifu.absolute_path
local dir_base            = fifu.dir_base

-- Unpack the package files using an 'isolated' system: this requires
-- a copy of the 'basic' DocStrip program, which is used then removed
function unpack(sources, sourcedirs)
  local errorlevel = dep_install(unpackdeps)
  if errorlevel ~= 0 then
    return errorlevel
  end
  errorlevel = bundleunpack(sourcedirs, sources)
  if errorlevel ~= 0 then
    return errorlevel
  end
  for i in entries(installfiles) do
    errorlevel = copy_tree(i, unpackdir, localdir)
    if errorlevel ~= 0 then
      return errorlevel
    end
  end
  return 0
end

-- Split off from the main unpack so it can be used on a bundle and not
-- leave only one modules files
bundleunpack = bundleunpack or function(sourcedirs, sources)
  local errorlevel = make_directory(localdir)
  if errorlevel ~=0 then
    return errorlevel
  end
  errorlevel = make_clean_drectory(unpackdir)
  if errorlevel ~=0 then
    return errorlevel
  end
  for i in entries(sourcedirs or { sourcefiledir }) do
    for j in entries(sources or { sourcefiles }) do
      for k in entries(j) do
        errorlevel = copy_tree(k, i, unpackdir)
        if errorlevel ~=0 then
          return errorlevel
        end
      end
    end
  end
  for i in entries(unpacksuppfiles) do
    errorlevel = copy_tree(i, supportdir, localdir)
    if errorlevel ~=0 then
      return errorlevel
    end
  end
  for i in entries(unpackfiles) do
    for j in keys(tree(unpackdir, i)) do
      local path, name = dir_base(j)
      local localdir = absolute_path(localdir)
      local success = io.popen(cmd_concat(
          "cd " .. unpackdir .. "/" .. path,
          os_setenv .. " TEXINPUTS=." .. os_pathsep
            .. localdir .. (unpacksearch and os_pathsep or ""),
          os_setenv .. " LUAINPUTS=." .. os_pathsep
            .. localdir .. (unpacksearch and os_pathsep or ""),
          unpackexe .. " " .. unpackopts .. " " .. name
            .. (options["quiet"] and (" > " .. os_null) or "")
        ), "w"
      ):write(string.rep("y\n", 300)):close()
      if not success then
        return 1
      end
    end
  end
  return 0
end
