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

--[=[
In former implementation, quite all variables were global.
This design rendered code maintenance very delicate because:
- the same name was used for global variables and local ones
- variable definitions were spread over the code
- names were difficult to read

How things are organized:
1) low level packages do not use global variables at all.
2) High level packages only use proxies to some global variables.
3) Setting global variables is only made in either `build.lua` or a configuration file.

Global variables are used as static parameters to customize
the behaviour of `l3build`. It means that both `preflight.lua`,
`build.lua` and configuration scripts are run in an environment
where only very few `l3build` global variables are defined.
When all these configuration scripts are executed,
a snapshot is taken of all the global variables known to `l3build`.
Any further change to a global variable will have absolutely no effect.

--]=]
local append  = table.insert
local os_time = os["time"]

---@type utlib_t
local utlib     = require("l3b-utillib")
local chooser   = utlib.chooser
local entries   = utlib.entries
local first_of  = utlib.first_of

---@type oslib_t
local oslib       = require("l3b-oslib")
local quoted_path = oslib.quoted_path

---@type fslib_t
local fslib             = require("l3b-fslib")
local set_tree_excluder = fslib.set_tree_excluder
local directory_exists  = fslib.directory_exists
local file_exists       = fslib.file_exists
local all_names         = fslib.all_names

---@type l3build_t
local l3build = require("l3build")

---Convert the given `epoch` to a number.
---@param epoch string
---@return number
---@see l3build.lua
---@usage private?
local function normalise_epoch(epoch)
  assert(epoch, 'normalize_epoch argument must not be nil')
  -- If given as an ISO date, turn into an epoch number
  if type(epoch) == "number" then
    return epoch
  end
  local y, m, d = epoch:match("^(%d%d%d%d)-(%d%d)-(%d%d)$")
  if y then
    return os_time({
        year = y, month = m, day   = d,
        hour = 0, sec = 0, isdst = nil
      }) - os_time({
        year = 1970, month = 1, day = 1,
        hour = 0, sec = 0, isdst = nil
      })
  elseif epoch:match("^%d+$") then
    return tonumber(epoch)
  else
    return 0
  end
end

---@class Main_t
---@field module        string The name of the module
---@field bundle        string The name of the bundle in which the module belongs (where relevant)
---@field ctanpkg       string Name of the CTAN package matching this module
---@field modules       string_list_t The list of all modules in a bundle (when not auto-detecting)
---@field exclmodules   string_list_t Directories to be excluded from automatic module detection
---@field tdsroot       string
---@field ctanzip       string  Name of the zip file (without extension) created for upload to CTAN
---@field epoch         integer Epoch (Unix date) to set for test runs
---@field _standalone   boolean True means the module is also the bundle
---@field _at_bundle_top    boolean True means we are at the top of the bundle

---@type Main_t
local Main

local Main_dflt = {
  module          = "",
  bundle          = "",
  exclmodules     = {},
  tdsroot         = "latex",
  epoch           = 1463734800,
}

local Main_computed = {
  _standalone = function (t, k, v_dflt)
    return not _G.bundle or _G.bundle == ""
  end,
  _at_bundle_top = function (t, k, v_dflt)
    return t.module == ""
  end,
  bundle = function (t, k, v_dflt)
    return t._standalone and t.module or _G.bundle
  end,
  ctanpkg = function (t, k, v_dflt)
    return  t._standalone
        and t.module
        or  t.bundle .."/".. t.module
  end,
  ctanzip = function (t, k, v_dflt)
    return t.ctanpkg .. "-ctan"
  end,
  modules = function (t, k, v_dflt) -- dynamically create the module list
    local result = {}
    local excl_modules = t.exclmodules or {}
    for entry in all_names(require("l3build-variables").Dir.work) do -- Dir is not yet defined
      if directory_exists(entry) and not excl_modules[entry] then
        if file_exists(entry .."/build.lua") then
          append(result, entry)
        end
      end
    end
    return result
  end,
  epoch = function (t, k, v_dflt)
    local options = l3build.options
    return options.epoch or _G["epoch"]
  end
}

Main = chooser({
  global = _G,
  default = Main_dflt,
  computed = Main_computed,
  fallback = function (t, k, v_dflt, v_G)
    -- "module" is a deprecated function in Lua 5.2: as we want the name
    -- for other purposes, and it should eventually be 'free', simply
    -- remove the built-in
    if k == "module" then
      return v_dflt
    end
  end,
  complete = function (t, k, result)
    if k == "epoch" then
      return normalise_epoch(result)
    end
    return result
  end,
})

---@class Dir_t
---@field work        string
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
local LOCAL = "local"

local work = "."

---@type Dir_t
local default_Dir = {
  work = ".",
}

