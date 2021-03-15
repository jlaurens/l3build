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

No global variable declaration is expected out of this package,
the various `build.lua` and configuration scripts.

It is the responsability of `l3build.dtx` contributors to ensure
that all global variables referenced there are defined in that file.

This file is `require`d just before performing the actions,
after the various build and configuration files are executed.
--]=]

local setmetatable  = setmetatable
local type          = type
local tostring      = tostring
local pairs         = pairs
local print         = print
local write         = io.write

---@type utlib_t
local utlib         = require("l3b-utillib")
local items         = utlib.items
local keys          = utlib.keys
local sorted_pairs  = utlib.sorted_pairs
local entries       = utlib.entries

---@type oslib_t
local oslib         = require("l3b-oslib")

---@type wklib_t
local wklib   = require("l3b-walklib")

---@type gblib_t
local gblib   = require("l3b-globlib")

---@type fslib_t
local fslib   = require("l3b-fslib")
local file_exists = fslib.file_exists

local l3build = require("l3build")

---Add an indirection level to _G
---Usefull to keep track of what is defined globally
---by `build.lua` and configuration files
---Must be run before those files are loaded.
---Does not work if build is already loaded (old latex2e design)
local function setup()
  if not l3build.G then
    l3build.G = setmetatable({}, {
      __index = _G,
    })
  end
  if not getmetatable(l3build.G) then
    setmetatable(l3build.G, {
      __index = _G,
    })
  end
end

local function unsetup()
  setmetatable(l3build.G, nil)
end
---Load and runs the build script from the work directory
---The difference with dofile is the running environment
---where all the declared variables are stored.
---@param work_dir string
local function load_build(work_dir)
  setup()
  local f, msg = loadfile(
    work_dir .. "/build.lua",
    "t",
    l3build.G
  )
  if not f then
    error(msg)
  end
  f() -- ignore any output
  unsetup()
end

---Load the configuration file.
---The file must exist.
---@param work_dir string path of the working directory
---@param config string name of the configuration
local function load_configuration(work_dir, config)
  local name = config:match("^config-(.*)") or config
  name = name:match("(.*)%.lua$") or name
  setup()
  local path = ("%s/config-%s.lua"):format(work_dir, name)
  if not file_exists(path) then
    path = ("%s/%s.lua"):format(work_dir, name)
    if not file_exists(path) then
      error("Unknown config: ".. config)
    end
  end
  local f, msg = loadfile(path, "t", l3build.G)
  if not f then
    error(msg)
  end
  f() -- ignore any output
  unsetup()
end

local l3b_functions = {
  "typeset",
  "bibtex",
  "biber",
  "makeindex",
  "tex",
  "checkinit_hook",
  "runtest_tasks",
  "update_tag",
  "tag_hook",
  "typeset_demo_tasks",
  "docinit_hook",
  "manifest_setup",
  "manifest_sort_within_match",
  "manifest_sort_within_group",
  "manifest_extract_filedesc",
  "manifest_write_opening",
  "manifest_write_subheading",
  "manifest_write_group_heading",
  "manifest_write_group_file",
  "manifest_write_group_file_descr",
}

