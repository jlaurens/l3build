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

local tostring  = tostring
local type      = type
local print     = print
local write     = io.write

local l3build   = require("l3build")

-- Global variables

_G.options = l3build.options


---@type utlib_t
local utlib         = require("l3b-utillib")
local items         = utlib.items
local keys          = utlib.keys
local sorted_pairs  = utlib.sorted_pairs

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
    "call", "install_files", "bibtex", "biber", "makeindex", "tex", "runcmd"
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
---@type l3b_tpst_engine_t
local engine = l3b_tpst.engine

_G.biber      = engine.biber
_G.bibtex     = engine.bibtex
_G.makeindex  = engine.makeindex
_G.tex        = engine.tex

_G.runcmd     = l3b_tpst.runcmd

-- Global variables

local exported_count = 0
local exported = {}

local function export_symbols(from, suffix, ...)
  if not from then
    print(debug.traceback())
    error("Missing from")
  end
  for item in items(...) do
    local from_item = from[item]
    if from_item == nil then
      print(debug.traceback())
      error("Erroneous item: ".. item)
    end
    _G[item .. suffix] = from_item
    exported[item ..suffix] = from_item
    exported_count = exported_count + 1
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
  "local",
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

export_symbols(l3b_check_vars, "",
  "forcecheckepoch",
  "asciiengines",
  "checkruns"
)

---@type l3b_inst_vars_t
local l3b_inst_vars = l3b_inst.Vars

export_symbols(l3b_inst_vars, "",
"ctanreadme"
)

export_symbols(Main, "",
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
  "typesetruns",
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

export_symbols(l3b_inst_vars, "",
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

---Display the list of exported variables
if l3build.options.debug then
  local official = {
"module",
"bundle",
"ctanpkg",
--
"modules",
"exclmodules",
--
"maindir",
"docfiledir",
"sourcefiledir",
"supportdir",
"testfiledir",
"testsuppdir",
"texmfdir",
"textfiledir",
--
"builddir",
"distribdir",
"localdir",
"resultdir",
"testdir",
"typesetdir",
"unpackdir",
--
"ctandir",
"tdsdir",
"tdsroot",
--
"auxfiles",
"bibfiles",
"binaryfiles",
"bstfiles",
"checkfiles",
"checksuppfiles",
"cleanfiles",
"demofiles",
"docfiles",
"dynamicfiles",
"excludefiles",
"installfiles",
"makeindexfiles",
"scriptfiles",
"scriptmanfiles",
"sourcefiles",
"tagfiles",
"textfiles",
"typesetdemofiles",
"typesetfiles",
"typesetsuppfiles",
"typesetsourcefiles",
"unpackfiles",
"unpacksuppfiles",
--
"includetests",
"excludetests",
--
"checkdeps",
"typesetdeps",
"unpackdeps",
--
"checkengines",
"stdengine",
"checkformat",
"specialformats",
"test_types",
"test_order",
--
"checkconfigs",
--
"typesetexe",
"unpackexe",
"zipexe",
"biberexe",
"bibtexexe",
"makeindexexe",
"curlexe",
--
"checkopts",
"typesetopts",
"unpackopts",
"zipopts",
"biberopts",
"bibtexopts",
"makeindexopts",
--
"checksearch",
"typesetsearch",
"unpacksearch",
--
"glossarystyle",
"indexstyle",
"specialtypesetting",
--
"forcecheckepoch",
"forcedocepoch",
--
"asciiengines",
"checkruns",
"ctanreadme",
"ctanzip",
"epoch",
"flatten",
"flattentds",
"flattenscript",
"maxprintline",
"packtdszip",
"ps2pdfopts",
"typesetcmds",
"typesetruns",
"recordstatus",
"manifestfile",
--
"tdslocations",
--
"uploadconfig",
--"uploadconfig.pkg",
--
"bakext",
"dviext",
"lvtext",
"tlgext",
"tpfext",
"lveext",
"logext",
"pvtext",
"pdfext",
"psext",
  }
  for entry in utlib.entries(official) do
    if exported[entry] == nil then
      print("MISSING GLOBAL: ", entry)
    end
  end
--]==]
  print(("DEBUG: %d global variables"):format(exported_count))
  print("{")
  local i = 0
  for key, _ in sorted_pairs(exported) do
    i = i + 1
    print(("--[[%3d]] %s,"):format(i, key))
  end
  print("}")
  print("DEBUG: Global variables:")
-- Print anything - including nested tables
  local function pretty_print(tt, indent, done)
    done = done or {}
    indent = indent or 0
    if type(tt) == "table" then
      local width = 0
      for key in keys(tt) do
        local l = #tostring(key)
        if l > width then
          width = l
        end
      end
      for key, value in sorted_pairs(tt) do
        local filler = (" "):rep(width - #tostring(key))
        write((" "):rep(indent)) -- indent it
        if type(value) == "table" and not done[value] then
          done[value] = true
          if next(value) then
            write(('["%s"]%s = {\n'):format(tostring(key), filler))
            pretty_print(value, indent + width + 7, done)
            write((" "):rep( indent + width + 5)) -- indent it
            write("}\n")
          else
            write(('["%s"] %s= {}\n'):format(tostring(key), filler))
          end
        elseif type(value) == "string" then
          write(('["%s"] %s= "%s"\n'):format(
              tostring(key), filler, tostring(value)))
        else
          write(('["%s"] %s= %s\n'):format(
              tostring(key), filler, tostring(value)))
        end
      end
    else
      io.write(tostring(tt) .. "\n")
    end
  end
  pretty_print(exported)
  print("")
end
