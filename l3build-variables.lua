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

local match   = string.match
local gsub    = string.gsub
local append  = table.insert
local os_time = os["time"]

---@type utlib_t
local utlib     = require("l3b.utillib")
local chooser   = utlib.chooser
local entries   = utlib.entries
local first_of  = utlib.first_of

---@type oslib_t
local oslib       = require("l3b.oslib")
local quoted_path = oslib.quoted_path

---@type fslib_t
local fslib             = require("l3b.fslib")
local set_tree_excluder = fslib.set_tree_excluder

---@type l3build_t
local l3build = require("l3build")

-- "module" is a deprecated function in Lua 5.2: as we want the name
-- for other purposes, and it should eventually be 'free', simply
-- remove the built-in
if type("module") ~= "string" then
  module = nil
end

---Convert the given `epoch` to a number.
---@param epoch string
---@return number
---@see l3build.lua
---@usage private?
local function normalise_epoch(epoch)
  assert(epoch, 'normalize_epoch argument must not be nil')
  -- If given as an ISO date, turn into an epoch number
  local y, m, d = match(epoch, "^(%d%d%d%d)-(%d%d)-(%d%d)$")
  if y then
    return os_time({
        year = y, month = m, day   = d,
        hour = 0, sec = 0, isdst = nil
      }) - os_time({
        year = 1970, month = 1, day = 1,
        hour = 0, sec = 0, isdst = nil
      })
  elseif match(epoch, "^%d+$") then
    return tonumber(epoch)
  else
    return 0
  end
end

---@class Main_t
---@field module        string
---@field bundle        string
---@field tdsroot       string
---@field ctanpkg       string
---@field ctanzip       string
---@field checkengines  string_list_t
---@field ctanreadme    string
---@field forcecheckepoch boolean
---@field epoch         integer
---@field flattentds    boolean

---@type Main_t
local Main = chooser(_G, setmetatable({
  module  = "",
  bundle  = "",
  tdsroot = "latex",
  checkengines = { "pdftex", "xetex", "luatex" },
  ctanreadme   = "README.md",
  forcecheckepoch = true,
  epoch           = 1463734800,
  flattentds      = true,
  [utlib.DID_CHOOSE] = function (result, k)
    -- No trailing /
    -- What about the leading "./"
    local options = l3build.options
    if k == "forcecheckepoch" then
      if options["epoch"] then
        return true
      end
    end
    if k == "epoch" then
      if options["epoch"] then
        result = options["epoch"]
      end
      return normalise_epoch(result)
    end
    return result
  end,
}, {
  __index = function (t, k)
    if k == "ctanpkg" then
      return  t.bundle ~= ""
          and t.bundle or t.module
    elseif k == "ctanzip" then
      return t.ctanpkg .. "-ctan"
    end
  end
}))

---@class Dir_t
---@field work        string
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
---@field local       string
---@field result      string
---@field test        string
---@field typeset     string
---@field unpack      string
---@field tds_module  string

local LOCAL = {}

---@type Dir_t
local default_Dir = setmetatable({
-- Directory structure for the build system
-- Use Unix-style path separators
  work = ".",
  [LOCAL] = "local",
  [utlib.DID_CHOOSE] = function (result, k)
    -- No trailing /
    -- What about the leading "./"
    if k.match and k:match("dir$") then
      return quoted_path(result:match("^(.-)/*$")) -- any return result will be quoted_path
    end
    return result
  end
}, {
  __index = function (t, k)
    local result
    if k == "current" then -- deprecate, not equal to the current directory.
      result = t.work
    elseif k == "main" then
      result = t.work
    elseif k == "docfile" then
      result = t.work
    elseif k == "sourcefile" then
      result = t.work
    elseif k == "textfile" then
      result = t.work
    elseif k == "support" then
      result = t.main .. "/support"
    elseif k == "testfile" then
      result = t.work .. "/testfiles"
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
---@field _all_typeset  string_list_t
---@field _all_pdffiles string_list_t
---@field typesetsupp   string_list_t
---@field typesetsource string_list_t
---@field unpack        string_list_t
---@field unpacksupp    string_list_t

---@type Files_t
local Files = chooser(_G, setmetatable({
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
}, {
  __index = function (t, k)
    if k == "_all_typeset" then
      local result = t.typeset
      for glob in entries(t.typesetdemo) do
        append(result, glob)
      end
      return result
    elseif k == "_all_pdffiles" then
      local result = {}
      for glob in entries(t.all_typeset_files) do
        append(result, first_of(gsub(glob, "%.%w+$", ".pdf")))
      end
      return result
    end
  end
}), { suffix = "files" })

-- Roots which should be unpacked to support unpacking/testing/typesetting

---@class Deps_t
---@field check   table
---@field typeset table
---@field unpack  table

---@type Deps_t
local Deps = chooser(_G, {
  check = {},
  typeset = {},
  unpack = {},
}, { suffix = "deps" })

-- Executable names plus following options

---@class Exe_t
---@field typeset   string
---@field unpack    string
---@field zip       string
---@field biber     string
---@field bibtex    string
---@field makeindex string

---@type Exe_t
local Exe = chooser(_G, {
  typeset   = "pdflatex",
  unpack    = "pdftex",
  zip       = "zip",
  biber     = "biber",
  bibtex    = "bibtex8",
  makeindex = "makeindex",
}, { suffix = "exe" })

---@class Opts_t
---@field check     string
---@field typeset   string
---@field unpack    string
---@field zip       string
---@field biber     string
---@field bibtex    string
---@field makeindex string

---@type Opts_t
local Opts  = chooser(_G, {
  check     = "-interaction=nonstopmode",
  typeset   = "-interaction=nonstopmode",
  unpack    = "",
  zip       = "-v -r -X",
  biber     = "",
  bibtex    = "-W",
  makeindex = "",
}, { suffix = "opts" })

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
---@field Exe   Exe_t
---@field Opts  Opts_t

return {
  Main              = Main,
  Xtn               = Xtn,
  LOCAL             = LOCAL,
  Dir               = Dir,
  Files             = Files,
  Deps              = Deps,
  Exe               = Exe,
  Opts              = Opts,
}