---Export symbols to an environment
---@param G           table
---@param in_document boolean
---@return table
local function export_symbols(G, in_document)
  -- Global variables
  G.options         = l3build.options

  G.abspath         = fslib.absolute_path
  G.dirname         = wklib.dir_name
  G.basename        = wklib.base_name
  G.cleandir        = fslib.make_clean_directory
  G.cp              = fslib.copy_tree
  G.direxists       = fslib.directory_exists
  G.fileexists      = fslib.file_exists
  G.filelist        = fslib.file_list
  G.glob_to_pattern = gblib.glob_to_pattern
  G.to_glob_match   = gblib.to_glob_match
  G.jobname         = wklib.job_name
  G.mkdir           = fslib.make_directory
  G.ren             = fslib.rename
  G.rm              = fslib.remove_tree
  G.run             = oslib.run
  G.splitpath       = wklib.dir_name
  G.normalize_path  = fslib.to_host


  -- System dependent strings
  --X os_concat
  --X os_null
  --X os_pathsep
  --X os_setenv

  --components of l3build
  if in_document then
    for k in items(
      "call", "install_files",
      "typeset", "bibtex", "biber", "makeindex", "tex",
      "runcmd"
    ) do
      if not type(G[k]) == "function" then
        -- only provide a global when not available
        -- `tex` is a table defined by luatex
        G[k] = function ()
          error(k .." is not available in document mode.")
        end
      end
    end
    return
  end

  local function export_f(from, ...)
    for item in items(...) do
      local v = from[item]
      assert(v, "Missing value for key ".. item)
      G[item] = v
    end
  end

  ---@type l3b_aux_t
  local l3b_aux = require("l3build-aux")
  export_f(l3b_aux, "call")

  ---@type l3b_inst_t
  local l3b_inst = require("l3build-install")
  export_f(l3b_inst, "install_files")

  -- typesetting functions

  ---@type l3b_doc_t
  local l3b_doc = require("l3build-doc")
  export_f(l3b_doc, "runcmd")

  -- Global functions

  ---@type l3b_doc_engine_t
  local engine = l3b_doc.engine
  export_f(engine,
    "typeset",
    "bibtex",
    "biber",
    "makeindex",
    "tex",
    "typeset_demo_tasks",
    "docinit_hook"
  )

  ---@type l3b_tag_t
  local l3b_tag = require("l3build-tag")
  ---@type l3b_tag_vars_t
  local l3b_tag_vars = l3b_tag.Vars
  export_f(l3b_tag_vars,
    "tag_hook",
    "update_tag"
  )

  ---@type l3b_check_t
  local l3b_check = require("l3build-check")
  ---@type l3b_check_vars_t
  local l3b_check_vars = l3b_check.Vars
  export_f(l3b_check_vars,
    "checkinit_hook",
    "runtest_tasks"
  )

  ---@type l3b_mfst_t
  local l3b_mfst = require("l3build-manifest")
  local l3b_mfst_hook = l3b_mfst.hook
  
  for item in items(
    "manifest_setup",
    "manifest_sort_within_match",
    "manifest_sort_within_group",
    "manifest_extract_filedesc",
    "manifest_write_opening",
    "manifest_write_subheading",
    "manifest_write_group_heading",
    "manifest_write_group_file",
    "manifest_write_group_file_descr"
  ) do
    local k = item:match("manifest_(.*)")
    local v = l3b_mfst_hook[k]
    assert(v, "Missing manifest hook for key ".. k)
    G[item] = v
  end

  if l3build.options.debug then
    for item in entries(l3b_functions) do
      assert(type(G[item]) == "function", "Missing function ".. item)
    end
  end

  -- Global variables

  ---@type OS_t
  local OS = oslib.OS

  for item in items(
    "pathsep",
    "concat",
    "null",
    "ascii",
    "cmpexe",
    "cmpext",
    "diffexe",
    "diffext",
    "grepexe",
    "setenv",
    "yes"
  ) do
    local from_item = OS[item]
    if from_item == nil then
      print(debug.traceback())
      error("Erroneous item: ".. item)
    end
    G["os_".. item] = from_item
  end

  local function export_v(from, suffix, ...)
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
      G[item .. suffix] = from_item
    end
  end

  ---@type l3b_vars_t
  local l3b_vars = require("l3build-variables")

  if type(G.module) == "function" then
    G.module = nil
  end

  ---@type Main_t
  local Main = l3b_vars.Main
  export_v(Main, "",
    "module",
    "bundle",
    "ctanpkg",
    "modules",
    "exclmodules"
  )

  --[==[ Shape of the bundle folder ]==]
  local Dir = l3b_vars.Dir
  export_v(Dir, "dir",
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

  G.localdir = Dir[l3b_vars.LOCAL]

  export_v(Main, "",
    "tdsroot"
  )

  local Files = l3b_vars.Files
  export_v(Files, "files",
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

  export_v(l3b_check_vars, "",
    "includetests",
    "excludetests"
  )

  ---@type Deps_t
  local Deps = l3b_vars.Deps
  export_v(Deps, "deps",
    "check",
    "typeset",
    "unpack"
  )

  export_v(l3b_check_vars, "",
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
  export_v(Exe, "exe",
    "typeset",
    "unpack",
    "zip",
    "biber",
    "bibtex",
    "makeindex",
    "curl"
  )

  local Opts = l3b_vars.Opts
  export_v(Opts, "opts",
    "check",
    "typeset",
    "unpack",
    "zip",
    "biber",
    "bibtex",
    "makeindex"
  )

  export_v(l3b_check_vars, "",
    "checksearch"
  )

  ---@type l3b_doc_vars_t
  local l3b_doc_vars = l3b_doc.Vars
  export_v(l3b_doc_vars, "",
    "typesetsearch"
  )

  ---@type l3b_unpk_t
  local l3b_unpk = require("l3build-unpack")
  ---@type l3b_unpk_vars_t
  local l3b_unpk_vars = l3b_unpk.Vars
  export_v(l3b_unpk_vars, "",
    "unpacksearch"
  )

  export_v(l3b_doc_vars, "",
    "glossarystyle",
    "indexstyle",
    "specialtypesetting",
    "forcedocepoch"
  )

  export_v(l3b_check_vars, "",
    "forcecheckepoch",
    "asciiengines",
    "checkruns"
  )

  ---@type l3b_inst_vars_t
  local l3b_inst_vars = l3b_inst.Vars

  export_v(l3b_inst_vars, "",
    "ctanreadme"
  )

  export_v(Main, "",
    "ctanzip",
    "epoch"
  )

  ---@type l3b_ctan_t
  local l3b_ctan = require("l3build-ctan")
  ---@type l3b_ctan_vars_t
  local l3b_ctan_vars = l3b_ctan.Vars
  export_v(l3b_ctan_vars, "",
    "flatten"
  )

  export_v(l3b_inst_vars, "",
    "flattentds",
    "flattenscript"
  )

  export_v(l3b_check_vars, "",
    "maxprintline"
  )

  export_v(l3b_ctan_vars, "",
    "packtdszip"
  )

  export_v(Opts, "opts",
    "ps2pdf"
  )

  export_v(l3b_doc_vars, "",
    "typesetruns",
    "typesetcmds"
  )

  export_v(l3b_check_vars, "",
    "recordstatus"
  )

  ---@type l3b_mfst_t
  local l3b_mfst = require("l3build-manifest")
  ---@type l3b_mfst_vars_t
  local l3b_mfst_vars = l3b_mfst.Vars

  export_v(l3b_mfst_vars, "",
    "manifestfile"
  )

  export_v(l3b_inst_vars, "",
    "tdslocations"
  )

  ---@type l3b_upld_t
  local l3b_upld = require("l3build-upload")
  ---@type l3b_upld_vars_t
  local l3b_upld_vars = l3b_upld.Vars

  export_v(l3b_upld_vars, "",
    "uploadconfig"
  )

  local Xtn = l3b_vars.Xtn
  export_v(Xtn, "ext",
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

  return G
end

---Prepares the print status command.
---Records the vanilla global variables and functions
local function prepare_print_status()
  local old = l3build.G
  l3build.G = {}
  local G = {}
  export_symbols(G)
  l3build.default_G = G
  l3build.G = old
end

---Print status for global function and hooks,
---for global variables as well.
local function print_status()
  local variables_n = 0
  local variables = {}
  local functions = {}
  local expected = {}
  for item in items(
    "typeset", "bibtex", "biber", "makeindex", "tex",
    "checkinit_hook",
    "runtest_tasks",
    "update_tag",
    "tag_hook",
    "typeset_demo_tasks",
    "docinit_hook",
    "manifest_setup",
    "manifest_sort_within_match",
    "manifest_sort_within_group",
    "manifest_extract_filedesc",
    "manifest_write_opening",
    "manifest_write_subheading",
    "manifest_write_group_heading",
    "manifest_write_group_file",
    "manifest_write_group_file_descr"
  ) do
    expected[item] = true
  end
  for k, v in pairs(_G) do
    if type(v) == "function" then
      if expected[k] then
        functions[k] = v
      end
    elseif l3build.default_G[k] then
      variables[k] = v
      variables_n = variables_n + 1
    end
  end
  
  print("Hooks and functions, (*) for custom ones")
  local width = 0
  for name in keys(expected) do
    if #name > width then
      width = #name
    end
  end
  for name in sorted_pairs(expected) do
    local filler = (" "):rep(width - #name)
    local is_custom = l3build.default_G[name] ~= functions[name]
    print("  ".. name .. filler .. (is_custom and " (*)" or ""))
  end

  ---Display the list of exported variables
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
    "os_pathsep",
    "os_concat",
    "os_null",
    "os_ascii",
    "os_cmpexe",
    "os_cmpext",
    "os_diffexe",
    "os_diffext",
    "os_grepexe",
    "os_setenv",
    "os_yes"
  }
  for entry in entries(official) do
    if _G[entry] == nil then
      print("MISSING GLOBAL: ", entry)
    end
  end
  print("")
  print(("Global variables (%d), (*) for custom ones"):format(variables_n))
-- Print anything - including nested tables
  local function pretty_print(tt, dflt, indent, done)
    dflt = dflt or {}
    done = done or {}
    indent = indent or 0
    if type(tt) == "table" then
      local w = 0
      local has_custom = false
      for k in keys(tt) do
        local l = #tostring(k)
        if l > w then
          w = l
        end
        has_custom = has_custom or tt[k] ~= dflt[k]
      end
      for k, v in sorted_pairs(tt) do
        local after_equals
        if has_custom then
          after_equals = v == dflt[k] and "    " or "(*) "
        else
          after_equals = ""
        end
        local filler = (" "):rep(w - #tostring(k))
        write((" "):rep(indent)) -- indent it
        if type(v) == "table" and not done[v] then
          done[v] = true
          if next(v) then
            write(('["%s"]%s = %s{\n'):format(tostring(k), filler, after_equals))
            pretty_print(v, dflt[k], indent + w + 7, done)
            write((" "):rep( indent + w + 5)) -- indent it
            write("}\n")
          else
            write(('["%s"]%s = %s{}\n'):format(tostring(k), filler, after_equals))
          end
        elseif type(v) == "string" then
          write(('["%s"]%s = %s"%s"\n'):format(
              tostring(k), filler, after_equals, tostring(v)))
        else
          write(('["%s"]%s = %s%s\n'):format(
              tostring(k), filler, after_equals, tostring(v)))
        end
      end
    else
      write(tostring(tt) .. (tt ~= dflt and "(*)" or '') .."\n")
    end
  end
  pretty_print(variables, l3build.default_G)
end

---@class l3b_globals_t
---@field export_symbols        fun(G: table, in_document: boolean): table
---@field print_status          fun()
---@field prepare_print_status  fun()
---@field setup                 fun()
---@field load_build            fun(work_dir: string)
---@field load_configuration    fun(work_dir: string)

return {
  export_symbols        = export_symbols,
  print_status          = print_status,
  prepare_print_status  = prepare_print_status,
  setup                 = setup,
  load_build            = load_build,
  load_configuration    = load_configuration,
}
