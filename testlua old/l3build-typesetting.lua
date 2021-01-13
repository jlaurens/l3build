--[[

File l3build-typesetting.lua Copyright (C) 2018-2020 The LaTeX3 Project

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

--
-- Auxiliary functions for typesetting: need to be generally available
--

local FF = L3.require('file-functions')

local ipairs = ipairs
local pairs  = pairs
local print  = print

local gsub  = string.gsub
local match = string.match

function dvitopdf(name, dir, engine, hide)
  FF.run(
    dir,
    (forcecheckepoch and L3:setepoch() or "") ..
    "dvips " .. name .. dviext
      .. (hide and (" > " .. FF.os_null) or "")
      .. FF.os_concat ..
   "ps2pdf " .. ps2pdfopt .. name .. psext
      .. (hide and (" > " .. FF.os_null) or "")
  )
end

-- An auxiliary used to set up the environmental variables
function runcmd(cmd,dir,vars)
  local dir = dir or "."
  local dir = FF.abspath(dir)
  local vars = vars or {}
  -- Allow for local texmf files
  local env = FF.os_setenv .. " TEXMFCNF=." .. FF.os_pathsep
  local localtexmf = ""
  if texmfdir and texmfdir ~= "" and FF.direxists(texmfdir) then
    localtexmf = FF.os_pathsep .. FF.abspath(texmfdir) .. "//"
  end
  local envpaths = "." .. localtexmf .. FF.os_pathsep
    .. FF.abspath(localdir) .. FF.os_pathsep
    .. dir .. (typesetsearch and FF.os_pathsep or "")
  -- Deal with spaces in paths
  if os.type == "windows" and match(envpaths," ") then
    envpaths = gsub(envpaths,'"','')
  end
  for _,var in pairs(vars) do
    env = env .. FF.os_concat .. FF.os_setenv .. " " .. var .. "=" .. envpaths
  end
  return run(dir,(forcedocepoch and L3:setepoch() or "") .. env .. FF.os_concat .. cmd)
end

function biber(name,dir)
  if FF.fileexists(dir .. "/" .. name .. ".bcf") then
    return
      runcmd(biberexe .. " " .. biberopts .. " " .. name,dir,{"BIBINPUTS"})
  end
  return 0
end

function bibtex(name,dir)
  local dir = dir or "."
  if FF.fileexists(dir .. "/" .. name .. ".aux") then
    -- LaTeX always generates an .aux file, so there is a need to
    -- look inside it for a \citation line
    local grep
    if os.type == "windows" then
      grep = "\\\\"
    else
     grep = "\\\\\\\\"
    end
    if FF.run(dir,
        FF.os_grepexe .. " \"^" .. grep .. "citation{\" " .. name .. ".aux > "
          .. FF.os_null
      ) + FF.run(dir,
        FF.os_grepexe .. " \"^" .. grep .. "bibdata{\" " .. name .. ".aux > "
          .. FF.os_null
      ) == 0 then
      return runcmd(bibtexexe .. " " .. bibtexopts .. " " .. name,dir,
        {"BIBINPUTS","BSTINPUTS"})
    end
  end
  return 0
end

function makeindex(name,dir,inext,outext,logext,style)
  local dir = dir or "."
  if FF.fileexists(dir .. "/" .. name .. inext) then
    if style == "" then style = nil end
    return runcmd(makeindexexe .. " " .. makeindexopts
      .. " -o " .. name .. outext
      .. (style and (" -s " .. style) or "")
      .. " -t " .. name .. logext .. " "  .. name .. inext,
      dir,
      {"INDEXSTYLE"})
  end
  return 0
end

function tex(file,dir,cmd)
  local dir = dir or "."
  local cmd = cmd or typesetexe .. typesetopts
  return runcmd(cmd .. " \"" .. typesetcmds
    .. "\\input " .. file .. "\"",
    dir,{"TEXINPUTS","LUAINPUTS"})
end

local function typesetpdf(file,dir)
  local dir = dir or "."
  local name = FF.jobname(file)
  print("Typesetting " .. name)
  local fn = typeset
  local cmd = typesetexe .. " " .. typesetopts
  if specialtypesetting and specialtypesetting[file] then
    fn = specialtypesetting[file].func or fn
    cmd = specialtypesetting[file].cmd or cmd
  end
  local errorlevel = fn(file,dir,cmd)
  if errorlevel ~= 0 then
    print(" ! Compilation failed")
    return errorlevel
  end
  pdfname = name .. pdfext
  FF.rm(docfiledir,pdfname)
  return FF.cp(pdfname,dir,docfiledir)
end

typeset = typeset or function(file,dir,exe)
  dir = dir or "."
  local errorlevel = tex(file,dir,exe)
  if errorlevel ~= 0 then
    return errorlevel
  end
  local name = FF.jobname(file)
  errorlevel = biber(name,dir) + bibtex(name,dir)
  if errorlevel ~= 0 then
    return errorlevel
  end
  for i = 2,typesetruns do
    errorlevel =
      makeindex(name,dir,".glo",".gls",".glg",glossarystyle) +
      makeindex(name,dir,".idx",".ind",".ilg",indexstyle)    +
      tex(file,dir,exe)
    if errorlevel ~= 0 then break end
  end
  return errorlevel
end

-- A hook to allow additional typesetting of demos
typeset_demo_tasks = typeset_demo_tasks or function()
  return 0
end

local function docinit()
  -- Set up
  FF.cleandir(typesetdir)
  for _,filetype in pairs(
      {bibfiles, docfiles, typesetfiles, typesetdemofiles}
    ) do
    for _,file in pairs(filetype) do
      FF.cp(file, docfiledir, typesetdir)
    end
  end
  for _,file in pairs(sourcefiles) do
    FF.cp(file, sourcefiledir, typesetdir)
  end
  for _,file in pairs(typesetsuppfiles) do
    FF.cp(file, supportdir, typesetdir)
  end
  depinstall(typesetdeps)
  unpack({sourcefiles, typesetsourcefiles}, {sourcefiledir, docfiledir})
  -- Main loop for doc creation
  local errorlevel = typeset_demo_tasks()
  if errorlevel ~= 0 then
    return errorlevel
  end
  return docinit_hook()
end

docinit_hook = docinit_hook or function() return 0 end

-- Typeset all required documents
-- Uses a set of dedicated auxiliaries that need to be available to others
function doc(files)
  local errorlevel = docinit()
  if errorlevel ~= 0 then return errorlevel end
  local done = {}
  for _,typesetfiles in ipairs({typesetdemofiles,typesetfiles}) do
    for _,glob in pairs(typesetfiles) do
      for _,dir in ipairs({typesetdir,unpackdir}) do
        for _,file in pairs(FF.tree(dir,glob)) do
          local path,srcname = FF.splitpath(file)
          local name = FF.jobname(srcname)
          if not done[name] then
            local typeset = true
            -- Allow for command line selection of files
            if files and next(files) then
              typeset = false
              for _,file in pairs(files) do
                if name == file then
                  typeset = true
                  break
                end
              end
            end
            -- Now know if we should typeset this source
            if typeset then
              local errorlevel = typesetpdf(srcname,path)
              if errorlevel ~= 0 then
                return errorlevel
              else
                done[name] = true
              end
            end
          end
        end
      end
    end
  end
  return 0
end

