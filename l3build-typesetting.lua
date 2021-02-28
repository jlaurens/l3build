--[[

File l3build-typesetting.lua Copyright (C) 2018-2020 The LaTeX Project

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

local print  = print

local gsub  = string.gsub
local match = string.match

local os_type = os.type

local util    = require("l3b.util")
local entries = util.entries
local items   = util.items
local values  = util.values

local fifu              = require("l3b.file-functions")
local cmd_concat        = fifu.cmd_concat
local run               = fifu.run
local directory_exists  = fifu.directory_exists
local absolute_path     = fifu.absolute_path
local file_exists       = fifu.file_exists
local job_name          = fifu.job_name
local remove_tree       = fifu.remove_tree
local copy_tree         = fifu.copy_tree
local make_clean_directory = fifu.make_clean_directory
local tree              = fifu.tree
local dir_base          = fifu.dir_base

function dvitopdf(name, dir, engine, hide)
  run(
    dir, cmd_concat(
      set_epoch_cmd(epoch, forcecheckepoch),
      "dvips " .. name .. dviext
        .. (hide and (" > " .. os_null) or ""),
      "ps2pdf " .. ps2pdfopt .. name .. psext
        .. (hide and (" > " .. os_null) or "")
    )
  )
end

-- An auxiliary used to set up the environmental variables
function runcmd(cmd, dir, vars)
  dir = dir or "."
  dir = absolute_path(dir)
  vars = vars or {}
  -- Allow for local texmf files
  local env = os_setenv .. " TEXMFCNF=." .. os_pathsep
  local localtexmf = ""
  if texmfdir and texmfdir ~= "" and directory_exists(texmfdir) then
    localtexmf = os_pathsep .. absolute_path(texmfdir) .. "//"
  end
  local envpaths = "." .. localtexmf .. os_pathsep
    .. absolute_path(localdir) .. os_pathsep
    .. dir .. (typesetsearch and os_pathsep or "")
  -- Deal with spaces in paths
  if os_type == "windows" and match(envpaths, " ") then
    envpaths = gsub(envpaths, '"', '')
  end
  for var in entries(vars) do
    env = cmd_concat(env, os_setenv .. " " .. var .. "=" .. envpaths)
  end
  return run(dir, cmd_concat(set_epoch_cmd(epoch, forcedocepoch), env, cmd))
end

function biber(name, dir)
  if file_exists(dir .. "/" .. name .. ".bcf") then
    return
      runcmd(biberexe .. " " .. biberopts .. " " .. name, dir, { "BIBINPUTS" })
  end
  return 0
end

function bibtex(name, dir)
  dir = dir or "."
  if file_exists(dir .. "/" .. name .. ".aux") then
    -- LaTeX always generates an .aux file, so there is a need to
    -- look inside it for a \citation line
    local grep
    if os_type == "windows" then
      grep = "\\\\"
    else
     grep = "\\\\\\\\"
    end
    if run(dir,
        os_grepexe .. " \"^" .. grep .. "citation{\" " .. name .. ".aux > "
          .. os_null
      ) + run(dir,
        os_grepexe .. " \"^" .. grep .. "bibdata{\" " .. name .. ".aux > "
          .. os_null
      ) == 0 then
      return runcmd(bibtexexe .. " " .. bibtexopts .. " " .. name, dir,
        { "BIBINPUTS", "BSTINPUTS" })
    end
  end
  return 0
end

function makeindex(name, dir, inext, outext, logext, style)
  dir = dir or "."
  if file_exists(dir .. "/" .. name .. inext) then
    if style == "" then style = nil end
    return runcmd(makeindexexe .. " " .. makeindexopts
      .. " -o " .. name .. outext
      .. (style and (" -s " .. style) or "")
      .. " -t " .. name .. logext .. " "  .. name .. inext,
      dir,
      { "INDEXSTYLE" })
  end
  return 0
end

function tex(file, dir, cmd)
  dir = dir or "."
  cmd = cmd or typesetexe .. typesetopts
  return runcmd(cmd .. " \"" .. typesetcmds
    .. "\\input " .. file .. "\"",
    dir, { "TEXINPUTS", "LUAINPUTS" })
end

local function typesetpdf(file, dir)
  dir = dir or "."
  local name = job_name(file)
  print("Typesetting " .. name)
  local fn = typeset
  local cmd = typesetexe .. " " .. typesetopts
  if specialtypesetting and specialtypesetting[file] then
    fn = specialtypesetting[file].func or fn
    cmd = specialtypesetting[file].cmd or cmd
  end
  local errorlevel = fn(file, dir, cmd)
  if errorlevel ~= 0 then
    print(" ! Compilation failed")
    return errorlevel
  end
  local pdfname = name .. pdfext
  remove_tree(docfiledir, pdfname)
  return copy_tree(pdfname, dir, docfiledir)
end

typeset = typeset or function(file, dir, exe)
  dir = dir or "."
  local errorlevel = tex(file, dir, exe)
  if errorlevel ~= 0 then
    return errorlevel
  end
  local name = job_name(file)
  errorlevel = biber(name, dir) + bibtex(name, dir)
  if errorlevel ~= 0 then
    return errorlevel
  end
  for i = 2, typesetruns do
    errorlevel =
      makeindex(name, dir, ".glo", ".gls", ".glg", glossarystyle) +
      makeindex(name, dir, ".idx", ".ind", ".ilg", indexstyle)    +
      tex(file, dir, exe)
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
  make_clean_directory(typesetdir)
  for filetype in items(
    bibfiles, docfiles, typesetfiles, typesetdemofiles
  ) do
    for file in entries(filetype) do
      copy_tree(file, docfiledir, typesetdir)
    end
  end
  for file in entries(sourcefiles) do
    copy_tree(file, sourcefiledir, typesetdir)
  end
  for file in entries(typesetsuppfiles) do
    copy_tree(file, supportdir, typesetdir)
  end
  dep_install(typesetdeps)
  unpack({ sourcefiles, typesetsourcefiles }, { sourcefiledir, docfiledir })
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
  for typesetfiles in items(typesetdemofiles, typesetfiles) do
    for glob in entries(typesetfiles) do
      for dir in items(typesetdir, unpackdir) do
        for p_cwd in values(tree(dir, glob)) do
          local path, srcname = dir_base(p_cwd)
          local name = job_name(srcname)
          if not done[name] then
            local typeset = true
            -- Allow for command line selection of files
            if files and next(files) then
              typeset = false
              for file in entries(files) do
                if name == file then
                  typeset = true
                  break
                end
              end
            end
            -- Now know if we should typeset this source
            if typeset then
              errorlevel = typesetpdf(srcname, path)
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

