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

local os_type = os["type"]

---@type utlib_t
local utlib       = require("l3b.utillib")
local entries     = utlib.entries
local items       = utlib.items
local values      = utlib.values
local first_of    = utlib.first_of
local extend_with = utlib.extend_with

---@type wklib_t
local wklib             = require("l3b.walklib")
local job_name          = wklib.job_name
local dir_base          = wklib.dir_base

---@type oslib_t
local oslib             = require("l3b.oslib")
local cmd_concat        = oslib.cmd_concat
local run               = oslib.run

---@type fslib_t
local fslib             = require("l3b.fslib")
local directory_exists  = fslib.directory_exists
local absolute_path     = fslib.absolute_path
local file_exists       = fslib.file_exists
local remove_tree       = fslib.remove_tree
local copy_tree         = fslib.copy_tree
local make_clean_directory = fslib.make_clean_directory
local tree              = fslib.tree

--@type l3b_aux_t
local l3b_aux = require("l3b.aux")
local set_epoch_cmd = l3b_aux.set_epoch_cmd
local dep_install = l3b_aux.dep_install

---dvitopdf
---@param name string
---@param dir string
---@param engine string
---@param hide boolean
---@return integer
local function dvitopdf(name, dir, engine, hide)
  return run(
    dir, cmd_concat(
      set_epoch_cmd(epoch, forcecheckepoch),
      "dvips " .. name .. dviext
        .. (hide and (" > " .. os_null) or ""),
      "ps2pdf " .. ps2pdfopt .. name .. psext
        .. (hide and (" > " .. os_null) or "")
    ) and 0 or 1
  )
end

-- An auxiliary used to set up the environmental variables
---comment
---@param cmd string
---@param dir string
---@param vars table
---@return boolean?  suc
---@return exitcode? exitcode
---@return integer?  code
local function runcmd(cmd, dir, vars)
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
    envpaths = first_of(gsub(envpaths, '"', '')) -- no '"' in windows!!!
  end
  for var in entries(vars) do
    env = cmd_concat(env, os_setenv .. " " .. var .. "=" .. envpaths)
  end
  return run(dir, cmd_concat(set_epoch_cmd(epoch, forcedocepoch), env, cmd))
end

---biber
---@param name string
---@param dir string
---@return integer
local function biber(name, dir)
  if file_exists(dir .. "/" .. name .. ".bcf") then
    return
      runcmd(biberexe .. " " .. biberopts .. " " .. name, dir, { "BIBINPUTS" })
      and 0 or 1
  end
  return 0
end

---comment
---@param name string
---@param dir string
---@return integer
local function bibtex(name, dir)
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
        { "BIBINPUTS", "BSTINPUTS" }) and 0 or 1
    end
  end
  return 0
end

---comment
---@param name string
---@param dir string
---@param inext string
---@param outext string
---@param logext string
---@param style string
---@return integer
local function makeindex(name, dir, inext, outext, logext, style)
  dir = dir or "."
  if file_exists(dir .. "/" .. name .. inext) then
    if style == "" then style = nil end
    return runcmd(makeindexexe .. " " .. makeindexopts
      .. " -o " .. name .. outext
      .. (style and (" -s " .. style) or "")
      .. " -t " .. name .. logext .. " "  .. name .. inext,
      dir,
      { "INDEXSTYLE" }) and 0 or 1
  end
  return 0
end

---TeX
---@param file string
---@param dir string
---@param cmd string
---@return integer
local function tex(file, dir, cmd)
  dir = dir or "."
  cmd = cmd or typesetexe .. typesetopts
  return runcmd(cmd .. " \"" .. typesetcmds
    .. "\\input " .. file .. "\"",
    dir, { "TEXINPUTS", "LUAINPUTS" }) and 0 or 1
end

