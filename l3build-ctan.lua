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

local lower = string.lower
local match = string.match

-- global tables

local Vars = assert(#Vars) and Vars

local CTAN = CTAN or {}

-- Copy files to the main CTAN release directory
local function copyctan()
  FS.mkdir(Vars.ctandir .. "/" .. Vars.ctanpkg)
  local function copyfiles(files, source)
    if source == Vars.currentdir or flatten then
      for _,filetype in pairs(files) do
        FS.cp(filetype, source, Vars.ctandir .. "/" .. Vars.ctanpkg)
      end
    else
      for _,filetype in pairs(files) do
        for file,_ in pairs(FS.tree(source, filetype)) do
          local path = FS.splitpath(file)
          local ctantarget = Vars.ctandir .. "/" .. Vars.ctanpkg .. "/"
            .. source .. "/" .. path
          FS.mkdir(ctantarget)
          FS.cp(file, source, ctantarget)
        end
      end
    end
  end
  for _,tab in pairs(
    {bibfiles,demofiles,docfiles,pdffiles,scriptmanfiles,typesetlist}) do
    copyfiles(tab, docfiledir)
  end
  copyfiles(sourcefiles, sourcefiledir)
  for _,file in pairs(textfiles) do
    FS.cp(file, textfiledir, Vars.ctandir .. "/" .. Vars.ctanpkg)
  end
end

function bundlectan()
  local errorlevel = install_files(tdsdir, true)
  if errorlevel ~=0 then return errorlevel end
  copyctan()
  return 0
end

function ctan()
  -- Always run tests for all engines
  Opts.engine = nil
  local function dirzip(dir, name)
    local zipname = name .. ".zip"
    local function tab_to_str(table)
      local string = ""
      for _,i in ipairs(table) do
        string = string .. " " .. "\"" .. i .. "\""
      end
      return string
    end
    -- Convert the tables of files to quoted strings
    local binfiles = tab_to_str(binaryfiles)
    local exclude = tab_to_str(excludefiles)
    -- First, zip up all of the text files
    OS.run(
      dir,
      zipexe .. " " .. zipopts .. " -ll ".. zipname .. " " .. "."
        .. (
          (binfiles or exclude) and (" -x" .. binfiles .. " " .. exclude)
          or ""
        )
    )
    -- Then add the binary ones
    OS.run(
      dir,
      zipexe .. " " .. zipopts .. " -g ".. zipname .. " " .. ". -i" ..
        binfiles .. (exclude and (" -x" .. exclude) or "")
    )
  end
  local errorlevel
  local standalone = false
  if bundle == "" then
    standalone = true
  end
  if standalone then
    errorlevel = call({"."},"check")
    bundle = module
  else
    errorlevel = call(modules, "bundlecheck")
  end
  if errorlevel == 0 then
    FS.rmdir(Vars.ctandir)
    FS.mkdir(Vars.ctandir .. "/" .. Vars.ctanpkg)
    FS.rmdir(tdsdir)
    FS.mkdir(tdsdir)
    if standalone then
      errorlevel = install_files(tdsdir, true)
      if errorlevel ~=0 then return errorlevel end
      copyctan()
    else
      errorlevel = call(modules, "bundlectan")
    end
  else
    print("\n====================")
    print("Tests failed, zip stage skipped!")
    print("====================\n")
    return errorlevel
  end
  if errorlevel == 0 then
    for _,i in ipairs(textfiles) do
      for _,j in pairs({unpackdir, textfiledir}) do
        FS.cp(i, j, Vars.ctandir .. "/" .. Vars.ctanpkg)
        FS.cp(i, j, tdsdir .. "/doc/" .. tdsroot .. "/" .. bundle)
      end
    end
    -- Rename README if necessary
    if ctanreadme ~= "" and not match(lower(ctanreadme),"^readme%.%w+") then
      local newfile = "README." .. match(ctanreadme, "%.(%w+)$")
      for _,dir in pairs({Vars.ctandir .. "/" .. Vars.ctanpkg,
        tdsdir .. "/doc/" .. tdsroot .. "/" .. bundle}) do
        if FS.fileexists(dir .. "/" .. ctanreadme) then
          FS.rm(dir, newfile)
          FS.ren(dir, ctanreadme, newfile)
        end
      end
    end
    dirzip(tdsdir, Vars.ctanpkg .. ".tds")
    if packtdszip then
      FS.cp(Vars.ctanpkg .. ".tds.zip", tdsdir, Vars.ctandir)
    end
    dirzip(Vars.ctandir, ctanzip)
    FS.cp(ctanzip .. ".zip", Vars.ctandir, Vars.currentdir)
  else
    print("\n====================")
    print("Typesetting failed, zip stage skipped!")
    print("====================\n")
  end
  return errorlevel
end

return CTAN