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

local print     = print

local not_empty = next
local gsub      = string.gsub
local match     = string.match

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
local remove_name       = fslib.remove_name
local copy_name         = fslib.copy_name
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
---@field typesetsearch boolean Switch to search the system \texttt{texmf} for during typesetting
---@field glossarystyle string  MakeIndex style file for glossary/changes creation
---@field indexstyle    string  MakeIndex style for index creation
---@field specialtypesetting table  Non-standard typesetting combinations
---@field forcedocepoch string  Force epoch when typesetting
---@field typesetcmds   string  Instructions to be passed to \TeX{} when doing typesetting
---@field typesetruns   integer Number of cycles of typesetting to carry out
---@field ps2pdfopt     string  Options for \texttt{ps2pdf}

---@type l3b_tpst_vars_t
local Vars = chooser(_G, {
  typesetruns         = 3,
  typesetcmds         = "",
  -- Enable access to trees outside of the repo
  -- As these may be set false, a more elaborate test than normal is needed
  typesetsearch       = true,
  -- Additional settings to fine-tune typesetting
  glossarystyle       = "gglo.ist",
  indexstyle          = "gind.ist",
  specialtypesetting  = {},
  forcedocepoch       = false,
  ps2pdfopt           = "",
  [utlib.KEY_did_choose]  = function (t, k, result)
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

---dvi2pdf, used while checking
---@param name string
---@param dir string
---@param engine string
---@param hide boolean
---@return error_level_t
local function dvi2pdf(name, dir, engine, hide)
  return run(
    dir, cmd_concat(
      set_epoch_cmd(Main.epoch, Main.forcecheckepoch),
      "dvips " .. name .. Xtn.dvi
        .. (hide and (" > " .. _G.os_null) or ""),
      "ps2pdf " .. Vars.ps2pdfopt .. name .. Xtn.ps
        .. (hide and (" > " .. _G.os_null) or "")
    ) and 0 or 1
  )
end

-- An auxiliary used to set up the environmental variables
---comment
---@param cmd   string
---@param dir?  string
---@param vars? table
---@return boolean?  suc
---@return exitcode? exitcode
---@return integer?  code
local function runcmd(cmd, dir, vars)
  dir = dir or "."
  dir = absolute_path(dir)
  vars = vars or {}
  -- Allow for local texmf files
  local env = _G.os_setenv .. " TEXMFCNF=." .. _G.os_pathsep
  local localtexmf = ""
  if Dir.texmf and Dir.texmf ~= "" and directory_exists(Dir.texmf) then
    localtexmf = _G.os_pathsep .. absolute_path(Dir.texmf) .. "//"
  end
  local envpaths = "." .. localtexmf .. _G.os_pathsep
    .. absolute_path(Dir[l3b_vars.LOCAL]) .. _G.os_pathsep
    .. dir .. (Vars.typesetsearch and _G.os_pathsep or "")
  -- Deal with spaces in paths
  if os_type == "windows" and match(envpaths, " ") then
    envpaths = first_of(gsub(envpaths, '"', '')) -- no '"' in windows!!!
  end
  for var in entries(vars) do
    env = cmd_concat(env, _G.os_setenv .. " " .. var .. "=" .. envpaths)
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
---@param dir? string
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
        _G.os_grepexe .. " \"^" .. grep .. "citation{\" " .. name .. ".aux > "
          .. _G.os_null
      ) + run(dir,
        _G.os_grepexe .. " \"^" .. grep .. "bibdata{\" " .. name .. ".aux > "
          .. _G.os_null
      ) == 0 then
      return runcmd(Exe.bibtex .. " " .. Opts.bibtex .. " " .. name, dir,
        { "BIBINPUTS", "BSTINPUTS" }) and 0 or 1
    end
  end
  return 0
end

---comment
---@param name string
---@param dir? string
---@param in_ext string
---@param out_ext string
---@param log_ext string
---@param style string
---@return error_level_t
function MT.makeindex(name, dir, in_ext, out_ext, log_ext, style)
  dir = dir or "." -- Why is it optional ?
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

-- The engine controller:
---@class Ngn_t
---@field tex                 fun(file: string, dir?: string, cmd?: string): error_level_t
---@field typeset             fun(file: string, dir?: string, cmd?: string): error_level_t
---@field typeset_demo_tasks  fun(): error_level_t
---@field doc_init_hook       fun(): error_level_t
---@field bibtex              fun(file: string, dir?: string, cmd?: string): error_level_t
---@field biber               fun(file: string, dir?: string, cmd?: string): error_level_t
---@field makeindex           fun(name: string, dir?: string, in_ext: string, out_ext: string, log_ext: string, style: string): error_level_t

-- Ngn.foo is _G.foo if it is a function, MF.foo otherwise.
-- Only fo known keys
---@type Ngn_t
local Ngn = chooser(_G, MT, {
  index = function (t, k)
    if k == "tex" then --- tex is already a table in texlua.
      if type(_G[k]) == "table" then
        return MT[k]
      end
    end
  end
})

---TeX
---@param file string
---@param dir? string
---@param cmd? string
---@return error_level_t
function MT.tex(file, dir, cmd)
  dir = dir or "."
  cmd = cmd or Exe.typeset .. Opts.typeset
  return runcmd(cmd .. " \"" .. Vars.typesetcmds
    .. "\\input " .. file .. "\"",
    dir, { "TEXINPUTS", "LUAINPUTS" }) and 0 or 1
end

---typeset
---@param file string
---@param dir? string
---@param cmd string
---@return error_level_t
function MT.typeset(file, dir, cmd)
  dir = dir or "."
  local error_level = Ngn.tex(file, dir, cmd)
  if error_level ~= 0 then
    return error_level
  end
  local name = job_name(file)
  error_level = Ngn.biber(name, dir) + Ngn.bibtex(name, dir)
  if error_level ~= 0 then
    return error_level
  end
  for i = 2, Vars.typesetruns do
    error_level = Ngn.makeindex(name, dir, ".glo", ".gls", ".glg", Vars.glossarystyle)
                + Ngn.makeindex(name, dir, ".idx", ".ind", ".ilg", Vars.indexstyle)
                + Ngn.tex(file, dir, cmd)
    if error_level ~= 0 then break end
  end
  return error_level
end

---Local helper
---@param file string
---@param dir? string
---@return error_level_t
local function typesetpdf(file, dir)
  dir = dir or "."
  local name = job_name(file)
  print("Typesetting " .. name)
  local func  = Ngn.typeset
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
  print("REMOVE COPY: ", pdf_name, dir, Dir.docfile)
  print(lfs.attribute(dir .."/".. pdf_name, "mode"))
  print(lfs.attribute(Dir.docfile .."/".. pdf_name, "mode"))
  remove_name(Dir.docfile, pdf_name)
  print(lfs.attribute(dir .."/".. pdf_name, "mode"))
  print(lfs.attribute(Dir.docfile .."/".. pdf_name, "mode"))
  return copy_name(pdf_name, dir, Dir.docfile)
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
    for glob in entries(filetype) do
      copy_tree(glob, Dir.docfile, Dir.typeset)
    end
  end
  for glob in entries(Files.source) do
    copy_tree(glob, Dir.sourcefile, Dir.typeset)
  end
  for glob in entries(Files.typesetsupp) do
    copy_tree(glob, Dir.support, Dir.typeset)
  end
  deps_install(Deps.typeset)
  unpack({ Files.source, Files.typesetsource }, { Dir.sourcefile, Dir.docfile })
  -- Main loop for doc creation
  local error_level = Ngn.typeset_demo_tasks()
  if error_level ~= 0 then
    return error_level
  end
  return Ngn.docinit_hook()
end

---Typeset all required documents
---Uses a set of dedicated auxiliaries that need to be available to others
---@param files? string_list_t
---@return error_level_t
local function doc(files)
  local error_level = docinit()
  if error_level ~= 0 then
    return error_level
  end
  ---@type flag_table_t
  local done = {}
  for typeset_globs in items(Files.typesetdemo, Files.typeset) do
    for glob in entries(typeset_globs) do
      for dir_path in items(Dir.typeset, Dir.unpack) do
        for p_wrk in values(tree(dir_path, glob)) do
          print("==============================\nDEBUG p_wrk", p_wrk)
          local src_dir, src_name = dir_base(p_wrk)
          local name = job_name(src_name)
          if not done[name] then
            local should_typeset = true
            -- Allow for command line selection of files
            if files and not_empty(files) then
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
              error_level = typesetpdf(src_name, src_dir)
              if error_level ~= 0 then
                return error_level
              end
              done[name] = true
            end
          end
        end
      end
    end
  end
  print("------------------------\nDEBUG DONE")
  return 0
end

---@class l3b_typesetting_t
---@field dvi2pdf   fun(name: string, dir: string, engine: string, hide: boolean): integer
---@field runcmd    fun(cmd:  string, dir: string, vars: table): boolean?, exitcode?, integer?
---@field doc       fun(files: string_list_t): integer
---@field bibtex    fun(name: string, dir: string): integer
---@field biber     fun(name: string, dir: string): integer
---@field tex       fun(name: string, dir: string, cmd: string): integer
---@field makeindex fun(name: string, dir: string, in_ext: string, out_ext: string, log_ext: string, style: string): integer

return {
  dvi2pdf           = dvi2pdf,
  runcmd            = runcmd,
  doc               = doc,
  bibtex            = Ngn.bibtex,
  biber             = Ngn.biber,
  tex               = Ngn.tex,
  makeindex         = Ngn.makeindex,
}
