--[[

File l3build-ctan.lua Copyright (C) 2018-2020 The LaTeX Project

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

local print = print

local lower = string.lower
local match = string.match

local util    = require("l3b.util")
local entries = util.entries
local items   = util.items
local values  = util.values
local to_quoted_string = util.to_quoted_string

-- Copy files to the main CTAN release directory
function copyctan()
  mkdir(ctandir .. "/" .. ctanpkg)
  local function copyfiles(files,source)
    if source == currentdir or flatten then
      for filetype in entries(files) do
        cp(filetype,source,ctandir .. "/" .. ctanpkg)
      end
    else
      for filetype in entries(files) do
        for file in values(tree(source,filetype)) do
          local path = dirname(file)
          local ctantarget = ctandir .. "/" .. ctanpkg .. "/" .. path
          mkdir(ctantarget)
          cp(file,source,ctantarget)
        end
      end
    end
  end
  for tab in items(
    bibfiles,demofiles,docfiles,
    pdffiles,scriptmanfiles,typesetlist
  ) do
    copyfiles(tab,docfiledir)
  end
  copyfiles(sourcefiles,sourcefiledir)
  for file in entries(textfiles) do
    cp(file, textfiledir, ctandir .. "/" .. ctanpkg)
  end
end

function bundlectan()
  local errorlevel = install_files(tdsdir,true)
  if errorlevel ~=0 then return errorlevel end
  copyctan()
  return 0
end

function ctan()
  -- Always run tests for all engines
  options["engine"] = nil
  local function dirzip(dir, name)
    local zipname = name .. ".zip"
    -- Convert the tables of files to quoted strings
    local binfiles = to_quoted_string(binaryfiles)
    local exclude = to_quoted_string(excludefiles)
    -- First, zip up all of the text files
    run(
      dir,
      zipexe .. " " .. zipopts .. " -ll ".. zipname .. " " .. "."
        .. (
          (binfiles or exclude) and (" -x" .. binfiles .. " " .. exclude)
          or ""
        )
    )
    -- Then add the binary ones
    run(
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
    rmdir(ctandir)
    mkdir(ctandir .. "/" .. ctanpkg)
    rmdir(tdsdir)
    mkdir(tdsdir)
    if standalone then
      errorlevel = install_files(tdsdir,true)
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
    for i in entries(textfiles) do
      for j in items(unpackdir, textfiledir) do
        cp(i, j, ctandir .. "/" .. ctanpkg)
        cp(i, j, tdsdir .. "/doc/" .. tdsroot .. "/" .. bundle)
      end
    end
    -- Rename README if necessary
    if ctanreadme ~= "" and not match(lower(ctanreadme),"^readme%.%w+") then
      local newfile = "README." .. match(ctanreadme,"%.(%w+)$")
      for dir in items(
        ctandir .. "/" .. ctanpkg,
        tdsdir .. "/doc/" .. tdsroot .. "/" .. bundle
      ) do
        if fileexists(dir .. "/" .. ctanreadme) then
          rm(dir,newfile)
          ren(dir,ctanreadme,newfile)
        end
      end
    end
    dirzip(tdsdir, ctanpkg .. ".tds")
    if packtdszip then
      cp(ctanpkg .. ".tds.zip", tdsdir, ctandir)
    end
    dirzip(ctandir, ctanzip)
    cp(ctanzip .. ".zip", ctandir, currentdir)
  else
    print("\n====================")
    print("Typesetting failed, zip stage skipped!")
    print("====================\n")
  end
  return errorlevel
end

