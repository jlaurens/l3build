--[[

File l3build-variables.lua Copyright (C) 2018-2020 The LaTeX3 Project

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

-- "module" is a deprecated function in Lua 5.2: as we want the name
-- for other purposes, and it should eventually be 'free', simply
-- remove the built-in
if type(module) == "function" then
  module = nil
end


-- We first define straightforward defaults for some keys
-- the some variables need a special management
local V = {
-- Ensure the module and bundle exist
  module = "",
  bundle = "",

-- Directory structure for the build system
-- Use Unix-style path separators
  currentdir = ".",
  maindir    = ".",
  testfiledir = "./testfiles",

-- Substructure for file locations
  docfiledir    = ".",
  sourcefiledir = ".",
  textfiledir   = ".",

-- File types for various operations
-- Use Unix-style globs
-- All of these may be set earlier, so a initialised conditionally
  auxfiles = {"*.aux", "*.lof", "*.lot", "*.toc"},
  bibfiles = {"*.bib"},
  binaryfiles = {"*.pdf", "*.zip"},
  bstfiles = {"*.bst"},
  checkfiles = { },
  checksuppfiles = { },
  cleanfiles = {"*.log", "*.pdf", "*.zip"},
  demofiles = { },
  docfiles = { },
  dynamicfiles = { },
  excludefiles = {"*~"},
  installfiles = {"*.sty","*.cls"},
  makeindexfiles = {"*.ist"},
  scriptfiles = { },
  scriptmanfiles = { },
  sourcefiles = {"*.dtx", "*.ins", "*-????-??-??.sty"},
  tagfiles = {"*.dtx"},
  textfiles = {"*.md", "*.txt"},
  typesetdemofiles = { },
  typesetfiles = {"*.dtx"},
  typesetsuppfiles = { },
  typesetsourcefiles = { },
  unpackfiles = {"*.ins"},
  unpacksuppfiles = { },
-- Roots which should be unpacked to support unpacking/testing/typesetting
  checkdeps = { },
  typesetdeps = { },
  unpackdeps = { },

-- Executable names plus following options
  typesetexe = "pdflatex",
  unpackexe = "pdftex",
  zipexe = "zip",

  checkopts = "-interaction=nonstopmode",
  typesetopts = "-interaction=nonstopmode",
  unpackopts = "",
  zipopts = "-v -r -X",

-- Engines for testing
  checkengines = {"pdftex", "xetex", "luatex"},
  checkformat = "latex",

-- Engines for testing
  stdengine = "pdftex",

-- The tests themselves
  includetests = {"*"},
  excludetests = { },

-- Configs for testing
  checkconfigs = {"build"},
-- Additional settings to fine-tune typesetting
  glossarystyle = "gglo.ist",
  indexstyle = "gind.ist",
  specialtypesetting = { },

-- Supporting binaries and options
  biberexe = "biber",
  biberopts = "",
  bibtexexe = "bibtex8",
  bibtexopts = "-W",
  makeindexexe = "makeindex",
  makeindexopts = "",

-- Other required settings
  asciiengines = {"pdftex"},
  checkruns = 1,
  ctanreadme = "README.md",
  ctanzip = V.ctanpkg .. "-ctan",
  epoch = 1463734800,
  maxprintline = 79,
  packtdszip = false,
  ps2pdfopt = "",
  typesetcmds = "",
  typesetruns = 3,
  recordstatus = false,

-- Extensions for various file types: used to abstract out stuff a bit
  bakext = ".bak",
  dviext = ".dvi",
  logext = ".log",
  lveext = ".lve",
  lvtext = ".lvt",
  pdfext = ".pdf",
  psext = ".ps",
  pvtext = ".pvt",
  tlgext = ".tlg",
  tpfext = ".tpf",

-- Manifest options
  manifestfile = "MANIFEST.md",

-- Non-standard installation locations
  tdslocations = { },

-- Upload settings
  curlexe = "curl",

  uploadconfig = {},
}

-- for each key of V, check for a global variable with that very name
-- and change the value to that variable eventually
for k in pairs(V) do
  local w = _ENV[k]
  if w then
    V[k] = w
  end
end

-- Substructure for file locations
V.supportdir    = supportdir    or V.maindir .. "/support"
V.testsuppdir   = testsuppdir   or V.testfiledir .. "/support"
V.texmfdir      = texmfdir      or V.maindir .. "/texmf"

-- Structure within a development area
V.builddir   = builddir   or V.maindir .. "/build"
V.distribdir = distribdir or V.builddir .. "/distrib"
V.localdir   = localdir   or V.builddir .. "/local"
V.resultdir  = resultdir  or V.builddir .. "/result"
V.testdir    = testdir    or V.builddir .. "/test"
V.typesetdir = typesetdir or V.builddir .. "/doc"
V.unpackdir  = unpackdir  or V.builddir .. "/unpacked"

-- Substructure for CTAN release material
V.ctandir = ctandir or V.distribdir .. "/ctan"
V.tdsdir  = tdsdir  or V.distribdir .. "/tds"
V.tdsroot = tdsroot or "latex"

-- Location for installation on CTAN or in TEXMFHOME
if bundle == "" then
  V.moduledir = V.tdsroot .. "/" .. V.module
  V.ctanpkg   = ctanpkg or V.module
else
  V.moduledir = V.tdsroot .. "/" .. bundle .. "/" .. V.module
  V.ctanpkg   = ctanpkg or bundle
end

-- Ensure that directories are 'space safe'
V.maindir       = FF.escapepath(V.maindir)
V.docfiledir    = FF.escapepath(V.docfiledir)
V.sourcefiledir = FF.escapepath(V.sourcefiledir)
V.supportdir    = FF.escapepath(V.supportdir)
V.testfiledir   = FF.escapepath(V.testfiledir)
V.testsuppdir   = FF.escapepath(V.testsuppdir)
V.builddir      = FF.escapepath(V.builddir)
V.distribdir    = FF.escapepath(V.distribdir)
V.localdir      = FF.escapepath(V.localdir)
V.resultdir     = FF.escapepath(V.resultdir)
V.testdir       = FF.escapepath(V.testdir)
V.typesetdir    = FF.escapepath(V.typesetdir)
V.unpackdir     = FF.escapepath(V.unpackdir)

-- Engines for testing
V.specialformats = specialformats or { }
V.specialformats.context = specialformats.context or {
    luatex = {binary = "context", format = ""},
    pdftex = {binary = "texexec", format = ""},
    xetex  = {binary = "texexec", format = "", options = "--xetex"}
  }
  V.specialformats.latex = specialformats.latex or {
    etex  = {format = "latex"},
    ptex  = {binary = "eptex"},
    uptex = {binary = "euptex"}
  }
if not string.find(status.banner,"2019") then
  V.specialformats.latex.luatex = specialformats.latex.luatex or
    {binary = "luahbtex",format = "lualatex"}
    V.specialformats["latex-dev"] = specialformats["latex-dev"] or
    {luatex = {binary="luahbtex",format = "lualatex-dev"}}
end

-- Enable access to trees outside of the repo
-- As these may be set false, a more elaborate test than normal is needed
local function force_true(x)
  if x == nil then
    return true
  else
    return x
  end
end
V.checksearch = force_true(checksearch)
V.typesetsearch = force_true(typesetsearch)
V.unpacksearch = force_true(unpacksearch)

-- Other required settings
V.flatten = force_true(flatten)
V.flattentds = force_true(flattentds)

-- Forcing epoch
V.forcecheckepoch = force_true(forcecheckepoch)
V.forcedocepoch = force_true(forcedocepoch)


-- Sanity check
V.check_engines = function (self, options)
  if options.engine and not options.force then
     -- Make a lookup table
    local t = { }
    for _, engine in pairs(self.checkengines) do
      t[engine] = true
    end
    for _, engine in pairs(options.engine) do
      if not t[engine] then
        print("\n! Error: Engine \"" .. engine .. "\" not set up for testing!")
        print("\n  Valid values are:")
        for _, engine in ipairs(self.checkengines) do
          print("  - " .. engine)
        end
        print("")
        os.exit(1)
      end
    end
  end
end

V.sanitize_epoch = function (self, options)
  -- Tidy up the epoch setting
  -- Force an epoch if set at the command line
  -- Must be done after loading variables, etc.
  if options.epoch then
    self.epoch  = options.epoch
    self.forcecheckepoch = true
    self.forcedocepoch   = true
  end
  -- If given as an ISO date, turn into an epoch number
  local y, m, d = self.epoch:match("^(%d%d%d%d)-(%d%d)-(%d%d)$")
  if y then
    self.epoch =
      os.time({year = y, month = m, day = d, hour = 0, sec = 0, isdst = nil}) -
      os.time({year = 1970, month = 1, day = 1, hour = 0, sec = 0, isdst = nil})
  elseif self.epoch:match("^%d+$") then
    self.epoch = tonumber(self.epoch)
  else
    self.epoch = 0
  end
end

-- When we have specific files to deal with, only use explicit configs
-- (or just the std one)
V.sanitize_check_config = function (self, options)
  if options.names then
    self.checkconfigs = options.config or {stdconfig} -- WHAT IS stdconfig?
  else
    self.checkconfigs = options.config or checkconfigs
  end
end

return V
