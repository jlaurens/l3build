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

local FF = L3.require('file-functions')
local V = L3.require('variables')

-- Copy files to the main CTAN release directory
L3.copyctan = function ()
  FF.mkdir(V.ctandir .. "/" .. V.ctanpkg)
  local function copyfiles(files,source)
    if source == V.currentdir or V.flatten then
      for _,filetype in pairs(files) do
        FF.cp(filetype,source,V.ctandir .. "/" .. V.ctanpkg)
      end
    else
      for _,filetype in pairs(files) do
        for file,_ in pairs(FF.tree(source,filetype)) do
          local path = FF.splitpath(file)
          local ctantarget = V.ctandir .. "/" .. V.ctanpkg .. "/"
            .. source .. "/" .. path
          FF.mkdir(ctantarget)
          FF.cp(file,source,ctantarget)
        end
      end
    end
  end
  for _,tab in pairs(
    {V.bibfiles,V.demofiles,V.docfiles,V.pdffiles,V.scriptmanfiles,V.typesetlist}) do
    copyfiles(tab,docfiledir)
  end
  copyfiles(V.sourcefiles,V.sourcefiledir)
  for _,file in pairs(V.textfiles) do
    FF.cp(file, V.textfiledir, V.ctandir .. "/" .. V.ctanpkg)
  end
end

L3.bundlectan = function (self)
  local errorlevel = self:install_files(V.tdsdir,true)
  if errorlevel ~=0 then return errorlevel end
  self:copyctan()
  return 0
end

L3.ctan = function (self)
  -- Always run tests for all engines
  self.options.engine = nil
  local function dirzip(dir, name)
    local zipname = name .. ".zip"
    local function tab_to_str(tab)
      local str = ""
      for _,i in ipairs(tab) do
        str = str .. " " .. "\"" .. i .. "\""
      end
      return str
    end
    -- Convert the tables of files to quoted strings
    local binfiles = tab_to_str(V.binaryfiles)
    local exclude = tab_to_str(V.excludefiles)
    -- First, zip up all of the text files
    FF.run(
      dir,
      V.zipexe .. " " .. V.zipopts .. " -ll ".. zipname .. " ."
        .. (
          (binfiles or exclude) and (" -x" .. binfiles .. " " .. exclude)
          or ""
        )
    )
    -- Then add the binary ones
    FF.run(
      dir,
      V.zipexe .. " " .. V.zipopts .. " -g ".. zipname .. " . -i" ..
        binfiles .. (exclude and (" -x" .. exclude) or "")
    )
  end
  local errorlevel
  local standalone = false
  if V.bundle == "" then
    standalone = true
  end
  if standalone then
    errorlevel = L3:call({"."},"check")
    V.bundle = V.module
  else
    errorlevel = L3:call(V.modules, "bundlecheck")
  end
  if errorlevel == 0 then
    FF.rmdir(V.ctandir)
    FF.mkdir(V.ctandir .. "/" .. V.ctanpkg)
    FF.rmdir(V.tdsdir)
    FF.mkdir(V.tdsdir)
    if standalone then
      errorlevel = self:install_files(V.tdsdir,true)
      if errorlevel ~=0 then return errorlevel end
      self:copyctan()
    else
      errorlevel = L3:call(V.modules, "bundlectan")
    end
  else
    print("\n====================")
    print("Tests failed, zip stage skipped!")
    print("====================\n")
    return errorlevel
  end
  if errorlevel == 0 then
    for _,i in ipairs(V.textfiles) do
      for _,j in pairs({V.unpackdir, V.textfiledir}) do
        FF.cp(i, j, V.ctandir .. "/" .. V.ctanpkg)
        FF.cp(i, j, V.tdsdir .. "/doc/" .. V.tdsroot .. "/" .. V.bundle)
      end
    end
    -- Rename README if necessary
    if V.ctanreadme ~= "" and not V.ctanreadme:lower():match("^readme%.%w+") then
      local newfile = "README." .. V.ctanreadme:match("%.(%w+)$")
      for _,dir in pairs({V.ctandir .. "/" .. V.ctanpkg,
      V.tdsdir .. "/doc/" .. V.tdsroot .. "/" .. V.bundle}) do
        if FF.fileexists(dir .. "/" .. V.ctanreadme) then
          FF.rm(dir,newfile)
          FF.ren(dir,V.ctanreadme,newfile)
        end
      end
    end
    dirzip(V.tdsdir, V.ctanpkg .. ".tds")
    if V.packtdszip then
      FF.cp(V.ctanpkg .. ".tds.zip", V.tdsdir, V.ctandir)
    end
    dirzip(V.ctandir, V.ctanzip)
    FF.cp(V.ctanzip .. ".zip", V.ctandir, V.currentdir)
  else
    print("\n====================")
    print("Typesetting failed, zip stage skipped!")
    print("====================\n")
  end
  return errorlevel
end

