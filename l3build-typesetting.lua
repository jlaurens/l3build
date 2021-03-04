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
local chooser     = utlib.chooser
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

---@type l3b_vars_t
local l3b_vars  = require("l3b.variables")
---@type Main_t
local Main      = l3b_vars.Main
---@type Xtn_t
local Xtn       = l3b_vars.Xtn
---@type Dir_t
local Dir       = l3b_vars.Dir
---@type Exe_t
local Exe       = l3b_vars.Exe
---@type Opts_t
local Opts      = l3b_vars.Opts
---@type Files_t
local Files     = l3b_vars.Files
---@type Deps_t
local Deps      = l3b_vars.Deps

--@type l3b_aux_t
local l3b_aux       = require("l3b.aux")
local set_epoch_cmd = l3b_aux.set_epoch_cmd
local deps_install  = l3b_aux.deps_install

--@type l3b_unpack_t
local l3b_unpack  = require("l3b.unpack")
local unpack      = l3b_unpack.unpack

---@class l3b_tpst_vars_t
---@field typesetruns   integer
---@field typesetcmds   string
---@field ps2pdfopt     string
---@field typesetsearch boolean
---@field glossarystyle string
---@field indexstyle    string
---@field specialtypesetting table
---@field forcedocepoch string

---@type l3b_tpst_vars_t
local Vars = chooser(_G, {
  typesetruns = 3,
  typesetcmds = "",
  ps2pdfopt = "",
  -- Enable access to trees outside of the repo
  -- As these may be set false, a more elaborate test than normal is needed
  typesetsearch = true,
  -- Additional settings to fine-tune typesetting
  glossarystyle = "gglo.ist",
  indexstyle    = "gind.ist",
  specialtypesetting = {},
  forcedocepoch   = false,
  [utlib.DID_CHOOSE] = function (result, k)
    -- No trailing /
    -- What about the leading "./"
    if k == "forcedocepoch" then
      local options = l3build.options
      if options["epoch"] then
        return true
      end
    end
    return result
  end,
})

