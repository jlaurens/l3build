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

local lfs         = require("lfs")
local lfs_dir     = lfs.dir
local attributes  = lfs.attributes

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
local directory_exists  = fslib.directory_exists
local all_names         = fslib.all_names

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
---@field module        string The name of the module
---@field bundle        string The name of the bundle in which the module belongs (where relevant)
---@field ctanpkg       string Name of the CTAN package matching this module
---@field exclmodules   string_list_t Directories to be excluded from automatic module detection
---@field modules       string_list_t The list of all modules in a bundle (when not auto-detecting)
---@field forcecheckepoch boolean Force epoch when running tests
---@field ctanreadme    string  Name of the file to send to CTAN as \texttt{README.\meta{ext}}s
---@field tdsroot       string
---@field ctanzip       string  Name of the zip file (without extension) created for upload to CTAN
---@field epoch         integer Epoch (Unix date) to set for test runs
---@field tdslocations  string_list_t For non-standard file installations

---@type Main_t
local Main = chooser(_G, setmetatable({
  module          = "",
  bundle          = "",
  exclmodules     = {},
  tdsroot         = "latex",
  ctanreadme      = "README.md",
  forcecheckepoch = true,
  epoch           = 1463734800,
  flattentds      = true,
  tdslocations    = {},
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
          and t.bundle .."/".. t.module
          or  t.module
    elseif k == "ctanzip" then
      return t.ctanpkg .. "-ctan"
    elseif k == "modules" then -- dynamically create the module list
      local result = {}
      local exclmodules = t.exclmodules or {}
      for entry in all_names(require("l3b.fslib").Dir._work) do -- Dir is not yet defined
        if directory_exists(entry) and not exclmodules[entry] then
          append(result, entry)
        end
      end
      return result
    end
  end
}))

---@class Dir_t
---@field _work       string
---@field current     string
---@field main        string Top level directory for the module/bundle
---@field docfile     string Directory containing documentation files
---@field sourcefile  string Directory containing source files
---@field support     string Directory containing general support files
---@field testfile    string Directory containing test files
---@field testsupp    string Directory containing test-specific support files
---@field texmf       string Directory containing support files in tree form
---@field textfile    string Directory containing plain text files
---@field build       string Directory for building and testing
---@field distrib     string Directory for generating distribution structure
---@field local       string Directory for extracted files in \enquote{sandboxed} \TeX{} runs
---@field result      string Directory for PDF files when using PDF-based tests
---@field test        string Directory for running tests
---@field typeset     string Directory for building documentation
---@field unpack      string Directory for unpacking sources
---@field ctan        string Directory for organising files for CTAN
---@field tds         string Directory for organised files into TDS structure
---@field tds_module  string
--[[

]]
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
      result = t._work
    elseif k == "main" then
      result = t._work
    elseif k == "docfile" then
      result = t._work
    elseif k == "sourcefile" then
      result = t._work
    elseif k == "textfile" then
      result = t._work
    elseif k == "support" then
      result = t.main .. "/support"
    elseif k == "testfile" then
      result = t._work .. "/testfiles"
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
    elseif k == "tds_module" then
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
---@field aux           string_list_t Secondary files to be saved as part of running tests
---@field bib           string_list_t \BibTeX{} database files
---@field binary        string_list_t Files to be added in binary mode to zip files
---@field bst           string_list_t \BibTeX{} style files
---@field check         string_list_t Extra files unpacked purely for tests
---@field checksupp     string_list_t Files needed for performing regression tests
---@field clean         string_list_t Files to delete when cleaning
---@field demo          string_list_t Files which show how to use a module
---@field doc           string_list_t Files which are part of the documentation but should not be typeset
---@field dynamic       string_list_t Secondary files to cleared before each test is run
---@field exclude       string_list_t Files to ignore entirely (default for Emacs backup files)
---@field install       string_list_t Files to install to the \texttt{tex} area of the \texttt{texmf} tree
---@field makeindex     string_list_t MakeIndex files to be included in a TDS-style zip
---@field script        string_list_t Files to install to the \texttt{scripts} area of the \texttt{texmf} tree
---@field scriptman     string_list_t Files to install to the \texttt{doc/man} area of the \texttt{texmf} tree
---@field source        string_list_t Files to copy for unpacking
---@field tag           string_list_t Files for automatic tagging
---@field text          string_list_t Plain text files to send to CTAN as-is
---@field typesetdemo   string_list_t Files to typeset before the documentation for inclusion in main documentation files
---@field typeset       string_list_t Files to typeset for documentation
---@field typesetsupp   string_list_t Files needed to support typesetting when \enquote{sandboxed}
---@field typesetsource string_list_t Files to copy to unpacking when typesetting
---@field unpack        string_list_t Files to run to perform unpacking
---@field unpacksupp    string_list_t Files needed to support unpacking when \enquote{sandboxed}
---@field _all_typeset  string_list_t To combine `typeset` files and `typesetdemo` files
---@field _all_pdf      string_list_t Counterpart of "_all_typeset"