---@type Dir_t
local Dir = chooser({
  global = _G,
  default =  default_Dir,
  suffix = "dir",
  computed = {
    current = function (t, k, v_dflt) -- deprecate, not equal to the current directory.
      return work
    end,
    main = function (t, k, v_dflt)
      return work
    end,
    docfile = function (t, k, v_dflt)
      return work
    end,
    sourcefile = function (t, k, v_dflt)
      return work
    end,
    textfile = function (t, k, v_dflt)
      return work
    end,
    support = function (t, k, v_dflt)
      return t.main .. "/support"
    end,
    testfile = function (t, k, v_dflt)
      return work .. "/testfiles"
    end,
    testsupp = function (t, k, v_dflt)
      return t.testfile .. "/support"
    end,
    texmf = function (t, k, v_dflt)
      return t.main .. "/texmf"
    -- Structure within a development area
    end,
    build = function (t, k, v_dflt)
      return t.main .. "/build"
    end,
    distrib = function (t, k, v_dflt)
      return t.build .. "/distrib"
    -- Substructure for CTAN release material
    end,
    ctan = function (t, k, v_dflt)
      return t.distrib .. "/ctan"
    end,
    tds = function (t, k, v_dflt)
      return t.distrib .. "/tds"
    end,
    [LOCAL] = function (t, k, v_dflt)
      return t.build .. "/local"
    end,
    result =  function (t, k, v_dflt)
      return t.build .. "/result"
    end,
    test = function (t, k, v_dflt)
      return t.build .. t._config .."/test"
    end,
    _config = function (t, k, v_dflt)
      return "" -- for example "-config-plain"
    end,
    typeset = function (t, k, v_dflt)
      return t.build .. "/doc"
    end,
    unpack = function (t, k, v_dflt)
      return t.build .. "/unpacked"
    -- Location for installation on CTAN or in TEXMFHOME
    end,
    tds_module = function (t, k, v_dflt)
      return Main.tdsroot
      .. (Main._standalone and "/" .. Main.bundle .. "/" or "/")
      .. Main.module
    end,
  },
  -- Directory structure for the build system
  -- Use Unix-style path separators
  complete = function (t, k, result)
    -- No trailing /
    -- What about the leading "./"
    if k.match and k:match("dir$") then
      return quoted_path(result:match("^(.-)/*$")) -- any return result will be quoted_path
    end
    return result
  end,
})

-- Dir.work = work TODO: what is this ?

set_tree_excluder(function (path)
  return path == Dir.build
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

local Files_computed = {
  _all_typeset = function (t, k, v_dflt)
    local tt = {}
    for glob in entries(t.typeset) do
      append(tt, glob)
    end
    for glob in entries(t.typesetdemo) do
      append(tt, glob)
    end
    return tt
  end,
  _all_pdf = function (t, k, v_dflt)
    local tt = {}
    for glob in entries(t._all_typeset) do
      append(tt, first_of(glob:gsub( "%.%w+$", ".pdf")))
    end
    return tt
  end,
}

---@type Files_t
local Files = chooser({
  global = _G,
  default = Files_dflt,
  suffix = "files",
  computed = Files_computed,
})

-- Roots which should be unpacked to support unpacking/testing/typesetting

---@class Deps_t
---@field check   string_list_t -- List of dependencies for running checks
---@field typeset string_list_t -- List of dependencies for typesetting docs
---@field unpack  string_list_t -- List of dependencies for unpacking

---@type Deps_t
local Deps = chooser({
  global = _G,
  default = {
    check = {},
    typeset = {},
    unpack = {},
  },
  suffix = "deps",
})

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
local Exe = chooser({
  global = _G,
  default = {
    typeset   = "pdflatex",
    unpack    = "pdftex",
    zip       = "zip",
    biber     = "biber",
    bibtex    = "bibtex8",
    makeindex = "makeindex",
    curl      = "curl",
  },
  suffix = "exe",
})

---@class Opts_t
---@field check     string Options passed to engine when running checks
---@field typeset   string Options passed to engine when typesetting
---@field unpack    string Options passed to engine when unpacking
---@field zip       string Options passed to zip program
---@field biber     string Biber options
---@field bibtex    string \BibTeX{} options
---@field makeindex string MakeIndex options
---@field ps2pdf    string ps2pdf options

---@type Opts_t
local Opts  = chooser({
  global = _G,
  default = {
    check     = "-interaction=nonstopmode",
    typeset   = "-interaction=nonstopmode",
    unpack    = "",
    zip       = "-v -r -X",
    biber     = "",
    bibtex    = "-W",
    makeindex = "",
    ps2pdf    = "",
  },
  suffix = "opts",
})

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
local Xtn = chooser({
  global = _G,
  default = {
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
  }
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
  LOCAL     = LOCAL,
  Main      = Main,
  Dir       = Dir,
  Files     = Files,
  Deps      = Deps,
  Exe       = Exe,
  Opts      = Opts,
  Xtn       = Xtn,
}
