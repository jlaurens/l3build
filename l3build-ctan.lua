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

local L3B = L3B
local Opts = Opts

-- global tables

local OS = L3B.require('OS')
local FS = L3B.require('FS')
local Aux = L3B.require('Aux')
local V = L3B.require('Vars')
local Ins = L3B.require('Ins')

-- Module table

local CTAN = L3B.provide('CTAN')

-- Copy files to the main CTAN release directory
local function copyctan()
  FS.mkdir(FS.dir.ctan .. "/" .. V.ctanpkg)
  local function copyfiles(files, source)
    if source == FS.dir.current or V.flatten then
      for _, filetype in pairs(files) do
        FS.cp(filetype, source, FS.dir.ctan .. "/" .. V.ctanpkg)
      end
    else
      for _, filetype in pairs(files) do
        for file, _ in pairs(FS.tree(source, filetype)) do
          local path = FS.splitpath(file)
          local ctantarget = FS.dir.ctan .. "/" .. V.ctanpkg .. "/"
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
    copyfiles(tab, FS.dir.docfile)
  end
  copyfiles(V.sourcefiles, FS.dir.sourcefile)
  for _,file in pairs(V.textfiles) do
    FS.cp(file, FS.dir.textfile, FS.dir.ctan .. "/" .. V.ctanpkg)
  end
end

function CTAN.bundlectan()
  local error_n = Ins.install_files(FS.dir.tds, true)
  if error_n ~=0 then return error_n end
  copyctan()
  return 0
end

function CTAN.ctan()
  -- Always run tests for all engines
  Opts.engines = nil
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
  local error_n
  local standalone = false
  if V.bundle == "" then
    standalone = true
  end
  if standalone then
    error_n = Aux.call({"."},"check", Opts)
    V.bundle = module
  else
    error_n = Aux.call(V.modules, "bundlecheck", Opts)
  end
  if error_n == 0 then
    FS.rmdir(FS.dir.ctan)
    FS.mkdir(FS.dir.ctan .. "/" .. V.ctanpkg)
    FS.rmdir(FS.dir.tds)
    FS.mkdir(FS.dir.tds)
    if standalone then
      error_n = install_files(FS.dir.tds, true)
      if error_n ~=0 then return error_n end
      copyctan()
    else
      error_n = Aux.call(V.modules, "bundlectan", Opts)
    end
  else
    print([[
====================
Tests failed, zip stage skipped!
====================
]])
    return error_n
  end
  if error_n == 0 then
    for _, i in ipairs(V.textfiles) do
      for _, j in pairs({ FS.dir.unpack, FS.dir.textfile }) do
        FS.cp(i, j, FS.dir.ctan .. "/" .. V.ctanpkg)
        FS.cp(i, j, FS.dir.tds .. "/doc/" .. V.tdsroot .. "/" .. V.bundle)
      end
    end
    -- Rename README if necessary
    if V.ctanreadme ~= "" and not
            V.ctanreadme:lower():match("^readme%.%w+") then
      local newfile = "README." .. V.ctanreadme:match("%.(%w+)$")
      for _,dir in pairs({
        FS.dir.ctan .. "/" .. V.ctanpkg,
        FS.dir.tds .. "/doc/" .. V.tdsroot .. "/" .. V.bundle
      }) do
        if FS.fileexists(dir .. "/" .. V.ctanreadme) then
          FS.rm(dir, newfile)
          FS.ren(dir, V.ctanreadme, newfile)
        end
      end
    end
    dirzip(FS.dir.tds, V.ctanpkg .. ".tds")
    if V.packtdszip then
      FS.cp(V.ctanpkg .. ".tds.zip", FS.dir.tds, FS.dir.ctan)
    end
    dirzip(FS.dir.ctan, V.ctanzip)
    FS.cp(V.ctanzip .. ".zip", FS.dir.ctan, FS.dir.current)
  else
    print([[
====================
Typesetting failed, zip stage skipped!
====================
]])
  end
  return error_n
end

return CTAN