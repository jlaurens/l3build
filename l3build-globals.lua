--[[

File l3build-globals.lua Copyright (C) 2018-2020 The LaTeX Project

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
Global variables are used as static parameters to customize
the behaviour of `l3build`. Default values are defined before
various configuration files are loaded and executed.

In former implementation, quite all variables were global.
This design rendered code maintenance very delicate because:
- the same name was used for global variables and local ones
- variable definitions were spread over the code
  and the lifetime was difficult to evaluate.
- names were difficult to read because
  they were too far from natural english language

The new design seems much more complicated at first glance.
It is far more user friendly though.

The central requirement is to allow the user to inspect the value
of global variables and get some dedicated description as well.
Reading the pdf documentation is now just a complement to the online documentation.

How things are organized:
1) low level packages do not use global variables at all.
2) l3build-aux package only uses l3build global namespace.
3) Othe high level packages only use bridges to some global variable sets:
  - Dir[] for directory paths
  - Files[] for file globs
  - Exe[] for executables
  - Opts[] for options
  - G for globally shared object
4) Setting global variables is only made in either `build.lua` or a configuration file.

Each global variable is defined by a table (of type variable_entry_t)
This table keeps track of
- the name
- the description
- the static value if any
- the dynamic value if any, a function
- the complete value if any, a function
All these entries are collected into one table.
The global environment will query this data base
to retrieve global variables values

The `export` function is used to export all these variables
to the global environment (or any other environment).

--]=]

-- module was a known function in lua < 5.3
-- but we need it as a "module" name
if type(_G.module) == "function" then
  module = nil
end
-- the tex name is for the "tex" command
if type(_G.tex) == "table" then
  _G.tex = nil
end

local tostring  = tostring
local print     = print
local append    = table.insert
local os_time   = os.time
local os_type   = os["type"]

local status  = require("status")

local kpse        = require("kpse")
local set_program = kpse.set_program_name
local var_value   = kpse.var_value

---@type wklib_t
local wklib     = require("l3b-walklib")
local job_name  = wklib.job_name

---@type gblib_t
local gblib   = require("l3b-globlib")

---@type utlib_t
local utlib             = require("l3b-utillib")
local bridge            = utlib.bridge
local entries           = utlib.entries
local keys              = utlib.keys
local compare_ascending = utlib.compare_ascending
local first_of          = utlib.first_of
local to_quoted_string  = utlib.to_quoted_string

---@type oslib_t
local oslib         = require("l3b-oslib")
local quoted_path   = oslib.quoted_path
local OS            = oslib.OS
local cmd_concat    = oslib.cmd_concat
local run           = oslib.run
local read_content  = oslib.read_content
local read_command  = oslib.read_command

---@type fslib_t
local fslib                 = require("l3b-fslib")
local directory_exists      = fslib.directory_exists
local file_exists           = fslib.file_exists
local all_names             = fslib.all_names
local quoted_absolute_path  = fslib.quoted_absolute_path
local get_current_directory = fslib.get_current_directory
local change_current_directory = fslib.change_current_directory

---@type l3build_t
local l3build = require("l3build")

---@type l3b_cli_t
local l3b_cli = require("l3build-cli")

---@type l3b_aux_t
local l3b_aux       = require("l3build-aux")
local set_epoch_cmd = l3b_aux.set_epoch_cmd

---@alias biber_f     fun(name: string, dir: string): error_level_n
---@alias bibtex_f    fun(name: string, dir: string): error_level_n
---@alias makeindex_f fun(name: string, dir: string, in_ext: string, out_ext: string, log_ext: string, style: string): error_level_n
---@alias tex_f       fun(file: string, dir: string, cmd: string|nil): error_level_n
---@alias typeset_f   fun(file: string, dir: string, cmd: string|nil): error_level_n

---@class special_typesetting_t
---@field func  typeset_f
---@field cmd   string

---@class test_types_t
---@field log table<string,string|function>
---@field pdf table<string,string|function>

---@alias bundleunpack_f fun(source_dirs: string[], sources: string[]): error_level_n