---typeset
---@param file string
---@param dir string
---@param cmd string
---@return integer
local function typeset(file, dir, cmd)
  dir = dir or "."
  local error_level = tex(file, dir, cmd)
  if error_level ~= 0 then
    return error_level
  end
  local name = job_name(file)
  error_level = biber(name, dir) + bibtex(name, dir)
  if error_level ~= 0 then
    return error_level
  end
  for i = 2, typesetruns do
    error_level =
      makeindex(name, dir, ".glo", ".gls", ".glg", glossarystyle) +
      makeindex(name, dir, ".idx", ".ind", ".ilg", indexstyle)    +
      tex(file, dir, cmd)
    if error_level ~= 0 then break end
  end
  return error_level
end

---Local
---@param file string
---@param dir string
---@return integer
local function typesetpdf(file, dir)
  dir = dir or "."
  local name = job_name(file)
  print("Typesetting " .. name)
  local func = _G.typeset or typeset
  local cmd = typesetexe .. " " .. typesetopts
  local special = specialtypesetting and specialtypesetting[file]
  if special then
    func = special.func or func
    cmd = special.cmd or cmd
  end
  local error_level = func(file, dir, cmd)
  if error_level ~= 0 then
    print(" ! Compilation failed")
    return error_level
  end
  local pdf_name = name .. pdfext
  remove_tree(docfiledir, pdf_name)
  return copy_tree(pdf_name, dir, docfiledir)
end

---@alias typeset_demo_tasks_t fun(): integer
---@alias docinit_hook_t fun(): integer

---comment
---@return integer
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
  ---@type typeset_demo_tasks_t
  local typeset_demo_tasks = _G.typeset_demo_tasks
  local error_level = typeset_demo_tasks and typeset_demo_tasks() or 0
  if error_level ~= 0 then
    return error_level
  end
  ---@type docinit_hook_t
  local docinit_hook = _G.docinit_hook
  return docinit_hook and docinit_hook() or 0
end

---Typeset all required documents
---Uses a set of dedicated auxiliaries that need to be available to others
---@param files table<integer, string>
---@return integer
local function doc(files)
  local error_level = docinit()
  if error_level ~= 0 then return error_level end
  local done = {}
  for typeset_files in items(typesetdemofiles, typesetfiles) do
    for glob in entries(typeset_files) do
      for dir in items(typesetdir, unpackdir) do
        for p_cwd in values(tree(dir, glob)) do
          local path, srcname = dir_base(p_cwd)
          local name = job_name(srcname)
          if not done[name] then
            local should_typeset = true
            -- Allow for command line selection of files
            if files and next(files) then
              should_typeset = false
              for file in entries(files) do
                if name == file then
                  should_typeset = true
                  break
                end
              end
            end
            -- Now know if we should typeset this source
            if should_typeset then
              error_level = typesetpdf(srcname, path)
              if error_level ~= 0 then
                return error_level
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

-- this is the map to export function symbols to the global space
local global_symbol_map = {
  runcmd = runcmd,
  biber = biber,
  bibtex = bibtex,
  makeindex = makeindex,
  tex = tex,
  typeset = typeset,
  doc = doc,
}

--[=[ Export function symbols ]=]
extend_with(_G, global_symbol_map)
-- [=[ ]=]

---@class l3b_typesetting_t
---@field dvitopdf fun(name: string, dir: string, engine: string, hide: boolean): integer
---@field runcmd fun(cmd string, dir string, vars table): boolean? suc, exitcode? exitcode, integer? code
---@field biber fun(name: string, dir string): integer
---@field bibtex fun(name: string, dir string): integer
---@field makeindex fun(name: string, dir: string, inext: string, outext: string, logext: string, style: string):integer
---@field tex fun(file: string, dir: string, cmd: string): integer
---@field typeset fun(file: string, dir: string, cmd: string): integer
---@field doc fun(files: table<integer, string>): integer

return {
  global_symbol_map = {},
  dvitopdf = dvitopdf,
  runcmd = runcmd,
  biber = biber,
  bibtex = bibtex,
  makeindex = makeindex,
  tex = tex,
  typeset = typeset,
  doc = doc,
}
