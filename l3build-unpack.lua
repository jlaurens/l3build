--[[

File l3build-unpack.lua Copyright (C) 2018-2020 The LaTeX3 Project

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

local execute          = os.execute

-- Unpack the package files using an 'isolated' system: this requires
-- a copy of the 'basic' DocStrip program, which is used then removed
function unpack(sources, sourcedirs)
  local errorlevel = depinstall(unpackdeps)
  if errorlevel ~= 0 then
    return errorlevel
  end
  errorlevel = bundleunpack(sourcedirs, sources)
  if errorlevel ~= 0 then
    return errorlevel
  end
  for _, i in ipairs(installfiles) do
    errorlevel = FS.cp(i, unpackdir, localdir)
    if errorlevel ~= 0 then
      return errorlevel
    end
  end
  return 0
end

-- Split off from the main unpack so it can be used on a bundle and not
-- leave only one modules files
bundleunpack = bundleunpack or function(sourcedirs, sources)
  local errorlevel = FS.mkdir(localdir)
  if errorlevel ~=0 then
    return errorlevel
  end
  errorlevel = FS.cleandir(unpackdir)
  if errorlevel ~=0 then
    return errorlevel
  end
  for _, i in ipairs(sourcedirs or {sourcefiledir}) do
    for _, j in ipairs(sources or {sourcefiles}) do
      for _, k in ipairs(j) do
        errorlevel = FS.cp(k, i, unpackdir)
        if errorlevel ~=0 then
          return errorlevel
        end
      end
    end
  end
  for _, i in ipairs(unpacksuppfiles) do
    errorlevel = FS.cp(i, supportdir, localdir)
    if errorlevel ~=0 then
      return errorlevel
    end
  end
  for _, i in ipairs(unpackfiles) do
    for j, _ in pairs(FS.tree(unpackdir, i)) do
      local path, name = FS.splitpath(j)
      local localdir = FS.abspath(localdir)
      local success = io.popen(
        "cd " .. unpackdir .. "/" .. path .. OS.concat ..
        OS.setenv .. " TEXINPUTS=." .. OS.pathsep
          .. localdir .. (unpacksearch and OS.pathsep or "") ..
        OS.concat  ..
        OS.setenv .. " LUAINPUTS=." .. OS.pathsep
          .. localdir .. (unpacksearch and OS.pathsep or "") ..
        OS.concat ..
        unpackexe .. " " .. unpackopts .. " " .. name
          .. (Opts.quiet and (" > " .. OS.null) or ""),
        "w"
      ):write(string.rep("y\n", 300)):close()
      if not success then
        return 1
      end
    end
  end
  return 0
end
