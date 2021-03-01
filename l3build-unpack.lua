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

---@type utlib_t
local utlib = require("l3b.utillib")
local entries = utlib.entries
local keys = utlib.keys

---@type wklib_t
local wklib             = require("l3b.walklib")
local dir_base          = wklib.dir_base

---@type oslib_t
local oslib             = require("l3b.oslib")
local cmd_concat        = oslib.cmd_concat

---@type fslib_t
local fslib                 = require("l3b.fslib")
local copy_tree             = fslib.copy_tree
local make_directory        = fslib.make_directory
local make_clean_directory  = fslib.make_clean_directory
local tree                  = fslib.tree
local absolute_path         = fslib.absolute_path

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
  errorlevel = make_clean_directory(unpackdir)
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
