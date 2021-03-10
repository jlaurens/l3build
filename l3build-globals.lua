#!/usr/bin/env texlua

--[[

File l3build-globales.lua Copyright (C) 2014-2020 The LaTeX Project

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

--[=[
This modules populates the global space with variables.
They all are described in `l3build.dtx`.

It is the responsability of `l3build.dtx` contributors to ensure
that all global variables referenced there are defined in that file.

This file is `dofile`d just before `options.lua` and `build.lua`
are `dofile`d such that both inherit all the global variables
defined here.
--]=]

local l3build = require("l3build")

-- Global variables

_G.options = l3build.options


---@type utlib_t
local utlib = require("l3b-utillib")
local items = utlib.items

---@type wklib_t
local wklib = require("l3b-walklib")

---@type oslib_t
local oslib = require("l3b-oslib")

---@type gblib_t
local gblib = require("l3b-globlib")

---@type fslib_t
local fslib = require("l3b-fslib")

_G.abspath        = fslib.absolute_path
_G.dirname        = wklib.dir_name
_G.basename       = wklib.base_name
_G.cleandir       = fslib.make_clean_directory
_G.cp             = fslib.copy_tree
_G.direxists      = fslib.directory_exists
_G.fileexists     = fslib.file_exists
_G.filelist       = fslib.file_list
_G.glob_to_pattern = gblib.glob_to_pattern
_G.to_glob_match  = gblib.to_glob_match
_G.jobname        = wklib.job_name
_G.mkdir          = fslib.make_directory
_G.ren            = fslib.rename
_G.rm             = fslib.remove_tree
_G.run            = oslib.run
_G.splitpath      = wklib.dir_name
_G.normalize_path = fslib.to_host

-- System dependent strings
--X os_concat
--X os_null
--X os_pathsep
--X os_setenv

--components of l3build
if l3build.in_document then
  for k in items(
    "call", "install_files", "biber", "makeindex", "tex", "runcmd"
  ) do
    if not _G[k] then
      -- only provide a global when not available
      -- `tex` is a table defined by luatex
      _G[k] = function ()
        error(k .." is not available in document mode.")
      end
    end
  end
  return
end


---@type l3b_aux_t
local l3b_aux = require("l3build-aux")

_G.call = l3b_aux.call

---@type l3b_inst_t
local l3b_inst = require("l3build-install")

_G.install_files = l3b_inst.install_files

-- typesetting functions

---@type l3b_tpst_t
local l3b_tpst = require("l3build-typesetting")

_G.biber      = l3b_tpst.biber
_G.bibtex     = l3b_tpst.bibtex
_G.makeindex  = l3b_tpst.makeindex
_G.tex        = l3b_tpst.tex

_G.runcmd     = l3b_tpst.runcmd

-- Global variables

local function export_symbols(from, suffix, ...)
  if not from then
    print(debug.traceback())
    error("Missing from")
  end
  for item in items(...) do
    if from[item] == nil then
      print(debug.traceback())
      error("Erroneous item: ".. item)
    end
    _G[item ..suffix] = from[item]
  end
end

---@type l3b_vars_t
local l3b_vars = require("l3build-variables")

if type(_G.module) == "function" then
  _G.module = nil
end

---@type Main_t
local Main = l3b_vars.Main
export_symbols(Main, "",
  "module",
  "bundle",
  "ctanpkg",
  "modules",
  "exclmodules"
)

--[==[ Shape of the bundle folder ]==]
local Dir = l3b_vars.Dir
export_symbols(Dir, "dir",
  "main",
  "docfile",
  "sourcefile",
  "support",
  "testfile",
  "testsupp",
  "texmf",
  "textfile",
  "build",
  "distrib",
  --"local",
  "result",
  "test",
  "typeset",
  "unpack",
  "ctan",
  "tds"
)

_G.localdir = Dir[l3b_vars.LOCAL]

export_symbols(Main, "",
"tdsroot"
)

local Files = l3b_vars.Files
export_symbols(Files, "files",
  "aux",
  "bib",
  "binary",
  "bst",
  "check",
  "checksupp",
  "clean",
  "demo",
  "doc",
  "dynamic",
  "exclude",
  "install",
  "makeindex",
  "script",
  "scriptman",
  "source",
  "tag",
  "text",
  "typesetdemo",
  "typeset",
  "typesetsupp",
  "typesetsource",
  "unpack",
  "unpacksupp"
)

---@type l3b_check_t
local l3b_check = require("l3build-check")
---@type l3b_check_vars_t
local l3b_check_vars = l3b_check.Vars
export_symbols(l3b_check_vars, "",
"includetests",
"excludetests"
)

---@type Deps_t
local Deps = l3b_vars.Deps
export_symbols(Deps, "deps",
"check",
"typeset",
"unpack"
)

export_symbols(l3b_check_vars, "",
  "checkengines",
  "stdengine",
  "checkformat",
  "specialformats",
  "test_types",
  "test_order",
  "checkconfigs"
)

---@type Exe_t
local Exe = l3b_vars.Exe
export_symbols(Exe, "exe",
  "typeset",
  "unpack",
  "zip",
  "biber",
  "bibtex",
  "makeindex",
  "curl"
)

local Opts = l3b_vars.Opts
export_symbols(Opts, "opts",
  "check",
  "typeset",
  "unpack",
  "zip",
  "biber",
  "bibtex",
  "makeindex"
)

export_symbols(l3b_check_vars, "",
  "checksearch"
)

---@type l3b_tpst_t
local l3b_tpst = require("l3build-typesetting")
---@type l3b_tpst_vars_t
local l3b_tpst_vars = l3b_tpst.Vars
export_symbols(l3b_tpst_vars, "",
  "typesetsearch"
)

---@type l3b_unpk_t
local l3b_unpk = require("l3build-unpack")
---@type l3b_unpk_vars_t
local l3b_unpk_vars = l3b_unpk.Vars
export_symbols(l3b_unpk_vars, "",
  "unpacksearch"
)

export_symbols(l3b_tpst_vars, "",
  "glossarystyle",
  "indexstyle",
  "specialtypesetting",
  "forcedocepoch"
)

export_symbols(Main, "",
  "forcecheckepoch"
)

export_symbols(l3b_check_vars, "",
"asciiengines",
"checkruns"
)

export_symbols(Main, "",
  "ctanreadme",
  "ctanzip",
  "epoch"
)

---@type l3b_ctan_t
local l3b_ctan = require("l3build-ctan")
---@type l3b_ctan_vars_t
local l3b_ctan_vars = l3b_ctan.Vars
export_symbols(l3b_ctan_vars, "",
  "flatten"
)

---@type l3b_inst_vars_t
local l3b_inst_vars = l3b_inst.Vars

export_symbols(l3b_inst_vars, "",
  "flattentds",
  "flattenscript"
)

export_symbols(l3b_check_vars, "",
  "maxprintline"
)

export_symbols(l3b_ctan_vars, "",
  "packtdszip"
)

export_symbols(Opts, "opts",
  "ps2pdf"
)

export_symbols(l3b_tpst_vars, "",
  "typesetcmds"
)

export_symbols(l3b_check_vars, "",
  "recordstatus"
)

---@type l3b_mfst_t
local l3b_mfst = require("l3build-manifest")
---@type l3b_mfst_vars_t
local l3b_mfst_vars = l3b_mfst.Vars

export_symbols(l3b_mfst_vars, "",
  "manifestfile"
)

export_symbols(Main, "",
  "tdslocations"
)

---@type l3b_upld_t
local l3b_upld = require("l3build-upload")
---@type l3b_upld_vars_t
local l3b_upld_vars = l3b_upld.Vars

export_symbols(l3b_upld_vars, "",
  "uploadconfig"
)

local Xtn = l3b_vars.Xtn
export_symbols(Xtn, "ext",
  "bak",
  "dvi",
  "lvt",
  "tlg",
  "tpf",
  "lve",
  "log",
  "pvt",
  "pdf",
  "ps"
)