---@class l3b_upld_config_t
---@field announcement  string        Announcement text
---@field author        string        Author name (semicolon-separated for multiple)
---@field ctanPath      string        CTAN path
---@field email         string        Email address of uploader
---@field license       string|string[] Package license(s)\footnote{See \url{https://ctan.org/license}}
---@field pkg           string        Name of the CTAN package (defaults to G.ctanpkg)
---@field summary       string        One-line summary
---@field uploader      string        Name of uploader
---@field version       string        Package version
---@field bugtracker    string|string[] URL(s) of bug tracker
---@field description   string        Short description/abstract
---@field development   string|string[] URL(s) of development channels
---@field home          string|string[] URL(s) of home page
---@field note          string        Internal note to CTAN
---@field repository    string|string[] URL(s) of source repositories
---@field support       string|string[] URL(s) of support channels
---@field topic         string|string[] Topic(s)\footnote{See \url{https://ctan.org/topics/highscore}}
---@field update        string        Boolean \\texttt{true} for an update, \\texttt{false} for a new package
---@field announcement_file string    Announcement text  file
---@field note_file     string        Note text file
---@field curlopt_file  string        The filename containing the options passed to curl

---@class G_t
---@field module        string The name of the module
---@field bundle        string The name of the bundle in which the module belongs (where relevant)
---@field ctanpkg       string Name of the CTAN package matching this module
---@field modules       string[] The list of all modules in a bundle (when not auto-detecting)
---@field exclmodules   string[] Directories to be excluded from automatic module detection
---@field tdsroot       string
---@field ctanzip       string  Name of the zip file (without extension) created for upload to CTAN
---@field epoch         integer Epoch (Unix date) to set for test runs
---@field flattentds    boolean Switch to flatten any source structure when creating a TDS structure
---@field flattenscript boolean Switch to flatten any script structure when creating a TDS structure
---@field ctanreadme    string  Name of the file to send to CTAN as \\texttt{README.\meta{ext}}s
---@field ctanupload    boolean Undocumented
---@field tdslocations  string[] For non-standard file installations
-- unexposed computed properties
---@field is_embedded   boolean True means the module belongs to a bundle
---@field is_standalone boolean False means the module belongs to a bundle
---@field at_top        boolean True means there is no bundle above
---@field at_bundle_top boolean True means we are at the top of the bundle
---@field config        string
---@field tds_module    string
---@field tds_main      string  G.tdsroot .."/".. G.bundle or G.module
-- unexposed properties
---@field config_suffix string
-- doc related
---@field typesetsearch boolean Switch to search the system \\texttt{texmf} for during typesetting
---@field glossarystyle string  MakeIndex style file for glossary/changes creation
---@field indexstyle    string  MakeIndex style for index creation
---@field specialtypesetting table<string,special_typesetting_t>  Non-standard typesetting combinations
---@field forcedocepoch string  Force epoch when typesetting
---@field typesetcmds   string  Instructions to be passed to \TeX{} when doing typesetting
---@field typesetruns   integer Number of cycles of typesetting to carry out
-- functions
---@field runcmd        fun(cmd: string, dir: string, vars: table):boolean?, string?, integer?
---@field biber         biber_f
---@field bibtex        bibtex_f
---@field makeindex     makeindex_f
---@field tex           tex_f
---@field typeset       typeset_f
---@field typeset_demo_tasks  fun(): error_level_n
---@field docinit_hook  fun(): error_level_n
-- check fields
---@field checkengines    string[] Engines to check with \\texttt{check} by default
---@field stdengine       string  Engine to generate \\texttt{.tlg} file from
---@field checkformat     string  Format to use for tests
---@field specialformats  table  Non-standard engine/format combinations
---@field test_types      test_types_t  Custom test variants
---@field test_order      string[] Which kinds of tests to evaluate
-- Configs for testing
---@field checkconfigs    table   Configurations to use for tests
---@field includetests    string[] Test names to include when checking
---@field excludetests    string[] Test names to exclude when checking
---@field recordstatus    boolean Switch to include error level from test runs in \\texttt{.tlg} files
---@field forcecheckepoch boolean Force epoch when running tests
---@field asciiengines    string[] Engines which should log as pure ASCII
---@field checkruns       integer Number of runs to complete for a test before comparing the log
---@field checksearch     boolean Switch to search the system \\texttt{texmf} for during checking
---@field maxprintline    integer Length of line to use in log files
---@field runtest_tasks   fun(test_name: string, run_number: integer): string
---@field checkinit_hook  fun(): error_level_n
---@field ps2pdfopt       string  Options for \\texttt{ps2pdf}
---@field unpacksearch    boolean  Switch to search the system \\texttt{texmf} for during unpacking
---@field bundleunpack    bundleunpack_f  bundle unpack overwrite
---@field flatten         boolean Switch to flatten any source structure when sending to CTAN
---@field packtdszip      boolean Switch to build a TDS-style zip file for CTAN
---@field manifestfile    string File name to use for the manifest file
---@field curl_debug      boolean
---@field uploadconfig    l3b_upld_config_t Metadata to describe the package for CTAN (see Table~\ref{tab:upload-setup})
---@field texmf_home      string
---@field typeset_list    string[]
-- tag
---@field tag_hook        tag_hook_f
---@field update_tag      update_tag_f

---@type G_t
local G

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
---@field local       string Directory for extracted files in sandboxed \TeX{} runs
---@field result      string Directory for PDF files when using PDF-based tests
---@field test        string Directory for running tests
---@field typeset     string Directory for building documentation
---@field unpack      string Directory for unpacking sources
---@field ctan        string Directory for organising files for CTAN
---@field tds         string Directory for organised files into TDS structure
---@field test_config string Computed directory for running tests

---@type Dir_t
local Dir

-- File types for various operations
-- Use Unix-style globs
-- All of these may be set earlier, so a initialised conditionally

---@class Files_t
---@field aux           string[] Secondary files to be saved as part of running tests
---@field bib           string[] \BibTeX{} database files
---@field binary        string[] Files to be added in binary mode to zip files
---@field bst           string[] \BibTeX{} style files
---@field check         string[] Extra files unpacked purely for tests
---@field checksupp     string[] Files needed for performing regression tests
---@field clean         string[] Files to delete when cleaning
---@field demo          string[] Files which show how to use a module
---@field doc           string[] Files which are part of the documentation but should not be typeset
---@field dynamic       string[] Secondary files to cleared before each test is run
---@field exclude       string[] Files to ignore entirely (default for Emacs backup files)
---@field install       string[] Files to install to the \\texttt{tex} area of the \\texttt{texmf} tree
---@field makeindex     string[] MakeIndex files to be included in a TDS-style zip
---@field script        string[] Files to install to the \\texttt{scripts} area of the \\texttt{texmf} tree
---@field scriptman     string[] Files to install to the \\texttt{doc/man} area of the \\texttt{texmf} tree
---@field source        string[] Files to copy for unpacking
---@field tag           string[] Files for automatic tagging
---@field text          string[] Plain text files to send to CTAN as-is
---@field typesetdemo   string[] Files to typeset before the documentation for inclusion in main documentation files
---@field typeset       string[] Files to typeset for documentation
---@field typesetsupp   string[] Files needed to support typesetting when \enquote{sandboxed}
---@field typesetsource string[] Files to copy to unpacking when typesetting
---@field unpack        string[] Files to run to perform unpacking
---@field unpacksupp    string[] Files needed to support unpacking when \enquote{sandboxed}
---@field _all_typeset  string[] To combine `typeset` files and `typesetdemo` files
---@field _all_pdf      string[] Counterpart of "_all_typeset"

---@type Files_t
local Files

---@class Deps_t
---@field check   string[] -- List of dependencies for running checks
---@field typeset string[] -- List of dependencies for typesetting docs
---@field unpack  string[] -- List of dependencies for unpacking

---@type Deps_t
local Deps = bridge({
  suffix = "deps",
})

-- Executable names plus following options

---@class Exe_t
---@field typeset   string Executable for compiling \\texttt{doc(s)}
---@field unpack    string Executable for running \\texttt{unpack}
---@field zip       string Executable for creating archive with \\texttt{ctan}
---@field biber     string Biber executable
---@field bibtex    string \BibTeX{} executable
---@field makeindex string MakeIndex executable
---@field curl      string Curl executable for \\texttt{upload}

---@type Exe_t
local Exe = bridge({
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

---@type Opts_t
local Opts = bridge({
  suffix = "opts"
})

-- Extensions for various file types: used to abstract out stuff a bit

---@class Xtn_t
---@field bak string  Extension of backup files
---@field dvi string  Extension of DVI files
---@field lvt string  Extension of log-based test files
---@field tlg string  Extension of test file output
---@field tpf string  Extension of PDF-based test output
---@field lve string  Extension of auto-generating test file output
---@field log string  Extension of checking output, before processing it into a \\texttt{.tlg}
---@field pvt string  Extension of PDF-based test files
---@field pdf string  Extension of PDF file for checking and saving
---@field ps  string  Extension of PostScript files

---@type Xtn_t
local Xtn = bridge({
  suffix = "ext", -- Xtn.bak -> _G.bakext
})

--[==[ Main variable query business
Allows a module to get the value of a global variable
of its owning main bundle. Can catch values defined in `build.lua`
but not in configuration files.
Used for "l3build --get-global-variable bundle"
and      "l3build --get-global-variable maindir"
]==]

---Get the variable with the given name,
---@param name string
---@return string|nil
local function get_main_variable(name)
  local cwd = get_current_directory()
  change_current_directory(l3build.main_dir)
  local cmd = to_quoted_string({
    "texlua",
    quoted_path(l3build.script_path),
    "status",
    "--".. l3b_cli.GET_MAIN_VARIABLE,
    name,
  })
  local t
  local ok, msg = pcall(function ()
    t = read_command(cmd)
  end)
  change_current_directory(cwd)
  if ok then
    local k, v = t:match("GLOBAL VARIABLE: name = (.-), value = (.*)")
    return name == k and v or nil
  else
    error(msg)
  end
end

---Print the correct message such that one can parse it
---and retrieve the value. Os agnostic method.
---@param name    string
---@param config  string[]
---@return error_level_n
local function handle_get_main_variable(name, config)
  name = name or "MISSING VARIABLE NAME"
  local f, msg = loadfile(l3build.work_dir .. "/build.lua")
  if not f then
    error(msg)
  end
  f() -- ignore any output
  print(("GLOBAL VARIABLE: name = %s, value = %s")
    :format(name, tostring(G[name])))
  return 0
end

local dot_dir = "."

-- default static values for variables

local function NYI()
  error("Missing implementation")
end

---@class variable_entry_t
---@field name        string
---@field description string
---@field value       any
---@field index       fun(t: table, k: string): any
---@field complete    fun(t: table, k: string, v: any): any

---@type table<string,variable_entry_t>
local DB = {}
---Declare the given variable
---@param by_name table<string,variable_entry_t>
local function declare(by_name)
  for name, entry in pairs(by_name) do
    assert(not DB[name], "Duplicate declaration ".. tostring(name))
    entry.name  = name
    DB[name]    = entry
  end
end

---Get the variable entry for the given name.
---@param name string
---@return variable_entry_t
local function get_entry(name)
  return DB[name]
end

local specialformats = {
  context = {
    luatex = { binary = "context", format = "" },
    pdftex = { binary = "texexec", format = "" },
    xetex  = { binary = "texexec", format = "", options = "--xetex" }
  },
  latex = {
    etex  = { format = "latex" },
    ptex  = { binary = "eptex" },
    uptex = { binary = "euptex" }
  }
}

if not status.banner:find(" 2019") then
  specialformats.latex.luatex = {
    binary = "luahbtex",
    format = "lualatex"
  }
  specialformats["latex-dev"] = {
    luatex = {
      binary ="luahbtex",
      format = "lualatex-dev"
    }
  }
end

---Bundle and module names can sometimes be guessed.
---Bundles and modules are directories containing a
---`build.lua` at the top.
---In general a bundle contains modules at its top level
---whereas modules do not.
---The standard bundle organization is illustrated
---by the examples.
---The bundle and module variables are not really meant
---to change during execution once they are initialized
---but this is not a requirement.
---One shot function.
---@usage after the `build.lua` has been executed.
local function guess_bundle_module()
  -- bundle and module values are very important
  -- because they control the behaviour of somme actions
  -- they also control where things are stored.
  -- Find bundle and module names defined by the client
  local bundle = rawget(_G, "bundle") -- do not fall back
  local module = rawget(_G, "module") -- to the metatable
  -- We act as if bundle and module were not already provided.
  -- This allows to make tests and eventually inform the user
  -- of a non standard shape, in case she has made a mistake.
  if G.is_embedded then
    -- A module inside a bundle: the current directory is
    -- .../<bundle>/<module>/...
    -- The bundle name must be provided, but can be a void string
    -- When missing, it is read from the the parent's `build.lua`
    -- We cannot execute the parent's script because
    -- this script may perform actions and change files (see latex2e)
    -- So we parse the content finger crossed.
    local s = read_content(l3build.main_dir .."build.lua")
    s = s:match("%f[%w]bundle%s*=%s*'([^']*)'")
          or s:match('%f[%w]bundle%s*=%s*"([^"]*)"')
          or s:match('%f[%w]bundle%s*=%s*%[%[([^]]*)%]%]')
    if not s then -- bundle name is required in bundle/module shape
      error('Missing in top `build.lua`: bundle = "<bundle name>"')
    end
    -- is it consistent?
    if not bundle then
      bundle = s
    elseif bundle ~= s then
      print(("Warning, bundle names are not consistent: %s and %s")
            :format(bundle, s))
    end
    -- embedded module names are the base name
    s = Dir.work:match("([^/]+)/$"):lower()
    if not module then
      module = s
    elseif module ~= s then
      print(("Warning, module names are not consistent: %s and %s")
            :format(module, s))
    end
  else -- not an embeded module
    local modules = G.modules
    if #modules > 0 then
      -- this is a top bundle,
      -- the bundle name must be provided
      -- the module name does not make sense
      if not bundle or bundle == "" then
        error('Missing in top build.lua: bundle = "<bundle name>"')
      end
      if module and module ~= "" then
        print("Warning, module name ignored: ".. module)
      end
      module = "" -- not nil!
    elseif bundle then
      -- this is a bundle with no modules,
      -- like latex2e
      if module and module ~= "" then
        print("Warning, module name ignored: ".. module)
      end
      module = "" -- not nil!
    elseif not module or module == "" then
      -- this is a standalone module (not in a bundle),
      -- the module name must be provided append
      -- the bundle name does not make sense
      error('Missing in top build.lua: module = "<module name>"')
    end
  end
  -- MISSING naming constraints
  rawset(_G, "bundle", bundle)
  rawset(_G, "module", module)
  -- One shot function: next call is a do nothing action.
  guess_bundle_module = function () end
end

declare({
  module = {
    description = "The name of the module",
    index = function (t, k)
      guess_bundle_module()
      return rawget(t, k)
    end,
  },
  bundle = {
    description = "The name of the bundle in which the module belongs (where relevant)",
    index = function (t, k)
      guess_bundle_module()
      return rawget(t, k)
    end,
  },
  ctanpkg = {
    description = "Name of the CTAN package matching this module",
    index = function (t, k)
      return  t.is_standalone
          and t.module
          or (t.bundle .."/".. t.module)
    end,
  },
  modules = {
    description = "The list of all modules in a bundle (when not auto-detecting)",
    index = function (t, k)
      local result = {}
      local excl_modules = t.exclmodules
      for name in all_names(Dir.work) do
        if directory_exists(name) and not excl_modules[name] then
          if file_exists(name .."/build.lua") then
            append(result, name)
          end
        end
      end
      return result
    end,
  },
  exclmodules = {
    description = "Directories to be excluded from automatic module detection",
    value = {},
  },
  options = {
    index = function (t, k)
      return l3build.options
    end,
  },
})
-- directory structure
declare({
  maindir = {
    description = "Top level directory for the module/bundle",
    index = function (t, k)
      if t.is_embedded then
        -- retrieve the maindir from the main build.lua
        local s = get_main_variable(k)
        if s then
          return s
        end
      end
      return l3build.main_dir:sub(1, -2)
    end,
  },
  docfiledir = {
    description = "Directory containing documentation files",
    value = ".",
  },
  sourcefiledir = {
    description = "Directory containing source files",
    value = ".",
  },
  supportdir = {
    description = "Directory containing general support files",
    index = function (t, k)
      return t.maindir .. "/support"
    end,
  },
  testfiledir = {
    description = "Directory containing test files",
    index = function (t, k)
      return dot_dir .. "/testfiles"
    end,
  },
  testsuppdir = {
    description = "Directory containing test-specific support files",
    index = function (t, k)
      return t.testfiledir .. "/support"
    end
  },
  texmfdir = {
    description = "Directory containing support files in tree form",
    index = function (t, k)
      return t.maindir .. "/texmf"
    end
  },
  -- Structure within a development area
  textfiledir = {
    description = "Directory containing plain text files",
    value = dot_dir,
  },
  builddir = {
    description = "Directory for building and testing",
    index = function (t, k)
      return t.maindir .. "/build"
    end
  },
  distribdir = {
    description = "Directory for generating distribution structure",
    index = function (t, k)
      return t.builddir .. "/distrib"
    end
  },
  -- Substructure for CTAN release material
  localdir = {
    description = "Directory for extracted files in \\enquote{sandboxed} \\TeX{} runs",
    index = function (t, k)
      return t.builddir .. "/local"
    end
  },
  resultdir = {
    description = "Directory for PDF files when using PDF-based tests",
    index = function (t, k)
      return t.builddir .. "/result"
    end
  },
  testdir = {
    description = "Directory for running tests",
    index = function (t, k)
      return t.builddir .. "/test" .. t.config_suffix
    end
  },
  config_suffix = {
    -- overwritten after load_unique_config call
    index = function (t, k)
      return ""
    end,
  },
  typesetdir = {
    description = "Directory for building documentation",
    index = function (t, k)
      return t.builddir .. "/doc"
    end
  },
  unpackdir = {
    description = "Directory for unpacking sources",
    index = function (t, k)
      return t.builddir .. "/unpacked"
    end
  },
  ctandir = {
    description = "Directory for organising files for CTAN",
    index = function (t, k)
      return t.distribdir .. "/ctan"
    end
  },
  tdsdir = {
    description = "Directory for organised files into TDS structure",
    index = function (t, k)
      return t.distribdir .. "/tds"
    end
  },
})
declare({
  tdsroot = {
    description = "Root directory of the TDS structure for the bundle/module to be installed into",
    value = "latex",
  },
  ctanupload = {
    description = "Only validation is attempted",
    value = false,
  },
})
-- file globs
declare({
  auxfiles = {
    description = "Secondary files to be saved as part of running tests",
    value = { "*.aux", "*.lof", "*.lot", "*.toc" },
  },
  bibfiles = {
    description = "\\BibTeX{} database files",
    value = { "*.bib" },
  },
  binaryfiles = {
    description = "Files to be added in binary mode to zip files",
    value = { "*.pdf", "*.zip" },
  },
  bstfiles = {
    description = "BibTeX style files to install",
    value = { "*.bst" },
  },
  checkfiles = {
    description = "Extra files unpacked purely for tests",
    value = {},
  },
  checksuppfiles = {
    description = "Files in the support directory needed for regression tests",
    value = {},
  },
  cleanfiles = {
    description = "Files to delete when cleaning",
    value = { "*.log", "*.pdf", "*.zip" },
  },
  demofiles = {
    description = "Demonstration files to use a module",
    value = {},
  },
  docfiles = {
    description = "Files which are part of the documentation but should not be typeset",
    value = {},
  },
  dynamicfiles = {
    description = "Secondary files to be cleared before each test is run",
    value = {},
  },
  excludefiles = {
    value = { "*~" },
    description = "Files to ignore entirely (default for Emacs backup files)",
  },
  installfiles = {
    description = "Files to install under the `tex` area of the `texmf` tree",
    value = { "*.sty", "*.cls" },
  },
  makeindexfiles = {
    description = "MakeIndex files to be included in a TDS-style zip",
    value = { "*.ist" },
  },
  scriptfiles = {
    description = "Files to install to the \\texttt{scripts} area of the \\texttt{texmf} tree",
    value = {},
  },
  scriptmanfiles = {
    description = "Files to install to the \\texttt{doc/man} area of the \\texttt{texmf} tree",
    value = {},
  },
  sourcefiles = {
    description = "Files to copy for unpacking",
    value = { "*.dtx", "*.ins", "*-????-??-??.sty" },
  },
  tagfiles = {
    description = "Files for automatic tagging",
    value = { "*.dtx" },
  },
  textfiles = {
    description = "Plain text files to send to CTAN as-is",
    value = { "*.md", "*.txt" },
  },
  typesetdemofiles = {
    description = "Files to typeset before the documentation for inclusion in main documentation files",
    value = {},
  },
  typesetfiles = {
    description = "Files to typeset for documentation",
    value = { "*.dtx" },
  },
  typesetsuppfiles = {
    description = "Files needed to support typesetting when sandboxed",
    value = {},
  },
  typesetsourcefiles = {
    description = "Files to copy to unpacking when typesetting",
    value = {},
  },
  unpackfiles = {
    description = "Files to run to perform unpacking",
    value = { "*.ins" },
  },
  unpacksuppfiles = {
    description = "Files needed to support unpacking when \\enquote{sandboxed}",
    value = {},
  },
})
-- check
declare({
  includetests = {
    description = "Test names to include when checking",
    value = { "*" },
  },
  excludetests = {
    description = "Test names to exclude when checking",
    value = {},
  },
  checkdeps = {
    description = "List of dependencies for running checks",
    value = {},
  },
  typesetdeps = {
    description = "List of dependencies for typesetting docs",
    value = {},
  },
  unpackdeps = {
    description = "List of dependencies for unpacking",
    value = {},
  },
  checkengines = {
    description = "Engines to check with \\texttt{check} by default",
    value = { "pdftex", "xetex", "luatex" },
  },
  stdengine = {
    description = "Engine to generate `.tlg` files",
    value = "pdftex",
  },
  checkformat = {
    description = "Format to use for tests",
    value = "latex",
  },
  specialformats = {
    description = "Non-standard engine/format combinations",
    value = specialformats,
  },
  test_types = {
    description = "Custom test variants",
    index = function (t, k)
      ---@type l3b_check_t
      local l3b_check = require("l3build-check")
      return {
        log = {
          test        = Xtn.lvt,
          generated   = Xtn.log,
          reference   = Xtn.tlg,
          expectation = Xtn.lve,
          compare     = l3b_check.compare_tlg,
          rewrite     = l3b_check.rewrite_log,
        },
        pdf = {
          test      = Xtn.pvt,
          generated = Xtn.pdf,
          reference = Xtn.tpf,
          rewrite   = l3b_check.rewrite_pdf,
        }
      }
    end,
  },
  test_order = {
    description = "Which kinds of tests to perform, keys of `test_types`",
    value = { "log", "pdf" },
  },
  checkconfigs = {
    description = "Configurations to use for tests",
    value = {  "build"  },
    complete = function (t, k, result)
      local options = l3build.options
      -- When we have specific files to deal with, only use explicit configs
      -- (or just the std one)
      -- TODO: Justify this...
      if options.names then
        return options.config or { _G.stdconfig }
      else
        return options.config or result
      end
    end
  },
})
-- Executable names
declare({
  typesetexe = {
    description = "Executable for running `doc`",
    value = "pdflatex",
  },
  unpackexe = {
    description = "Executable for running `unpack`",
    value = "pdftex",
  },
  zipexe = {
    description = "Executable for creating archive with `ctan`",
    value = "zip",
  },
  biberexe = {
    description = "Biber executable",
    value = "biber",
  },
  bibtexexe = {
    description = "BibTeX executable",
    value = "bibtex8",
  },
  makeindexexe = {
    description = "MakeIndex executable",
    value = "makeindex",
  },
  curlexe = {
    description = "Curl executable for `upload`",
    value = "curl",
  },
})
-- CLI Options
declare({
  checkopts = {
    description = "Options passed to engine when running checks",
    value = "-interaction=nonstopmode",
  },
  typesetopts = {
    description = "Options passed to engine when typesetting",
    value = "-interaction=nonstopmode",
  },
  unpackopts = {
    description = "Options passed to engine when unpacking",
    value = "",
  },
  zipopts = {
    description = "Options passed to zip program",
    value = "-v -r -X",
  },
  biberopts = {
    description = "Biber options",
    value = "",
  },
  bibtexopts = {
    description = "BibTeX options",
    value = "-W",
  },
  makeindexopts = {
    description = "MakeIndex options",
    value = "",
  },
})

declare({
  config = {
    value = "",
  },
  curl_debug  = {
    value = false,
  },
})

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

declare({
  -- Enable access to trees outside of the repo
  -- As these may be set false, a more elaborate test than normal is needed
  typesetsearch = {
    description = "Switch to search the system `texmf` for during typesetting",
    value = true,
  },
  unpacksearch = {
    description = "Switch to search the system `texmf` for during unpacking",
    value = true,
  },
  -- Additional settings to fine-tune typesetting
  glossarystyle = {
    description = "MakeIndex style file for glossary/changes creation",
    value = "gglo.ist",
  },
  indexstyle = {
    description = "MakeIndex style for index creation",
    value = "gind.ist",
  },
  specialtypesetting = {
    description = "Non-standard typesetting combinations",
    value = {},
  },
  forcecheckepoch = {
    description = "Force epoch when running tests",
    value = "true",
    complete = function (t, k, result)
      local options = l3build.options
      if options.epoch then
        return true
      end
      return result
    end
  },
  forcedocepoch = {
    description = "Force epoch when typesetting",
    value = "false",
    complete = function (t, k, result)
      local options = l3build.options
      return (options.epoch or result) and true or false
    end,
  },
  asciiengines = {
    description = "Engines which should log as pure ASCII",
    value = { "pdftex" },
  },
  checkruns = {
    description = "Number of runs to complete for a test before comparing the log",
    value = 1,
  },
  ctanreadme = {
    description = "Name of the file to send to CTAN as \\texttt{README.\\meta{ext}}",
    value = "README.md",
  },
  ctanzip = {
    description = "Name of the zip file (without extension) created for upload to CTAN",
    index = function (t, k)
      return t.ctanpkg .. "-ctan"
    end,
  },
  epoch = {
    description = "Epoch (Unix date) to set for test runs",
    index = function (t, k)
      local options = l3build.options
      return options.epoch or _G.epoch or 1463734800
    end,
    complete = function (t, k, result)
      return normalise_epoch(result)
    end,
  },
  flatten = {
    description = "Switch to flatten any source structure when sending to CTAN",
    value = true,
  },
  flattentds = {
    description = "Switch to flatten any source structure when creating a TDS structure",
    value = true,
  },
  flattenscript = {
    description = "Switch to flatten any script structure when creating a TDS structure",
    index = function (t, k)
      return G.flattentds -- by defaut flattentds and flattenscript are synonyms
    end,
  },
  maxprintline = {
    description = "Length of line to use in log files",
    value = 79,
  },
  packtdszip = {
    description = "Switch to build a TDS-style zip file for CTAN",
    value = false,
  },
  ps2pdfopts = {
    description = "Options for `ps2pdf`",
    value = "",
  },
  typesetcmds = {
    description = "Instructions to be passed to TeX when doing typesetting",
    value = "",
  },
  typesetruns = {
    description = "Number of cycles of typesetting to carry out",
    value = 3,
  },
  recordstatus = {
    description = "Switch to include error level from test runs in `.tlg` files",
    value = false,
  },
  manifestfile = {
    description = "File name to use for the manifest file",
    value = "MANIFEST.md",
  },
  tdslocations = {
    description = "For non-standard file installations",
    value = {},
  },
  uploadconfig = {
    value = {},
    description = "Metadata to describe the package for CTAN (see Table~\\ref{tab:upload-setup})",
    index =  function (t, k)
      return setmetatable({}, {
        __index = function (tt, kk)
          if kk == "pkg" then
            return t.ctanpkg
          end
        end
      })
    end,
  }
})
-- file extensions
declare({
  bakext = {
    description = "Extension of backup files",
    value = ".bak",
  },
  dviext = {
    description = "Extension of DVI files",
    value = ".dvi",
  },
  lvtext = {
    description = "Extension of log-based test files",
    value = ".lvt",
  },
  tlgext = {
    description = "Extension of test file output",
    value = ".tlg",
  },
  tpfext = {
    description = "Extension of PDF-based test output",
    value = ".tpf",
  },
  lveext = {
    description = "Extension of auto-generating test file output",
    value = ".lve",
  },
  logext = {
    description = "Extension of checking output, before processing it into a \\texttt{.tlg}",
    value = ".log",
  },
  pvtext = {
    description = "Extension of PDF-based test files",
    value = ".pvt",
  },
  pdfext = {
    description = "Extension of PDF file for checking and saving",
    value = ".pdf",
  },
  psext = {
    description = "Extension of PostScript files",
    value = ".ps",
  }
})

declare({
  abspath = {
    description =
[[Usage: `abspath("foo.bar")`
Returns "/absolute/path/to/foo.bar" on unix like systems
and "C:\absolute\path\to\foo.bar" on windows.
]],
    value = fslib.absolute_path,
  },
  dirname = {
    description =
[[Usage: `dirname("path/to/foo.bar")`
Returns "path/to".
]],
    value = wklib.dir_name,
  },
  basename = {
    description =
[[Usage: `basename("path/to/foo.bar")`
Returns "foo.bar".
]],
    value = wklib.base_name,
  },
  cleandir = {
    description =
[[Usage: `cleandir("path/to/dir")`
Removes any content in "path/to/dir" directory.
Returns 0 on success, a positive number on error.
]],
    value = fslib.make_clean_directory,
  },
  cp = {
    description =
[[Usage: `cp("*.bar", "path/to/source", "path/to/destination")`
Copies files matching the "*.bar" from "path/to/source" directory
to the "path/to/destination" directory.
Returns 0 on success, a positive number on error.
]],
    value = fslib.copy_tree,
  },
  direxists = {
    description =
[[`direxists("path/to/dir")`
Returns `true` if there is a directory at "path/to/dir",
`false` otherwise.
]],
    value = fslib.directory_exists,
  },
  fileexists = {
    description =
[[`fileexists("path/to/foo.bar")`
Returns `true` if there is a file at "path/to/foo.bar",
`false` otherwise.
]],
    value = fslib.file_exists,
  },
  filelist = {
    description =
[[`filelist("path/to/dir", "*.bar")
Returns a regular table of all the files within "path/to/dir"
which name matches "*.bar";
if no glob is provided, returns a list of
all files at "path/to/dir".]],
    value = fslib.file_list,
  },
  glob_to_pattern = {
    description =
[[`glob_to_pattern("*.bar")`
Returns Lua pattern that corresponds to the glob "*.bar".
]],
    value = gblib.glob_to_pattern,
  },
  to_glob_match = {
    description = 
[[`f = to_glob_match("*.bar")`
Returns a function that returns true if its file name argument
matches "*.bar", false otherwise.Lua pattern that corresponds to the glob "*.bar".
In that example `f("foo.bar") == true` whereas `f("foo.baz") == false`.
]],
    value = gblib.to_glob_match,
  },
  jobname = {
    description =
[[`jobname("path/to/dir/foo.bar")`
Returns the argument with no extension and no parent directory path,
"foo" in the example. 
]],
    value = wklib.job_name,
  },
  mkdir = {
    description =
[[`mkdir("path/to/dir")`
Create "path/to/dir" with all intermediate levels;
returns 0 on success, a positive number on error.]],
    value = fslib.make_directory,
  },
  ren = {
    description =
[[`ren("foo.bar", "path/to/source", "path/to/destination")`
Renames "path/to/source/foo.bar" into "path/to/destination/foo.bar";
returns 0 on success, a positive number on error.]],
    value = fslib.rename,
  },
  rm = {
    description =
[[`rm("path/to/dir", "*.bar")
Removes all files in "path/to/dir" matching "*.bar";
returns 0 on success, a positive number on error.]],
    value = fslib.remove_tree,
  },
  run = {
    description =
[[Executes `cmd`, from the `dir` directory;
returns an error level.]],
    value = oslib.run,
  },
  splitpath = {
    description =
[[Returns two strings split at the last |/|: the `dirname(...)` and
the |basename(...)|.]],
    value = wklib.dir_base,
  },
  normalize_path = {
    description =
[[When called on Windows, returns a string comprising the `path` argument with
`/` characters replaced by `\\`. In other cases returns the path unchanged.]],
    value = fslib.to_host,
  },
  call = {
    description =
[[Runs the  `l3build` `target` (a string) for each directory in the
`dirs` list. This will pass command line options from the parent
script to the child processes. The `options` table should take the
same form as the global `options`, described above. If it is
absent then the global list is used.
Note that the `target` field in this table is ignored.]],
    value = l3b_aux.call,
  },
  install_files = {
    description = "",
    value = NYI, -- l3b_inst.install_files,
  },
  manifest_setup = {
    description = "",
    value = NYI,
  },
  manifest_extract_filedesc = {
    description = "",
    value = NYI,
  },
  manifest_write_subheading = {
    description = "",
    value = NYI,
  },
  manifest_sort_within_match = {
    description = "",
    value = NYI,
  },
  manifest_sort_within_group = {
    description = "",
    value = NYI,
  },
  manifest_write_opening = {
    description = "",
    value = NYI,
  },
  manifest_write_group_heading = {
    description = "",
    value = NYI,
  },
  manifest_write_group_file_descr = {
    description = "",
    value = NYI,
  },
  manifest_write_group_file = {
    description = "",
    value = NYI,
  },
})

declare({
  os_concat = {
    description = "The concatenation operation for using multiple commands in one system call",
    value = OS.concat,
  },
  os_null = {
    description = "The location to redirect commands which should produce no output at the terminal: almost always used preceded by `>`",
    value = OS.null,
  },
  os_pathsep = {
    description = "The separator used when setting an environment variable to multiple paths.",
    value = OS.pathsep,
  },
  os_setenv = {
    description = "The command to set an environmental variable.",
    value = OS.setenv,
  },
  os_yes = {
    description = "DEPRECATED.",
    value = OS.yes,
  },
  os_ascii = {
    -- description = "",
    value = OS.ascii,
  },
  os_cmpexe = {
    -- description = "",
    value = OS.cmpexe,
  },
  os_cmpext = {
    -- description = "",
    value = OS.cmpext,
  },
  os_diffexe = {
    -- description = "",
    value = OS.diffexe,
  },
  os_diffext = {
    -- description = "",
    value = OS.diffext,
  },
  os_grepexe = {
    -- description = "",
    value = OS.grepexe,
  },
})

local LOCAL = "local"

-- An auxiliary used to set up the environmental variables
---comment
---@param cmd   string
---@param dir?  string
---@param vars? table
---@return boolean?  suc
---@return exitcode? exitcode
---@return integer?  code
local function runcmd(cmd, dir, vars)
  dir = quoted_absolute_path(dir or ".")
  vars = vars or {}
  -- Allow for local texmf files
  local env = OS.setenv .. " TEXMFCNF=." .. OS.pathsep
  local local_texmf = ""
  if Dir.texmf and Dir.texmf ~= "" and directory_exists(Dir.texmf) then
    local_texmf = OS.pathsep .. quoted_absolute_path(Dir.texmf) .. "//"
  end
  local env_paths = "." .. local_texmf .. OS.pathsep
    .. quoted_absolute_path(Dir[LOCAL]) .. OS.pathsep
    .. dir .. (G.typesetsearch and OS.pathsep or "")
  -- Deal with spaces in paths
  if os_type == "windows" and env_paths:match(" ") then
    env_paths = first_of(env_paths:gsub('"', '')) -- no '"' in windows!!!
  end
  for var in entries(vars) do
    env = cmd_concat(env, OS.setenv .. " " .. var .. "=" .. env_paths)
  end
  print("set_epoch_cmd(G.epoch, G.forcedocepoch)", set_epoch_cmd(G.epoch, G.forcedocepoch))
  print(env)
  print(cmd)
  return run(dir, cmd_concat(set_epoch_cmd(G.epoch, G.forcedocepoch), env, cmd))
end

---biber
---@param name string
---@param dir string
---@return error_level_n
local function biber(name, dir)
  if file_exists(dir .. "/" .. name .. ".bcf") then
    return G.runcmd(
      Exe.biber .. " " .. Opts.biber .. " " .. name,
      dir,
      { "BIBINPUTS" }
    ) and 0 or 1
  end
  return 0
end

---comment
---@param name string
---@param dir string
---@return error_level_n
local function bibtex(name, dir)
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
        OS.grepexe .. " \"^" .. grep .. "citation{\" " .. name .. ".aux > "
          .. OS.null
      ) + run(dir,
        OS.grepexe .. " \"^" .. grep .. "bibdata{\" " .. name .. ".aux > "
          .. OS.null
      ) == 0 then
      return G.runcmd(
        Exe.bibtex .. " " .. Opts.bibtex .. " " .. name,
        dir,
        { "BIBINPUTS", "BSTINPUTS" }
      ) and 0 or 1
    end
  end
  return 0
end

---comment
---@param name string
---@param dir string
---@param in_ext string
---@param out_ext string
---@param log_ext string
---@param style string
---@return error_level_n
local function makeindex(name, dir, in_ext, out_ext, log_ext, style)
  dir = dir or "." -- Why is it optional ?
  if file_exists(dir .. "/" .. name .. in_ext) then
    if style == "" then style = nil end
    return G.runcmd(
      Exe.makeindex .. " " .. Opts.makeindex
        .. " -o " .. name .. out_ext
        .. (style and (" -s " .. style) or "")
        .. " -t " .. name .. log_ext .. " "  .. name .. in_ext,
      dir,
      { "INDEXSTYLE" }
    ) and 0 or 1
  end
  return 0
end

---TeX
---@param file string
---@param dir string
---@param cmd string|nil
---@return error_level_n
local function tex(file, dir, cmd)
  cmd = cmd or Exe.typeset .." ".. Opts.typeset
  return G.runcmd(cmd .. " \"" .. G.typesetcmds
    .. "\\input " .. file .. "\"",
    dir, { "TEXINPUTS", "LUAINPUTS" }) and 0 or 1
end

---typeset. Default command is the same as for `tex`.
---@param file string
---@param dir string
---@param cmd string|nil
---@return error_level_n
local function typeset(file, dir, cmd)
  local error_level = G.tex(file, dir, cmd)
  if error_level ~= 0 then
    return error_level
  end
  local name = job_name(file)
  error_level = G.biber(name, dir) + G.bibtex(name, dir)
  if error_level ~= 0 then
    return error_level
  end
  for i = 2, G.typesetruns do
    error_level = G.makeindex(name, dir, ".glo", ".gls", ".glg", G.glossarystyle)
                + G.makeindex(name, dir, ".idx", ".ind", ".ilg", G.indexstyle)
                + G.tex(file, dir, cmd)
    if error_level ~= 0 then break end
  end
  return error_level
end

---Do nothing function
---@return error_level_n
local function typeset_demo_tasks()
  return 0
end

---Do nothing function
---@return error_level_n
local function docinit_hook()
  return 0
end

---Default function that can be overwritten
---@return error_level_n
local function checkinit_hook()
  return 0
end

---comment
---@param test_name string
---@param run_number integer
---@return string
local function runtest_tasks(test_name, run_number)
  return ""
end

declare({
  biber = {
    description =
[[Runs Biber on file `name` (i.e a jobname lacking any extension)
inside the dir` folder. If there is no `.bcf` file then
no action is taken with a return value of `0`.]],
    value = biber,
  },
  bibtex = {
    description =
[[Runs BibTeX on file `name` (i.e a jobname lacking any extension)
inside the `dir` folder. If there are no `\citation` lines in
the `.aux` file then no action is taken with a return value of `0`.]],
    value = bibtex,
  },
  tex = {
    description =
[[Runs `cmd` (by default `typesetexe` `typesetopts`) on the
`name` inside the `dir` folder.]],
    value = tex,
  },
  makeindex = {
    description =
[[Runs MakeIndex on file `name` (i.e a jobname lacking any extension)
inside the `dir` folder. The various extensions and the `style`
should normally be given as standard for MakeIndex.]],
    value = makeindex,
  },
  runcmd = {
    description =
[[A generic function which runs the `cmd` in the `dir`, first
setting up all of the environmental variables specified to
point to the `local` and `working` directories. This function is useful
when creating non-standard typesetting steps]],
    value = runcmd,
  },
  typeset = {
    description = "",
    value = typeset,
  },
  typeset_demo_tasks = {
    description = "runs after copying files to the typesetting location but before the main typesetting run.",
    value = typeset_demo_tasks,
  },
  docinit_hook = {
    description = "A hook to initialize doc process",
    value = docinit_hook,
  },
  checkinit_hook = {
    description = "A hook to initialize check process",
    value = checkinit_hook,
  },
  tag_hook = {
    description =
[[Usage: `function tag_hook(tag_name, date)
  ...
end`
  To allow more complex tasks to take place, a hook `tag_hook()` is also
available. It will receive the tag name and date as arguments, and
may be used to carry out arbitrary tasks after all files have been updated.
For example, this can be used to set a version control tag for an entire repository.
]],
    index = function (t, k)
      return require("l3build-tag").tag_hook
    end,
  },
  update_tag = {
    description =
[[Usage: function update_tag(file, content, tag_name, tag_date)
  ...
  return content
end
The `tag` target can automatically edit source files to
modify date and release tag name. As standard, no automatic
replacement takes place, but setting up a `update_tag` function
will allow this to happen.
]],
    index = function (t, k)
      return require("l3build-tag").update_tag
    end,
  },
  runtest_tasks = {
    description = "A hook to allow additional tasks to run for the tests",
    value = runtest_tasks,
  },
})

---Static global variables
---@type table
local G_values = setmetatable({}, {
  __index = function (t, k)
    ---@type variable_entry_t
    local entry = get_entry(k)
    if not entry then
      return
    end
    return entry.value
  end
})

---Computed global variables
---Used only when the eponym global variable is not set.
---@param t table
---@param k string
---@return any
local G_index = function (t, k)
  ---@type variable_entry_t
  local entry = get_entry(k)
  if entry then
    return entry.index and entry.index(t, k)
  end
  if k == "typeset_list" then
    error("Documentation is not installed")
  end
  if k == "texmf_home" then
    local result = l3build.options.texmfhome
    if not result then
      set_program("latex")
      result = var_value("TEXMFHOME")
    end
    return result
  end
  if k == "is_embedded" then
    return l3build.main_dir ~= l3build.work_dir
  end
  if k == "is_standalone" then
    return t.bundle == ""
  end
  if k == "at_top" then
    return l3build.main_dir == l3build.work_dir
  end
  if k == "at_bundle_top" then
    return t.at_top and not t.is_standalone
  end
  if k == "bundleunpack" then
    return require("l3build-unpack").bundleunpack
  end
  if k == "tds_main" then
    return t.is_standalone
      and t.tdsroot .."/".. t.module
      or  t.tdsroot .."/".. t.bundle
  end
  if k == "tds_module" then
    return t.is_standalone
      and t.module
      or  t.bundle .."/".. t.module
  end
end

G = bridge({
  index     = G_index,
  complete = function (t, k, result)
    local entry = get_entry(k)
    if entry then
      return entry.complete and entry.complete(t, k, result)
    end
    return result
  end,
  newindex = function (t, k, v)
    if k == "typeset_list" then
      rawset(t, k, v)
      return true
    end
    if k == "config_suffix" then
      --print(debug.traceback())
      rawset(t, k, v)
      return true
    end
  end,
})

Dir = bridge({
  suffix = "dir",
  complete = function (t, k, result) -- In progress
    -- No trailing /
    -- What about the leading "./"
    if k.match and k:match("dir$") then
      if not result then
        error("No result for key ".. k)
      end
      return quoted_path(result:match("^(.-)/*$")) -- any return result will be quoted_path
    end
    return result
  end,
})

-- Dir.work = work TODO: what is this ?

Files = bridge({
  suffix = "files",
  index = function (t, k)
    if k == "_all_typeset" then
      local result = {}
      for glob in entries(t.typeset) do
        append(result, glob)
      end
      for glob in entries(t.typesetdemo) do
        append(result, glob)
      end
      return result
    end
    if k == "_all_pdf" then
      local result = {}
      for glob in entries(t._all_typeset) do
        append(result, first_of(glob:gsub( "%.%w+$", ".pdf")))
      end
      return result
    end
  end
})

---Iterator over all the global variable names
---@return string_iterator_f
local function all_variable_names()
  return keys(DB, { compare = function (a, b)
  return a < b
  end })
end

---Get the description of the named global variable
---@param name string
---@return string
local function get_description(name)
  ---@type variable_entry_t
  local entry = get_entry(name)
  return entry and entry.description
    or ("No global variable named ".. name)
end

---Export globals in the metatable of the given table.
---At the end, `env` will know about any variable
---that was previously `declare`d.
---@param env? table defaults to `_G`
local function export(env)
  env = env or _G
  -- if there is already an __index function metamethod, we amend it
  -- if there is no such metamethod, we add a fresh one
  local MT = getmetatable(env) or {}
  local __index = MT.__index
  local f_index = type(__index) == "function" and __index
  local t_index = type(__index) == "table"    and __index
  function MT.__index(t, k)
    local result
    ---@type variable_entry_t
    local entry = get_entry(k)
    if entry then
      -- this is a global declared variable
      if entry.index then
        -- try first as computed property
        result = entry.index(t, k)
        if result ~= nil then
          return result
        end
      end
      -- fall back to the static value
      return entry.value
    end
    -- use the previous metamethod, if any
    if t_index then
      result = t_index[k]
    elseif f_index then
      result = f_index(t, k)
    end
    return result
  end
  return setmetatable(env, MT)
end

---@class l3b_globals_t
---@field LOCAL     any
---@field export    function
---@field all_variable_names        string_iterator_f
---@field get_descriptions          fun(name: string): string
---@field get_main_variable         fun(name: string, dir: string): string
---@field handle_get_main_variable  fun(name: string): error_level_n
---@field get_entry                 fun(name: string): variable_entry_t
---@field G         G_t
---@field Dir       Dir_t
---@field Files     Files_t
---@field Deps      Deps_t
---@field Exe       Exe_t
---@field Opts      Opts_t
---@field Xtn       Xtn_t

return {
  LOCAL                 = LOCAL,
  all_variable_names    = all_variable_names,
  get_description       = get_description,
  export                = export,
  get_main_variable     = get_main_variable,
  handle_get_main_variable = handle_get_main_variable,
  get_entry             = get_entry,
  G                     = G,
  Dir                   = Dir,
  Files                 = Files,
  Deps                  = Deps,
  Exe                   = Exe,
  Opts                  = Opts,
  Xtn                   = Xtn,
}
