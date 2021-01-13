--[[

File l3build-clean.lua Copyright (C) 2018,2020 The LaTeX3 Project

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

local FF = L3.require('file-functions')
L3.require('aux')

-- Remove all generated files
function clean()
  -- To make sure that distribdir never contains any stray subdirs,
  -- it is entirely removed then recreated rather than simply deleting
  -- all of the files
  local errorlevel =
    FF.rmdir(distribdir)    +
    FF.mkdir(distribdir)    +
    FF.cleandir(localdir)   +
    FF.cleandir(testdir)    +
    FF.cleandir(typesetdir) +
    FF.cleandir(unpackdir)

  if errorlevel ~= 0 then return errorlevel end

  local clean_list = { }
  for _,dir in pairs(FF.remove_duplicates({maindir,sourcefiledir,docfiledir})) do
    for _,glob in pairs(cleanfiles) do
      for file,_ in pairs(FF.tree(dir,glob)) do
        clean_list[file] = true
      end
    end
    for _,glob in pairs(sourcefiles) do
      for file,_ in pairs(FF.tree(dir,glob)) do
        clean_list[file] = nil
      end
    end
    for file,_ in pairs(clean_list) do
      errorlevel = FF.rm(dir,file)
      if errorlevel ~= 0 then return errorlevel end
    end
  end

  return 0
end

function bundleclean()
  local errorlevel = L3:call(modules, "clean")
  for _,i in ipairs(cleanfiles) do
    errorlevel = FF.rm(currentdir, i) + errorlevel
  end
  return (
    errorlevel     +
    FF.rmdir(ctandir) +
    FF.rmdir(tdsdir)
  )
end

