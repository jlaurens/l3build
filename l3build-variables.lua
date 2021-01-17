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

-- local safety guards

local pairs = pairs
local banner = status and status.banner or ""

-- global tables

local FS = L3B.require('FS')

-- "module" is a deprecated function in Lua 5.2: as we want the name
-- for other purposes, and it should eventually be 'free', simply
-- remove the built-in
if type(module) == "function" then
  module = nil
end

-- module table

local Vars = L3B.provide('Vars')

local function special_latex_luatex ()
  if not banner:find("2019") then
    return { binary = "luahbtex", format = "lualatex" }
  end
end

local function special_latex_dev ()
  if not banner:find("2019") then
    return { 
      luatex = { binary="luahbtex", format = "lualatex-dev" }
    }
  end
  return {}
end

-- Primay defaults. No dependencies.
local defaults = {
-- Ensure the module and bundle exist
  module = "",
  bundle = "",

-- Directory structure for the build system
-- Use Unix-style path separators
  currentdir = ".", -- TODO critical: move to FS
  maindir    = ".", -- TODO critical: move to FS

-- Substructure for file locations
  docfiledir    = ".", -- TODO critical: move to FS
  sourcefiledir = ".", -- TODO critical: move to FS
  textfiledir   = ".", -- TODO critical: move to FS
  testfiledir   = "./testfiles", -- TODO critical: move to FS

-- File types for various operations
-- Use Unix-style globs
-- All of these may be set earlier, so a initialised conditionally
  auxfiles       = { "*.aux", "*.lof", "*.lot", "*.toc" },
  bibfiles       = { "*.bib" },
  binaryfiles    = { "*.pdf", "*.zip" },
  bstfiles       = { "*.bst" },
  checkfiles     = {},
  checksuppfiles = {},
  cleanfiles     = { "*.log", "*.pdf", "*.zip" },
  demofiles      = {},
  docfiles       = {},
  dynamicfiles   = {},
  excludefiles   = { "*~" },
  exclmodules    = {}, -- was hidden in former stdmain
  installfiles   = { "*.sty","*.cls" },
  makeindexfiles = { "*.ist" },
  scriptfiles    = {},
  scriptmanfiles = {},
  sourcefiles    = { "*.dtx", "*.ins", "*-????-??-??.sty" },
  tagfiles       = { "*.dtx" },
  textfiles      = { "*.md", "*.txt" },
  typesetdemofiles   = {},
  typesetfiles       = { "*.dtx" },
  typesetsuppfiles   = {},
  typesetsourcefiles = {},
  unpackfiles        = { "*.ins" },
  unpacksuppfiles    = {},

-- Roots which should be unpacked to support unpacking/testing/typesetting
  checkdeps   = {},
  typesetdeps = {},
  unpackdeps  = {},

-- Executable names plus following options
  typesetexe = "pdflatex",
  unpackexe  = "pdftex",
  zipexe     = "zip",

  checkopts   = "-interaction=nonstopmode",
  typesetopts = "-interaction=nonstopmode",
  unpackopts  = "",
  zipopts     = "-v -r -X",

-- Engines for testing
  checkengines = { "pdftex", "xetex", "luatex" },
  checkformat = "latex",
  specialformats = { 
    context = {
      luatex = { binary = "context", format = "" },
      pdftex = { binary = "texexec", format = "" },
      xetex  = { binary = "texexec", format = "", options = "--xetex" }
    },
    latex = {
      luatex = special_latex_luatex(),
      etex   = { format = "latex" },
      ptex   = { binary = "eptex" },
      uptex  = { binary = "euptex" }
    },
    ["latex-dev"] = special_latex_dev(),
  },
  stdengine = "pdftex",
-- The tests themselves
  includetests = { "*" },
  excludetests = {},
-- Configs for testing
  checkconfigs = { "build" },
-- Additional settings to fine-tune typesetting
  glossarystyle = "gglo.ist",
  indexstyle    = "gind.ist",
  specialtypesetting = {},

-- Supporting binaries and options
  biberexe      = "biber",
  biberopts     = "",
  bibtexexe     = "bibtex8",
  bibtexopts    = "-W",
  makeindexexe  = "makeindex",
  makeindexopts = "",

-- Other required settings
  asciiengines = { "pdftex" },
  checkruns = 1,
  ctanreadme = "README.md",
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
  psext  = ".ps",
  pvtext = ".pvt",
  tlgext = ".tlg",
  tpfext = ".tpf",

-- Manifest options
  manifestfile = "MANIFEST.md",

-- Non-standard installation locations
  tdslocations = {},
  tdsroot = "latex",

-- Upload settings
  curlexe = "curl",
  uploadconfig = {},
-- Checking
  checkinit_hook = function () return 0 end,
-- A hook to allow additional tasks to run for the tests
  runtest_tasks = function () return "" end
}

local defaults_no_nil = {
  checksearch = true,
  typesetsearch = true,
  unpacksearch = true,
  forcecheckepoch = true,
  forcedocepoch = true,
  flatten = true,
  flattentds = true,
}

