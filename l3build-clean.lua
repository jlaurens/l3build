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

-- Remove all generated files
function clean()
  -- To make sure that distribdir never contains any stray subdirs,
  -- it is entirely removed then recreated rather than simply deleting
  -- all of the files
  local error_n =
    FS.rmdir(distribdir)    +
    FS.mkdir(distribdir)    +
    FS.cleandir(localdir)   +
    FS.cleandir(testdir)    +
    FS.cleandir(typesetdir) +
    FS.cleandir(unpackdir)

  if error_n ~= 0 then return error_n end

  local clean_list = {}
  for _, dir in pairs(FS.without_duplicates({maindir, sourcefiledir, docfiledir})) do
    for _, glob in pairs(cleanfiles) do
      for file, _ in pairs(FS.tree(dir, glob)) do
        clean_list[file] = true
      end
    end
    for _, glob in pairs(sourcefiles) do
      for file, _ in pairs(FS.tree(dir, glob)) do
        clean_list[file] = nil
      end
    end
    for file, _ in pairs(clean_list) do
      error_n = FS.rm(dir, file)
      if error_n ~= 0 then return error_n end
    end
  end

  return 0
end

function bundleclean()
  local error_n = Aux.call(modules, "clean", Opts)
  for _, i in ipairs(cleanfiles) do
    error_n = FS.rm(FS.dir.current, i) + error_n
  end
  return (
    error_n     +
    FS.rmdir(FS.dir.ctan) +
    FS.rmdir(tdsdir)
  )
end

