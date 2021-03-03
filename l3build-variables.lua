--[[

File l3build-variables.lua Copyright (C) 2018-2020 The LaTeX Project

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

local status = require("status")

---@type utlib_t
local utlib     = require("l3b.utillib")
local chooser   = utlib.chooser
local first_of  = utlib.first_of

---@type oslib_t
local oslib       = require("l3b.oslib")
local quoted_path = oslib.quoted_path

---@type fslib_t
local fslib             = require("l3b.fslib")
local set_tree_excluder = fslib.set_tree_excluder

-- "module" is a deprecated function in Lua 5.2: as we want the name
-- for other purposes, and it should eventually be 'free', simply
-- remove the built-in
if type("module") ~= "string" then
  module = nil
end

---@class Main_t
---@field module string
---@field bundle string
---@field tdsroot string
---@field ctanpkg string

---@type Main_t
local Main = chooser(_G, setmetatable({
  module  = "",
  bundle  = "",
  tdsroot = "latex",
}, {
  __index = function (t, k)
    if k == "ctanpkg" then
      return  t.bundle ~= ""
          and t.bundle or t.module
    end
  end
}))

---@class Dir_t
---@field current     string
---@field main        string
---@field docfile     string
---@field sourcefile  string
---@field textfile    string
---@field support     string
---@field testfile    string
---@field testsupp    string
---@field texmf       string
---@field build       string
---@field distrib     string
---@field ctan        string
---@field tds         string
---@field local   string
---@field result      string
---@field test        string
---@field typeset     string
---@field unpack      string
---@field module      string

local LOCAL = {}

---@type Dir_t
local default_Dir = setmetatable({
-- Directory structure for the build system
-- Use Unix-style path separators
  current = ".",
  [LOCAL] = "local",
  [utlib.DID_CHOOSE] = function (result, k)
    -- No trailing /
    -- What about the leading "./"
    if k:match("dir$") then
      return quoted_path(result:match("^(.-)/*$")) -- any return result will be quoted_path
    end
    return result
  end
}, {
  __index = function (t, k)
    local result
    if k == "main" then
      result = t.current
    elseif k == "docfile" then
      result = t.current
    elseif k == "sourcefile" then
      result = t.current
    elseif k == "textfile" then
      result = t.current
    elseif k == "support" then
      result = t.main .. "/support"
    elseif k == "testfile" then
      result = t.current .. "/testfiles"
    elseif k == "testsupp" then
      result = t.testfile .. "/support"
    elseif k == "texmf" then
      result = t.main .. "/texmf"
    -- Structure within a development area
    elseif k == "build" then
      result = t.main .. "/build"
    elseif k == "distrib" then
      result = t.build .. "/distrib"
    -- Substructure for CTAN release material
    elseif k == "ctan" then
      result = t.distrib .. "/ctan"
    elseif k == "tds" then
      result = t.distrib .. "/tds"
    elseif k == "local" then
      result = t.build .. "/local"
    elseif k == "result" then
      result = t.build .. "/result"
    elseif k == "test" then
      result = t.build .. "/test"
    elseif k == "typeset" then
      result = t.build .. "/doc"
    elseif k == "unpack" then
      result = t.build .. "/unpacked"
    -- Location for installation on CTAN or in TEXMFHOME
    elseif k == "module" then
      result = Main.tdsroot .. "/" .. Main.bundle .. "/" .. Main.module
      result = first_of(result:gsub("//", "/"))
    end
    return result
  end
})

---@type Dir_t
local Dir = chooser(_G, default_Dir, { suffix = "dir" })

set_tree_excluder(function (path)
  return path ~= Dir.build
end)

-- File types for various operations
-- Use Unix-style globs
-- All of these may be set earlier, so a initialised conditionally

---@class Files_t
---@field aux           string_list_t
---@field bib           string_list_t
---@field binary        string_list_t
---@field bst           string_list_t
---@field check         string_list_t
---@field checksupp     string_list_t
---@field clean         string_list_t
---@field demo          string_list_t
---@field doc           string_list_t
---@field dynamic       string_list_t
---@field exclude       string_list_t
---@field install       string_list_t
---@field makeindex     string_list_t
---@field script        string_list_t
---@field scriptman     string_list_t
---@field source        string_list_t
---@field tag           string_list_t
---@field text          string_list_t
---@field typesetdemo   string_list_t
---@field typeset       string_list_t
---@field typesetsupp   string_list_t
---@field typesetsource string_list_t
---@field unpack        string_list_t
---@field unpacksupp    string_list_t

---@type Files_t
local Files = chooser(_G, {
  aux           = { "*.aux", "*.lof", "*.lot", "*.toc" },
  bib           = { "*.bib" },
  binary        = { "*.pdf", "*.zip" },
  bst           = { "*.bst" },
  check         = {},
  checksupp     = {},
  clean         = { "*.log", "*.pdf", "*.zip" },
  demo          = {},
  doc           = {},
  dynamic       = {},
  exclude       = { "*~" },
  install       = { "*.sty","*.cls" },
  makeindex     = { "*.ist" },
  script        = {},
  scriptman     = {},
  source        = { "*.dtx", "*.ins", "*-????-??-??.sty" },
  tag           = { "*.dtx" },
  text          = { "*.md", "*.txt" },
  typesetdemo   = {},
  typeset       = { "*.dtx" },
  typesetsupp   = {},
  typesetsource = {},
  unpack        = { "*.ins" },
  unpacksupp    = {},
}, { suffix = "files" })


-- Roots which should be unpacked to support unpacking/testing/typesetting

---@class Deps_t
---@field check   string
---@field typeset string
---@field unpack  string

---@type Deps_t
local Deps = chooser(_G, {
  check = {},
  typeset = {},
  unpack = {},
}, { suffix = "deps" })

-- Executable names plus following options
typesetexe = typesetexe or "pdflatex"
unpackexe  = unpackexe  or "pdftex"
zipexe     = zipexe     or "zip"

checkopts   = checkopts   or "-interaction=nonstopmode"
typesetopts = typesetopts or "-interaction=nonstopmode"
unpackopts  = unpackopts  or ""
zipopts     = zipopts     or "-v -r -X"

-- Engines for testing
checkengines = checkengines or { "pdftex", "xetex", "luatex" }
checkformat  = checkformat  or "latex"
specialformats = specialformats or {}
specialformats.context = specialformats.context or {
    luatex = { binary = "context", format = "" },
    pdftex = { binary = "texexec", format = "" },
    xetex  = { binary = "texexec", format = "", options = "--xetex" }
  }
specialformats.latex = specialformats.latex or {
    etex  = { format = "latex" },
    ptex  = { binary = "eptex" },
    uptex = { binary = "euptex" }
  }
if not string.find(status.banner," 2019") then
  specialformats.latex.luatex = specialformats.latex.luatex or
    { binary = "luahbtex", format = "lualatex" }
  specialformats["latex-dev"] = specialformats["latex-dev"] or
    { luatex = { binary="luahbtex", format = "lualatex-dev" }}
end

stdengine    = stdengine    or "pdftex"

-- The tests themselves
includetests = includetests or { "*" }
excludetests = excludetests or {}

-- Configs for testing
checkconfigs = checkconfigs or { "build" }

-- Enable access to trees outside of the repo
-- As these may be set false, a more elaborate test than normal is needed
if checksearch == nil then
  checksearch = true
end
if typesetsearch == nil then
  typesetsearch = true
end
if unpacksearch == nil then
  unpacksearch = true
end

-- Additional settings to fine-tune typesetting
glossarystyle = glossarystyle or "gglo.ist"
indexstyle    = indexstyle    or "gind.ist"
specialtypesetting = specialtypesetting or {}

-- Supporting binaries and options
biberexe      = biberexe      or "biber"
biberopts     = biberopts     or ""
bibtexexe     = bibtexexe     or "bibtex8"
bibtexopts    = bibtexopts    or "-W"
makeindexexe  = makeindexexe  or "makeindex"
makeindexopts = makeindexopts or ""

-- Forcing epoch
if forcecheckepoch == nil then
  forcecheckepoch = true
end
if forcedocepoch == nil then
  forcedocepoch = false
end

-- Other required settings
asciiengines = asciiengines or { "pdftex" }
checkruns    = checkruns    or 1
ctanreadme   = ctanreadme   or "README.md"
ctanzip      = ctanzip      or Main.ctanpkg .. "-ctan"
epoch        = epoch        or 1463734800
if flatten == nil then
  flatten = true
end
if flattentds == nil then
  flattentds = true
end
maxprintline = maxprintline or 79
packtdszip   = packtdszip   or false
ps2pdfopt    = ps2pdfopt    or ""
typesetcmds  = typesetcmds  or ""
typesetruns  = typesetruns  or 3
recordstatus = recordstatus or false

-- Extensions for various file types: used to abstract out stuff a bit

---@class Xtn_t
---@field bak string
---@field dvi string
---@field log string
---@field lve string
---@field lvt string
---@field pdf string
---@field ps  string
---@field pvt string
---@field tlg string
---@field tpf string

---@type Xtn_t
local Xtn = chooser(_G, {
  bak = ".bak",
  dvi = ".dvi",
  log = ".log",
  lve = ".lve",
  lvt = ".lvt",
  pdf = ".pdf",
  ps  = ".ps" ,
  pvt = ".pvt",
  tlg = ".tlg",
  tpf = ".tpf",
})

---@class l3b_vars_t
---@field Xtn   Xtn_t
---@field Main  Main_t
---@field LOCAL any
---@field Dir   Dir_t
---@field Files Files_t
---@field Deps  Deps_t

return {
  global_symbol_map = {},
  Xtn               = Xtn,
  Main              = Main,
  LOCAL             = LOCAL,
  Dir               = Dir,
  Files             = Files,
  Deps              = Deps,
}