-- Sanity check
local function check_engines (opts, checkengines)
  if opts.engines and not opts.force then
    -- Make a lookup table
    local t = {}
    for _, engine in pairs(checkengines) do
      t[engine] = true
    end
    for _, engine in pairs(opts.engines) do
      if not t[engine] then
        print("\n! Error: Engine \"" .. engine .. "\" not set up for testing!")
        print("\n  Valid values are:")
        for _, engine in ipairs(checkengines) do
          print("  - " .. engine)
        end
        print("")
        os.exit(1)
      end
    end
  end
end

local function normalise_epoch(epoch)
  -- If given as an ISO date, turn into an epoch number
  local y, m, d = epoch:match("^(%d%d%d%d)-(%d%d)-(%d%d)$")
  if y then
    epoch =
      os.time({ year = y,    month = m, day = d, hour = 0, sec = 0, isdst = nil }) -
      os.time({ year = 1970, month = 1, day = 1, hour = 0, sec = 0, isdst = nil })
  elseif epoch:match("^%d+$") then
    epoch = tonumber(epoch)
  else
    epoch = 0
  end
  return epoch
end

-- Merge in the table `t` the defaults and the given environment.
-- additional management for directory names
-- @param env Defaults to `_ENV`
Vars.finalize = function (t, opts, env)
  env = env or _ENV
  for k, v in pairs(defaults) do
    t[k] = env[k] or v
  end
  for k, v in pairs(defaults_no_nil) do
    local env_k = env[k]
    t[k] = env_k ~= nil and env_k or v
  end
  -- dependent values
  -- Package
  t.supportdir  = env.supportdir  or t.maindir     .. "/support"
  t.texmfdir    = env.texmfdir    or t.maindir     .. "/texmf"
  t.testsuppdir = env.testsuppdir or t.testfiledir .. "/support"
  -- Structure within a development area
  t.builddir    = env.builddir    or t.maindir  .. "/build"
  t.distribdir  = env.distribdir  or t.builddir .. "/distrib"
  t.localdir    = env.localdir    or t.builddir .. "/local"
  t.resultdir   = env.resultdir   or t.builddir .. "/result"
  t.testdir     = env.testdir     or t.builddir .. "/test"
  t.typesetdir  = env.typesetdir  or t.builddir .. "/doc"
  t.unpackdir   = env.unpackdir   or t.builddir .. "/unpacked"
  -- Substructure for CTAN release material
  t.ctandir     = env.ctandir or t.distribdir .. "/ctan"
  t.tdsdir      = env.tdsdir  or t.distribdir .. "/tds"
  -- Merge specialformats
  local specialformats = env.specialformats
  if specialformats then
    for _, k in pairs({ "context", "latex", "latex-dev" }) do
      local v = specialformats[k]
      if v then
        t.specialformats[k] = v
      end
    end
  end
  -- Location for installation on CTAN or in TEXMFHOME
  if t.bundle == "" then
    t.moduledir = t.tdsroot .. "/" .. t.module
    t.ctanpkg   = t.ctanpkg or t.module
  else
    t.moduledir = t.tdsroot .. "/" .. t.bundle .. "/" .. t.module
    t.ctanpkg   = t.ctanpkg or t.module
  end
  t.ctanzip = t.ctanpkg .. "-ctan"
  -- Ensure that directories are 'space safe'
  for _, v in pairs({
    "maindir",
    "docfiledir",
    "sourcefiledir",
    "supportdir",
    "testfiledir",
    "testsuppdir",
    "builddir",
    "distribdir",
    "localdir",
    "resultdir",
    "testdir",
    "typesetdir",
    "unpackdir",    
  }) do
    t[v] = FS.escape_path(t[v])
  end
  -- Tidy up the epoch setting
  -- Force an epoch if set at the command line
  -- Must be done after loading variables, etc.
  if opts.epoch then
    t.epoch           = opts.epoch
    t.forcecheckepoch = true
    t.forcedocepoch   = true
  end
  t.epoch = normalise_epoch(t.epoch)
    -- Sanity check
  check_engines(opts, t.checkengines)
  if opts.names then
    V.checkconfigs = opts.config or { stdconfig } -- What is stdconfig?
  else
    V.checkconfigs = opts.config or V.checkconfigs
  end
end

-- Updates the given `t` table with
-- the configuration name and environment
-- @param env Defaults to `_ENV`
function Vars.finalize_one_config(t, cfg, env)
  env = env or _ENV
  t.testdir = t.testdir .. "-" .. cfg
  -- Reset testsuppdir if required
  if env.testsuppdir and env.testsuppdir ~= t.testsuppdir then
    -- testsuppdir has change since last `finalize`
    t.testsuppdir = env.testsuppdir
  end
  if env.testfiledir and env.testfiledir ~= t.testfiledir then
    if env.testsuppdir == t.testfiledir .. "/support" then
      t.testsuppdir = env.testfiledir .. "/support"
    end
    t.testfiledir = env.testfiledir
  end
end

return Vars
