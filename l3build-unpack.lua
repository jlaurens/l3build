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

-- local safe guards

local execute          = os.execute

-- Global tables

local Aux = Require('Aux')

-- Unpack the package files using an 'isolated' system: this requires
-- a copy of the 'basic' DocStrip program, which is used then removed
function unpack(sources, sourcedirs)
  local error_n = Aux.depinstall(unpackdeps)
  if error_n ~= 0 then
    return error_n
  end
  error_n = V.bundleunpack(sourcedirs, sources)
  if error_n ~= 0 then
    return error_n
  end
  for _, i in ipairs(installfiles) do
    error_n = FS.cp(i, unpackdir, localdir)
    if error_n ~= 0 then
      return error_n
    end
  end
  return 0
end

function Pack.finalize(self, env)
  env = env or _ENV
  if type(env.bundleunpack) == "function" then
    self.bundleunpack = env.bundleunpack
  end
end

-- Split off from the main unpack so it can be used on a bundle and not
-- leave only one modules files
function Pack.bundleunpack(sourcedirs, sources)
  local error_n = FS.mkdir(localdir)
  if error_n ~=0 then
    return error_n
  end
  error_n = FS.cleandir(unpackdir)
  if error_n ~=0 then
    return error_n
  end
  for _, i in ipairs(sourcedirs or {sourcefiledir}) do
    for _, j in ipairs(sources or {sourcefiles}) do
      for _, k in ipairs(j) do
        error_n = FS.cp(k, i, unpackdir)
        if error_n ~=0 then
          return error_n
        end
      end
    end
  end
  for _, i in ipairs(unpacksuppfiles) do
    error_n = FS.cp(i, supportdir, localdir)
    if error_n ~=0 then
      return error_n
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