---dvitopdf
---@param name string
---@param dir string
---@param engine string
---@param hide boolean
---@return error_level_t
local function dvitopdf(name, dir, engine, hide)
  return run(
    dir, cmd_concat(
      set_epoch_cmd(Main.epoch, Main.forcecheckepoch),
      "dvips " .. name .. Xtn.dvi
        .. (hide and (" > " .. os_null) or ""),
      "ps2pdf " .. Vars.ps2pdfopt .. name .. Xtn.ps
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
  if Dir.texmf and Dir.texmf ~= "" and directory_exists(Dir.texmf) then
    localtexmf = os_pathsep .. absolute_path(Dir.texmf) .. "//"
  end
  local envpaths = "." .. localtexmf .. os_pathsep
    .. absolute_path(Dir[l3b_vars.LOCAL]) .. os_pathsep
    .. dir .. (Vars.typesetsearch and os_pathsep or "")
  -- Deal with spaces in paths
  if os_type == "windows" and match(envpaths, " ") then
    envpaths = first_of(gsub(envpaths, '"', '')) -- no '"' in windows!!!
  end
  for var in entries(vars) do
    env = cmd_concat(env, os_setenv .. " " .. var .. "=" .. envpaths)
  end
  return run(dir, cmd_concat(set_epoch_cmd(Main.epoch, Vars.forcedocepoch), env, cmd))
end

local MT = {}

---biber
---@param name string
---@param dir string
---@return error_level_t
function MT.biber(name, dir)
  if file_exists(dir .. "/" .. name .. ".bcf") then
    return
      runcmd(Exe.biber .. " " .. Opts.biber .. " " .. name, dir, { "BIBINPUTS" })
        and 0 or 1
  end
  return 0
end

---comment
---@param name string
---@param dir string
---@return error_level_t
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
      return runcmd(Exe.bibtex .. " " .. Opts.bibtex .. " " .. name, dir,
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
---@return error_level_t
function MT.makeindex(name, dir, in_ext, out_ext, log_ext, style)
  dir = dir or "."
  if file_exists(dir .. "/" .. name .. in_ext) then
    if style == "" then style = nil end
    return runcmd(Exe.makeindex .. " " .. Opts.makeindex
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
---@return error_level_t
function MT.tex(file, dir, cmd)
  dir = dir or "."
  cmd = cmd or Exe.typeset .. Opts.typeset
  return runcmd(cmd .. " \"" .. Vars.typesetcmds
    .. "\\input " .. file .. "\"",
    dir, { "TEXINPUTS", "LUAINPUTS" }) and 0 or 1
end

-- Ctrl.foo is _G.foo if it is a function, 
-- TODO: Use chooser here
local Ctrl = setmetatable({}, {
  __index = function (t, k)
    local MT_k = MT[k]
    if MT_k ~= nil then -- only keys interactive MT are recognized
      local _G_k = _G[k]
      local result = type(_G_k) == "function" and _G_k or MT_k
        local options = l3build.options
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
---@return error_level_t
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
  for i = 2, Vars.typesetruns do
    error_level = Ctrl.makeindex(name, dir, ".glo", ".gls", ".glg", Vars.glossarystyle)
                + Ctrl.makeindex(name, dir, ".idx", ".ind", ".ilg", Vars.indexstyle)
                + Ctrl.tex(file, dir, cmd)
    if error_level ~= 0 then break end
  end
  return error_level
end

---Local helper
---@param file string
---@param dir string
---@return error_level_t
local function typesetpdf(file, dir)
  dir = dir or "."
  local name = job_name(file)
  print("Typesetting " .. name)
  local func  = Ctrl.typeset
  local cmd   = Exe.typeset .. " " .. Opts.typeset
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
  local pdf_name = name .. Xtn.pdf
  remove_tree(Dir.docfile, pdf_name)
  return copy_tree(pdf_name, dir, Dir.docfile)
end

---Do nothing function
---@return error_level_t
function MT.typeset_demo_tasks()
  return 0
end

---Do nothing function
---@return error_level_t
function MT.docinit_hook()
  return 0
end

---comment
---@return error_level_t
local function docinit()
  -- Set up
  make_clean_directory(Dir.typeset)
  for filetype in items(
    Files.bib, Files.doc, Files.typeset, Files.typesetdemo
  ) do
    for file in entries(filetype) do
      copy_tree(file, Dir.docfile, Dir.typeset)
    end
  end
  for file in entries(Files.source) do
    copy_tree(file, Dir.sourcefile, Dir.typeset)
  end
  for file in entries(Files.typesetsupp) do
    copy_tree(file, Dir.support, Dir.typeset)
  end
  deps_install(Deps.typeset)
  unpack({ Files.source, Files.typesetsource }, { Dir.sourcefile, Dir.docfile })
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
---@return error_level_t
local function doc(files)
  local error_level = docinit()
  if error_level ~= 0 then return error_level end
  local done = {}
  for typeset_files in items(Files.typesetdemo, Files.typeset) do
    for glob in entries(typeset_files) do
      for dir in items(Dir.typeset, Dir.unpack) do
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

---@class l3b_typesetting_t
---@field dvitopdf  fun(name: string, dir: string, engine: string, hide: boolean): integer
---@field runcmd    fun(cmd:  string, dir: string, vars: table): boolean?, exitcode?, integer?
---@field doc       fun(files: string_list_t): integer
---@field bibtex    fun(name: string, dir: string): integer
---@field biber     fun(name: string, dir: string): integer
---@field tex       fun(name: string, dir: string, cmd: string): integer
---@field makeindex fun(name: string, dir: string, in_ext: string, out_ext: string, log_ext: string, style: string): integer

return {
  dvitopdf          = dvitopdf,
  runcmd            = runcmd,
  doc               = doc,
  bibtex            = Ctrl.bibtex,
  biber             = Ctrl.biber,
  tex               = Ctrl.tex,
  makeindex         = Ctrl.makeindex,
}