local Files_dflt  = {
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
  install       = { "*.sty", "*.cls" },
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
}
---@type Files_t
local Files = chooser(_G, setmetatable(Files_dflt, {
  __index = function (t, k)
    if k == "_all_typeset" then -- dynamic private key to merge typeset and typeset demo
      local result = t.typeset
      for glob in entries(t.typesetdemo) do
        append(result, glob)
      end
      return result
    elseif k == "_all_pdf" then -- dynamic private key, counterpart of "_all_typeset"
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
---@field check   string_list_t -- List of dependencies for running checks
---@field typeset string_list_t -- List of dependencies for typesetting docs
---@field unpack  string_list_t -- List of dependencies for unpacking

---@type Deps_t
local Deps = chooser(_G, {
  check = {},
  typeset = {},
  unpack = {},
}, { suffix = "deps" })

-- Executable names plus following options

---@class Exe_t
---@field typeset   string Executable for compiling \texttt{doc(s)}
---@field unpack    string Executable for running \texttt{unpack}
---@field zip       string Executable for creating archive with \texttt{ctan}
---@field biber     string Biber executable
---@field bibtex    string \BibTeX{} executable
---@field makeindex string MakeIndex executable
---@field curl      string Curl executable for \texttt{upload}

---@type Exe_t
local Exe = chooser(_G, {
  typeset   = "pdflatex",
  unpack    = "pdftex",
  zip       = "zip",
  biber     = "biber",
  bibtex    = "bibtex8",
  makeindex = "makeindex",
  curl      = "curl",
}, { suffix = "exe" })

---@class Opts_t
---@field check     string Options passed to engine when running checks
---@field typeset   string Options passed to engine when typesetting
---@field unpack    string Options passed to engine when unpacking
---@field zip       string Options passed to zip program
---@field biber     string Biber options
---@field bibtex    string \BibTeX{} options
---@field makeindex string MakeIndex options

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
---@field bak string  Extension of backup files
---@field dvi string  Extension of DVI files
---@field lvt string  Extension of log-based test files
---@field tlg string  Extension of test file output
---@field tpf string  Extension of PDF-based test output
---@field lve string  Extension of auto-generating test file output
---@field log string  Extension of checking output, before processing it into a \texttt{.tlg}
---@field pvt string  Extension of PDF-based test files
---@field pdf string  Extension of PDF file for checking and saving
---@field ps  string  Extension of PostScript files

---@type Xtn_t
local Xtn = chooser(_G, {
  bak = ".bak",
  dvi = ".dvi",
  lvt = ".lvt",
  tlg = ".tlg",
  tpf = ".tpf",
  lve = ".lve",
  log = ".log",
  pvt = ".pvt",
  pdf = ".pdf",
  ps  = ".ps" ,
})

---@class l3b_vars_t
---@field LOCAL any
---@field Main  Main_t
---@field Dir   Dir_t
---@field Files Files_t
---@field Deps  Deps_t
---@field Exe   Exe_t
---@field Opts  Opts_t
---@field Xtn   Xtn_t

return {
  LOCAL             = LOCAL,
  Main              = Main,
  Dir               = Dir,
  Files             = Files,
  Deps              = Deps,
  Exe               = Exe,
  Opts              = Opts,
  Xtn               = Xtn,
}

