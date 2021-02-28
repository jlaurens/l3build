--[[

File l3build-clean.lua Copyright (C) 2018,2020 The LaTeX Project

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

local util          = require("l3b.util")
local entries       = util.entries
local keys          = util.keys
local unique_items  = util.unique_items

-- Remove all generated files
function clean()
  -- To make sure that distribdir never contains any stray subdirs,
  -- it is entirely removed then recreated rather than simply deleting
  -- all of the files
  local errorlevel =
    rmdir(distribdir)    +
    mkdir(distribdir)    +
    cleandir(localdir)   +
    cleandir(testdir)    +
    cleandir(typesetdir) +
    cleandir(unpackdir)

  if errorlevel ~= 0 then return errorlevel end

  local clean_list = { }
  for dir in unique_items(maindir, sourcefiledir, docfiledir) do
    for glob in entries(cleanfiles) do
      for file in keys(tree(dir,glob)) do
        clean_list[file] = true
      end
    end
    for glob in entries(sourcefiles) do
      for file in keys(tree(dir,glob)) do
        clean_list[file] = nil
      end
    end
    for file in keys(clean_list) do
      errorlevel = rm(dir,file)
      if errorlevel ~= 0 then return errorlevel end
    end
  end

  return 0
end

function bundleclean()
  local errorlevel = call(modules, "clean")
  for i in entries(cleanfiles) do
    errorlevel = rm(currentdir, i) + errorlevel
  end
  return (
    errorlevel     +
    rmdir(ctandir) +
    rmdir(tdsdir)
  )
end

