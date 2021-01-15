--[[

File l3build-ctan.lua Copyright (C) 2018-2020 The LaTeX3 Project

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

local pairs = pairs
local print = print

-- global tables

local OS = Require(OS)
local FS = Require(FS)
local Aux = Require(Aux)
local Opts = Require(Opts)
local V = Require(Vars)
local Ins = Require(Ins)

-- Module table

local CTAN = Provide(CTAN)

-- Copy files to the main CTAN release directory
local function copyctan()
  FS.mkdir(V.ctandir .. "/" .. V.ctanpkg)
  local function copyfiles(files, source)
    if source == V.currentdir or V.flatten then
      for _, filetype in pairs(files) do
        FS.cp(filetype, source, V.ctandir .. "/" .. V.ctanpkg)
      end
    else
      for _, filetype in pairs(files) do
        for file, _ in pairs(FS.tree(source, filetype)) do
          local path = FS.splitpath(file)
          local ctantarget = V.ctandir .. "/" .. V.ctanpkg .. "/"
            .. source .. "/" .. path
          FS.mkdir(ctantarget)
          FS.cp(file, source, ctantarget)
        end
      end
    end
  end
  for _,tab in pairs({
      V.bibfiles,
      V.demofiles,
      V.docfiles,
      V.pdffiles,
      V.scriptmanfiles,
      V.typesetlist
    }) do
    copyfiles(tab, V.docfiledir)
  end
  copyfiles(V.sourcefiles, V.sourcefiledir)
  for _,file in pairs(V.textfiles) do
    FS.cp(file, V.textfiledir, V.ctandir .. "/" .. V.ctanpkg)
  end
end

function CTAN.bundlectan()
  local errorlevel = Ins.install_files(V.tdsdir, true)
  if errorlevel ~=0 then return errorlevel end
  copyctan()
  return 0
end

function CTAN.ctan()
  -- Always run tests for all engines
  Opts.engine = nil
  local function dirzip(dir, name)
    local zipname = name .. ".zip"
    local function tab_to_str(table)
      local string = ""
      for _, i in ipairs(table) do
        string = string .. " " .. "\"" .. i .. "\""
      end
      return string
    end
    -- Convert the tables of files to quoted strings
    local binfiles = tab_to_str(V.binaryfiles)
    local exclude = tab_to_str(V.excludefiles)
    -- First, zip up all of the text files
    OS.run(
      dir,
      V.zipexe .. " " .. V.zipopts .. " -ll ".. zipname .. " " .. "."
        .. (
          (binfiles or exclude) and (" -x" .. binfiles .. " " .. exclude)
          or ""
        )
    )
    -- Then add the binary ones
    OS.run(
      dir,
      V.zipexe .. " " .. V.zipopts .. " -g ".. zipname .. " " .. ". -i" ..
        binfiles .. (exclude and (" -x" .. exclude) or "")
    )
  end
  local errorlevel
  local standalone = false
  if V.bundle == "" then
    standalone = true
  end
  if standalone then
    errorlevel = Aux.call({"."},"check")
    V.bundle = module
  else
    errorlevel = Aux.call(V.modules, "bundlecheck")
  end
  if errorlevel == 0 then
    FS.rmdir(V.ctandir)
    FS.mkdir(V.ctandir .. "/" .. V.ctanpkg)
    FS.rmdir(V.tdsdir)
    FS.mkdir(V.tdsdir)
    if standalone then
      errorlevel = install_files(V.tdsdir, true)
      if errorlevel ~=0 then return errorlevel end
      copyctan()
    else
      errorlevel = Aux.call(V.modules, "bundlectan")
    end
  else
    print([[
====================
Tests failed, zip stage skipped!
====================
]])
    return errorlevel
  end
  if errorlevel == 0 then
    for _, i in ipairs(V.textfiles) do
      for _, j in pairs({ V.unpackdir, V.textfiledir }) do
        FS.cp(i, j, V.ctandir .. "/" .. V.ctanpkg)
        FS.cp(i, j, V.tdsdir .. "/doc/" .. V.tdsroot .. "/" .. V.bundle)
      end
    end
    -- Rename README if necessary
    if V.ctanreadme ~= "" and not
            V.ctanreadme:lower():match("^readme%.%w+") then
      local newfile = "README." .. V.ctanreadme:match("%.(%w+)$")
      for _,dir in pairs({
        V.ctandir .. "/" .. V.ctanpkg,
        V.tdsdir .. "/doc/" .. V.tdsroot .. "/" .. V.bundle
      }) do
        if FS.fileexists(dir .. "/" .. V.ctanreadme) then
          FS.rm(dir, newfile)
          FS.ren(dir, V.ctanreadme, newfile)
        end
      end
    end
    dirzip(V.tdsdir, V.ctanpkg .. ".tds")
    if V.packtdszip then
      FS.cp(V.ctanpkg .. ".tds.zip", V.tdsdir, V.ctandir)
    end
    dirzip(V.ctandir, V.ctanzip)
    FS.cp(V.ctanzip .. ".zip", V.ctandir, V.currentdir)
  else
    print([[
====================
Typesetting failed, zip stage skipped!
====================
]])
  end
  return errorlevel
end

return CTAN