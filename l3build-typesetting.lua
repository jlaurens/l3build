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

--@type l3build_t
local l3build = require("l3build")
local options = l3build.options

--@type l3b_aux_t
local l3b_aux       = require("l3b.aux")
local set_epoch_cmd = l3b_aux.set_epoch_cmd
local dep_install   = l3b_aux.dep_install

--@type l3b_unpack_t
local l3b_unpack  = require("l3b.unpack")
local unpack      = l3b_unpack.unpack

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

local MT = {}

---biber
---@param name string
---@param dir string
---@return integer
function MT.biber(name, dir)
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
function MT.bibtex(name, dir)
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
---@param in_ext string
---@param out_ext string
---@param log_ext string
---@param style string
---@return integer
function MT.makeindex(name, dir, in_ext, out_ext, log_ext, style)
  dir = dir or "."
  if file_exists(dir .. "/" .. name .. in_ext) then
    if style == "" then style = nil end
    return runcmd(makeindexexe .. " " .. makeindexopts
      .. " -o " .. name .. out_ext
      .. (style and (" -s " .. style) or "")
      .. " -t " .. name .. log_ext .. " "  .. name .. in_ext,
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
function MT.tex(file, dir, cmd)
  dir = dir or "."
  cmd = cmd or typesetexe .. typesetopts
  return runcmd(cmd .. " \"" .. typesetcmds
    .. "\\input " .. file .. "\"",
    dir, { "TEXINPUTS", "LUAINPUTS" }) and 0 or 1
end

-- Ctrl.foo is _G.foo if it is a function, 
local Ctrl = setmetatable({}, {
  __index = function (t, k)
    local MT_k = MT[k]
    if MT_k ~= nil then -- only keys interactive MT are recognized
      local _G_k = _G[k]
      local result = type(_G_k) == "function" and _G_k or MT_k
      if not options.__disable_engine_cache then -- disable engine cache from the command line
        t[k] = result
      end
      return result
    end
  end
})

---typeset
---@param file string
---@param dir string
---@param cmd string
---@return integer
function MT.typeset(file, dir, cmd)
  dir = dir or "."
  local error_level = Ctrl.tex(file, dir, cmd)
  if error_level ~= 0 then
    return error_level
  end
  local name = job_name(file)
  error_level = Ctrl.biber(name, dir) + Ctrl.bibtex(name, dir)
  if error_level ~= 0 then
    return error_level
  end
  for i = 2, typesetruns do
    error_level = Ctrl.makeindex(name, dir, ".glo", ".gls", ".glg", glossarystyle)
                + Ctrl.makeindex(name, dir, ".idx", ".ind", ".ilg", indexstyle)
                + Ctrl.tex(file, dir, cmd)
    if error_level ~= 0 then break end
  end
  return error_level
end

---Local helper
---@param file string
---@param dir string
---@return integer
local function typesetpdf(file, dir)
  dir = dir or "."
  local name = job_name(file)
  print("Typesetting " .. name)
  local func = Ctrl.typeset
  local cmd = _G.typesetexe .. " " .. _G.typesetopts
  local special = _G.specialtypesetting and _G.specialtypesetting[file]
  if special then
    func = special.func or func
    cmd  = special.cmd  or cmd
  end
  local error_level = func(file, dir, cmd)
  if error_level ~= 0 then
    print(" ! Compilation failed")
    return error_level
  end
  local pdf_name = name .. _G.pdfext
  remove_tree(_G.docfiledir, pdf_name)
  return copy_tree(pdf_name, dir, _G.docfiledir)
end

---Do nothing function
---@return integer
function MT.typeset_demo_tasks()
  return 0
end

---Do nothing function
---@return integer
function MT.docinit_hook()
  return 0
end

---comment
---@return integer
local function docinit()
  -- Set up
  make_clean_directory(_G.typesetdir)
  for filetype in items(
    _G.bibfiles, _G.docfiles, _G.typesetfiles, _G.typesetdemofiles
  ) do
    for file in entries(filetype) do
      copy_tree(file, _G.docfiledir, _G.typesetdir)
    end
  end
  for file in entries(_G.sourcefiles) do
    copy_tree(file, _G.sourcefiledir, _G.typesetdir)
  end
  for file in entries(_G.typesetsuppfiles) do
    copy_tree(file, _G.supportdir, _G.typesetdir)
  end
  dep_install(_G.typesetdeps)
  unpack({ _G.sourcefiles, _G.typesetsourcefiles }, { _G.sourcefiledir, _G.docfiledir })
  -- Main loop for doc creation
  local error_level = Ctrl.typeset_demo_tasks()
  if error_level ~= 0 then
    return error_level
  end
  return Ctrl.docinit_hook()
end

---Typeset all required documents
---Uses a set of dedicated auxiliaries that need to be available to others
---@param files string_list_t
---@return integer
local function doc(files)
  local error_level = docinit()
  if error_level ~= 0 then return error_level end
  local done = {}
  for typeset_files in items(_G.typesetdemofiles, _G.typesetfiles) do
    for glob in entries(typeset_files) do
      for dir in items(_G.typesetdir, _G.unpackdir) do
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
  runcmd = runcmd, -- dtx
  doc = doc,
}

--[=[ Export function symbols ]=]
extend_with(_G, global_symbol_map)
-- [=[ ]=]

---@class l3b_typesetting_t
---@field dvitopdf  fun(name: string, dir: string, engine: string, hide: boolean): integer
---@field runcmd    fun(cmd:  string, dir: string, vars: table): boolean?, exitcode?, integer?
---@field doc       fun(files: string_list_t): integer

return {
  global_symbol_map = global_symbol_map,
  dvitopdf          = dvitopdf,
  runcmd            = runcmd,
  doc               = doc,
}
