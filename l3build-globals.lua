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

Each global variable is defined by a table (of type VariableEntry)
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

-- module was a known function in lua <= 5.3
-- but we need it as a "module" name
if type(_G.module) == "function" then
  _G.module = nil
end
-- the tex name is for the "tex" command
if type(_G.tex) == "table" then
  _G.tex = nil
end

local tostring  = tostring
local print     = print
local push      = table.insert
local exit      = os.exit
local os_time   = os.time
local os_type   = os["type"]

local status  = require("status")

local kpse        = require("kpse")
local set_program = kpse.set_program_name
local var_value   = kpse.var_value

---@type Object
local Object    = require("l3b-object")

---@type pathlib_t
local pathlib   = require("l3b-pathlib")
local dir_name  = pathlib.dir_name
local base_name = pathlib.base_name
local job_name  = pathlib.job_name

---@type corelib_t
local corelib           = require("l3b-corelib")
local bridge            = corelib.bridge

---@type utlib_t
local utlib             = require("l3b-utillib")
local is_error          = utlib.is_error
local entries           = utlib.entries
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
local push_pop_current_directory = fslib.push_pop_current_directory

---@type l3build_t
local l3build = require("l3build")

---@type l3b_aux_t
local l3b_aux       = require("l3build-aux")
local set_epoch_cmd = l3b_aux.set_epoch_cmd

local GET_MAIN_VARIABLE = corelib.GET_MAIN_VARIABLE

--[==[ Module implementation ]==]

---@alias biber_f     fun(name: string, dir: string): error_level_n
---@alias bibtex_f    fun(name: string, dir: string): error_level_n
---@alias makeindex_f fun(name: string, dir: string, in_ext: string, out_ext: string, log_ext: string, style: string): error_level_n
---@alias tex_f       fun(file: string, dir: string, cmd: string|nil): error_level_n
---@alias typeset_f   fun(file: string, dir: string, cmd: string|nil): error_level_n

---@class special_typesetting_t
---@field public func  typeset_f
---@field public cmd   string

---@class test_types_t
---@field public log table<string,string|function>
---@field public pdf table<string,string|function>

---@alias bundleunpack_f fun(source_dirs: string[], sources: string[]): error_level_n

---@class upload_config_t
---@field public announcement  string        @Announcement text
---@field public author        string        @Author name (semicolon-separated for multiple)
---@field public ctanPath      string        @CTAN path
---@field public email         string        @Email address of uploader
---@field public license       string|string[] @Package license(s) See https://ctan.org/license
---@field public pkg           string        @Name of the CTAN package (defaults to G.ctanpkg)
---@field public summary       string        @One-line summary
---@field public uploader      string        @Name of uploader
---@field public version       string        @Package version
---@field public bugtracker    string|string[] @URL(s) of bug tracker
---@field public description   string        @Short description/abstract
---@field public development   string|string[] @URL(s) of development channels
---@field public home          string|string[] @URL(s) of home page
---@field public note          string        @Internal note to CTAN
---@field public repository    string|string[] @URL(s) of source repositories
---@field public support       string|string[] @URL(s) of support channels
---@field public topic         string|string[] @Topic(s). See https://ctan.org/topics/highscore
---@field public update        string        @Boolean `true` for an update, `false` for a new package
---@field public announcement_file string    @Announcement text  file
---@field public note_file     string        @Note text file
---@field public curlopt_file  string        @The filename containing the options passed to curl

---@class _G_t
---@field public module        string @The name of the module
---@field public bundle        string @The name of the bundle in which the module belongs (where relevant)
---@field public ctanpkg       string @Name of the CTAN package matching this module
---@field public modules       string[] @The list of all modules in a bundle (when not auto-detecting)
---@field public exclmodules   string[] @Directories to be excluded from automatic module detection
---@field public tdsroot       string
---@field public ctanzip       string  @Name of the zip file (without extension) created for upload to CTAN
---@field public epoch         integer @Epoch (Unix date) to set for test runs
---@field public flattentds    boolean @Switch to flatten any source structure when creating a TDS structure
---@field public flattenscript boolean @Switch to flatten any script structure when creating a TDS structure
---@field public ctanreadme    string  @Name of the file to send to CTAN as `README.`md
---@field public ctanupload    boolean @Undocumented
---@field public tdslocations  string[] @For non-standard file installations
-- doc related
---@field public typesetsearch boolean @Switch to search the system `texmf` for during typesetting
---@field public glossarystyle string  @MakeIndex style file for glossary/changes creation
---@field public indexstyle    string  @MakeIndex style for index creation
---@field public specialtypesetting table<string,special_typesetting_t>  @Non-standard typesetting combinations
---@field public forcedocepoch string  @Force epoch when typesetting
---@field public typesetcmds   string  @Instructions to be passed to TeX when doing typesetting
---@field public typesetruns   integer @Number of cycles of typesetting to carry out
-- functions
---@field public runcmd        fun(cmd: string, dir: string, vars: table):boolean?, string?, integer?
---@field public biber         biber_f
---@field public bibtex        bibtex_f
---@field public makeindex     makeindex_f
---@field public tex           tex_f
---@field public typeset       typeset_f
---@field public typeset_demo_tasks  fun(): error_level_n
---@field public docinit_hook  fun(): error_level_n
-- check fields
---@field public checkengines    string[] @Engines to check with `check` by default
---@field public stdengine       string  @Engine to generate `.tlg` file from
---@field public checkformat     string  @Format to use for tests
---@field public specialformats  table  @Non-standard engine/format combinations
---@field public test_types      test_types_t  @Custom test variants
---@field public test_order      string[] @Which kinds of tests to evaluate
-- Configs for testing
---@field public checkconfigs    table   @Configurations to use for tests
---@field public includetests    string[] @Test names to include when checking
---@field public excludetests    string[] @Test names to exclude when checking
---@field public recordstatus    boolean @Switch to include error level from test runs in `.tlg` files
---@field public forcecheckepoch boolean @Force epoch when running tests
---@field public asciiengines    string[] @Engines which should log as pure ASCII
---@field public checkruns       integer @Number of runs to complete for a test before comparing the log
---@field public checksearch     boolean @Switch to search the system `texmf` for during checking
---@field public maxprintline    integer @Length of line to use in log files
---@field public runtest_tasks   fun(test_name: string, run_number: integer): string
---@field public checkinit_hook  fun(): error_level_n
---@field public ps2pdfopt       string  @Options for `ps2pdf`
---@field public unpacksearch    boolean  @Switch to search the system `texmf` for during unpacking
---@field public bundleunpack    bundleunpack_f  @bundle unpack overwrite
---@field public bundleunpackcmd string  @bundle unpack command overwrite
---@field public flatten         boolean @Switch to flatten any source structure when sending to CTAN
---@field public packtdszip      boolean @Switch to build a TDS-style zip file for CTAN
---@field public manifestfile    string @File name to use for the manifest file
---@field public curl_debug      boolean
---@field public uploadconfig    upload_config_t @Metadata to describe the package for CTAN
---@field public texmf_home      string
---@field public typeset_list    string[]
-- tag
---@field public tag_hook        tag_hook_f
---@field public update_tag      update_tag_f

---@class G_t: _G_t
-- unexposed computed properties
---@field public is_embedded   boolean @true means the module belongs to a bundle
---@field public is_standalone boolean @false means the module belongs to a bundle
---@field public at_top        boolean @true means there is no bundle above
---@field public at_bundle_top boolean @true means we are at the top of the bundle
---@field public config        string
---@field public tds_module    string
---@field public tds_main      string  @G.tdsroot / G.bundle or G.module

---@type G_t
local G

---@class Dir_t
---@field public work        string @Directory with the `build.lua` file.
---@field public main        string @Top level directory for the module|bundle
---@field public docfile     string @Directory containing documentation files
---@field public sourcefile  string @Directory containing source files
---@field public support     string @Directory containing general support files
---@field public testfile    string @Directory containing test files
---@field public testsupp    string @Directory containing test-specific support files
---@field public texmf       string @Directory containing support files in tree form
---@field public textfile    string @Directory containing plain text files
---@field public build       string @Directory for building and testing
---@field public distrib     string @Directory for generating distribution structure
---@field public local       string @Directory for extracted files in sandboxed TeX runs
---@field public result      string @Directory for PDF files when using PDF-based tests
---@field public test        string @Directory for running tests
---@field public typeset     string @Directory for building documentation
---@field public unpack      string @Directory for unpacking sources
---@field public ctan        string @Directory for organising files for CTAN
---@field public tds         string @Directory for organised files into TDS structure

---@type Dir_t
local Dir

-- File types for various operations
-- Use Unix-style globs
-- All of these may be set earlier, so a initialised conditionally

---@class Files_t
---@field public aux           string[] @Secondary files to be saved as part of running tests
---@field public bib           string[] @BibTeX database files
---@field public binary        string[] @Files to be added in binary mode to zip files
---@field public bst           string[] @BibTeX style files
---@field public check         string[] @Extra files unpacked purely for tests
---@field public checksupp     string[] @Files needed for performing regression tests
---@field public clean         string[] @Files to delete when cleaning
---@field public demo          string[] @Files which show how to use a module
---@field public doc           string[] @Files which are part of the documentation but should not be typeset
---@field public dynamic       string[] @Secondary files to cleared before each test is run
---@field public exclude       string[] @Files to ignore entirely (default for Emacs backup files)
---@field public install       string[] @Files to install to the `tex` area of the `texmf` tree
---@field public makeindex     string[] @MakeIndex files to be included in a TDS-style zip
---@field public script        string[] @Files to install to the `scripts` area of the `texmf` tree
---@field public scriptman     string[] @Files to install to the `doc/man` area of the `texmf` tree
---@field public source        string[] @Files to copy for unpacking
---@field public tag           string[] @Files for automatic tagging
---@field public text          string[] @Plain text files to send to CTAN as-is
---@field public typesetdemo   string[] @Files to typeset before the documentation for inclusion in main documentation files
---@field public typeset       string[] @Files to typeset for documentation
---@field public typesetsupp   string[] @Files needed to support typesetting when 'sandboxed'
---@field public typesetsource string[] @Files to copy to unpacking when typesetting
---@field public unpack        string[] @Files to run to perform unpacking
---@field public unpacksupp    string[] @Files needed to support unpacking when 'sandboxed'
---@field public _all_typeset  string[] @To combine `typeset` files and `typesetdemo` files
---@field public _all_pdf      string[] @Counterpart of "_all_typeset"

---@type Files_t
local Files

---@class Deps_t
---@field public check   string[] @-- List of dependencies for running checks
---@field public typeset string[] @-- List of dependencies for typesetting docs
---@field public unpack  string[] @-- List of dependencies for unpacking

---@type Deps_t
local Deps

-- Executable names plus following options

---@class Exe_t
---@field public typeset   string @Executable for compiling `doc(s)`
---@field public unpack    string @Executable for running `unpack`
---@field public zip       string @Executable for creating archive with `ctan`
---@field public biber     string @Biber executable
---@field public bibtex    string @BibTeX executable
---@field public makeindex string @MakeIndex executable
---@field public curl      string @Curl executable for `upload`

---@type Exe_t
local Exe

---@class Opts_t
---@field public check     string @Options passed to engine when running checks
---@field public typeset   string @Options passed to engine when typesetting
---@field public unpack    string @Options passed to engine when unpacking
---@field public zip       string @Options passed to zip program
---@field public biber     string @Biber options
---@field public bibtex    string @BibTeX options
---@field public makeindex string @MakeIndex options

---@type Opts_t
local Opts

-- Extensions for various file types: used to abstract out stuff a bit

---@class Xtn_t
---@field public bak string  @Extension of backup files
---@field public dvi string  @Extension of DVI files
---@field public lvt string  @Extension of log-based test files
---@field public tlg string  @Extension of test file output
---@field public tpf string  @Extension of PDF-based test output
---@field public lve string  @Extension of auto-generating test file output
---@field public log string  @Extension of checking output, before processing it into a `.tlg`
---@field public pvt string  @Extension of PDF-based test files
---@field public pdf string  @Extension of PDF file for checking and saving
---@field public ps  string  @Extension of PostScript files

---@type Xtn_t
local Xtn

--[==[ Main variable query business
Allows a module to get the value of a global variable
of its owning main bundle. Can catch values defined in `build.lua`
but not in configuration files.
Used for "l3build --get-global-variable bundle"
and      "l3build --get-global-variable maindir"
]==]

---Get the main variable with the given name,
---@param name string
---@return string|nil
local function get_main_variable(name)
  local command = to_quoted_string({
    "texlua",
    quoted_path(l3build.script_path),
    "status",
    "--".. GET_MAIN_VARIABLE,
    name,
  })
  local ok, packed = push_pop_current_directory(
    l3build.main_dir,
    function (cmd)
      local result = read_command(cmd)
      return result
    end,
    command
  )
  if ok then
    local k, v = packed[1]:match("GLOBAL VARIABLE: name = (.-), value = (.*)")
    return name == k and v or nil
  else
    error(packed)
  end
end

---Print the correct message such that one can parse it
---and retrieve the value. Os agnostic method.
---@param name    string
---@param config  string[]
---@return error_level_n
local function handle_get_main_variable(name, config)
  name = name or "MISSING VARIABLE NAME"
  local f, msg = loadfile(l3build.work_dir / "build.lua")
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

---@class pre_variable_entry_t
---@field public description string
---@field public value       any
---@field public index       fun(self: VariableEntry, env: table, k: string): any @ takes precedence over the value
---@field public complete    fun(self: VariableEntry, env: table, k: string, v: any): any

---@class VariableEntry: pre_variable_entry_t
---@field public name           string
---@field public level          integer
---@field public type           string
---@field public vanilla_value  any

local VariableEntry = Object:make_subclass("VariableEntry")

function VariableEntry:__initialize(name)
  self.name = name
end

---@type table<string,VariableEntry>
local entry_by_name = {}
---@type VariableEntry[]
local entry_by_index = {}

---Declare the given variable
---@param by_name table<string,pre_variable_entry_t>
local function declare(by_name)
  for name, entry in pairs(by_name) do
    assert(not entry_by_name[name], "Duplicate declaration ".. tostring(name))
    entry = VariableEntry(entry, name)
    entry_by_name[name] = entry
    push(entry_by_index, entry)
  end
end

---Get the variable entry for the given name.
---@param name string
---@return VariableEntry
local function get_entry(name)
  return entry_by_name[name]
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
---@param env table
---@usage after the `build.lua` has been executed.
local function guess_bundle_module(env)
  -- bundle and module values are very important
  -- because they control the behaviour of somme actions
  -- they also control where things are stored.
  -- Find bundle and module names defined by the client
  local bundle = rawget(_G, "bundle") -- do not fall back
  local module = rawget(_G, "module") -- to the metatable
  -- We act as if bundle and module were not already provided.
  -- This allows to make tests and eventually inform the user
  -- of a non standard shape, in case she has made a mistake.
  if env.is_embedded then
    -- A module inside a bundle: the current directory is
    -- .../<bundle>/<module>/...
    -- The bundle name must be provided, but can be a void string
    -- When missing, it is read from the the parent's `build.lua`
    -- We cannot execute the parent's script because
    -- this script may perform actions and change files (see latex2e)
    -- So we parse the content finger crossed.
    local s = get_main_variable("bundle")
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
    s = base_name(dir_name(Dir.work)):lower()
    if not module then
      module = s
    elseif module ~= s then
      print(("Warning, module names are not consistent: %s and %s")
            :format(module, s))
    end
  else -- not an embeded module
    local modules = env.modules
    if #modules > 0 then
      -- this is a top bundle,
      -- the bundle name must be provided
      -- the module name does not make sense
      if not bundle or bundle == "" then
        bundle = get_main_variable("bundle")
        if not bundle then -- bundle name is required in bundle/module shape
          error('Missing in top `build.lua`: bundle = "<bundle name>"')
        end
      end
      if module and module ~= "" then
        print("Warning, module name ignored (in bundle): ".. module)
      end
      module = "" -- not nil!
    elseif bundle and bundle ~= "" then
      -- this is a bundle with no modules,
      -- like latex2e
      if module and module ~= "" then
        print("Warning, module name ignored: ".. module)
      end
      module = "" -- not nil!
    else
      bundle = ""
      if not module or module == "" then
        -- this is a standalone module (not in a bundle),
        -- the module name must be provided explicitly
        -- the bundle name does not make sense
        -- and we cannot guess the module name from
        -- any path
        error('Missing in top build.lua: module = "<module name>"')
      end
    end
  end
  -- MISSING naming constraints
  rawset(env, "bundle", bundle)
  rawset(env, "module", module)
end

declare({
  modules = {
    description = "The list of all modules in a bundle (when not auto-detecting)",
    index = function (env, k)
      local result = {}
      local excl_modules = env.exclmodules
      for name in all_names(Dir.work) do
        if directory_exists(name) and not excl_modules[name] then
          if file_exists(name / "build.lua") then
            push(result, name)
          end
        end
      end
      rawset(env, k, result)
      return result
    end,
  },
  exclmodules = {
    description = "Directories to be excluded from automatic module detection",
    value       = {},
  },
  options = {
    index = function (env, k)
      return l3build.options
    end,
  },
  module = {
    description = "The name of the module",
    index = function (env, k)
      guess_bundle_module(env)
      return rawget(env, k)
    end,
  },
  bundle = {
    description = "The name of the bundle in which the module belongs (where relevant)",
    index = function (env, k)
      guess_bundle_module(env)
      return rawget(env, k)
    end,
  },
  ctanpkg = {
    description = "Name of the CTAN package matching this module",
    index = function (env, k)
      return  env.is_standalone
          and env.module
          or (env.bundle / env.module)
    end,
  },
})
-- directory structure
declare({
  maindir = {
    description = "Top level directory for the module/bundle",
    index = function (env, k)
      if env.is_embedded then
        -- retrieve the maindir from the main build.lua
        local s = get_main_variable(k)
        if s then
          return s / "."
        end
      end
      return l3build.main_dir / "."
    end,
  },
  supportdir = {
    description = "Directory containing general support files",
    index = function (env, k)
      return env.maindir / "support"
    end,
  },
  texmfdir = {
    description = "Directory containing support files in tree form",
    index = function (env, k)
      return env.maindir / "texmf"
    end
  },
  builddir = {
    description = "Directory for building and testing",
    index = function (env, k)
      return env.maindir / "build"
    end
  },
  docfiledir = {
    description = "Directory containing documentation files",
    value       = dot_dir,
  },
  sourcefiledir = {
    description = "Directory containing source files",
    value       = dot_dir,
  },
  testfiledir = {
    description = "Directory containing test files",
    index = function (env, k)
      return dot_dir / "testfiles"
    end,
  },
  testsuppdir = {
    description = "Directory containing test-specific support files",
    index = function (env, k)
      return env.testfiledir / "support"
    end
  },
  -- Structure within a development area
  textfiledir = {
    description = "Directory containing plain text files",
    value       = dot_dir,
  },
  distribdir = {
    description = "Directory for generating distribution structure",
    index = function (env, k)
      return env.builddir / "distrib"
    end
  },
  -- Substructure for CTAN release material
  localdir = {
    description = "Directory for extracted files in 'sandboxed' TeX runs",
    index = function (env, k)
      return env.builddir / "local"
    end
  },
  resultdir = {
    description = "Directory for PDF files when using PDF-based tests",
    index = function (env, k)
      return env.builddir / "result"
    end
  },
  testdir = {
    description = "Directory for running tests",
    index = function (env, k)
      return env.builddir / "test" .. env.config_suffix
    end
  },
  typesetdir = {
    description = "Directory for building documentation",
    index = function (env, k)
      return env.builddir / "doc"
    end
  },
  unpackdir = {
    description = "Directory for unpacking sources",
    index = function (env, k)
      return env.builddir / "unpacked"
    end
  },
  ctandir = {
    description = "Directory for organising files for CTAN",
    index = function (env, k)
      return env.distribdir / "ctan"
    end
  },
  tdsdir = {
    description = "Directory for organised files into TDS structure",
    index = function (env, k)
      return env.distribdir / "tds"
    end
  },
  workdir = {
    description = "Working directory",
    index = function (env, k)
      return l3build.work_dir:sub(1, -2) -- no trailing "/"
    end
  },
  config_suffix = {
    -- overwritten after load_unique_config call
    index = function (env, k)
      return ""
    end,
  },
})
declare({
  tdsroot = {
    description = "Root directory of the TDS structure for the bundle/module to be installed into",
    value       = "latex",
  },
  ctanupload = {
    description = "Only validation is attempted",
    value       = false,
  },
})
-- file globs
declare({
  auxfiles = {
    description = "Secondary files to be saved as part of running tests",
    value       = { "*.aux", "*.lof", "*.lot", "*.toc" },
  },
  bibfiles = {
    description = "BibTeX database files",
    value       = { "*.bib" },
  },
  binaryfiles = {
    description = "Files to be added in binary mode to zip files",
    value       = { "*.pdf", "*.zip" },
  },
  bstfiles = {
    description = "BibTeX style files to install",
    value       = { "*.bst" },
  },
  checkfiles = {
    description = "Extra files unpacked purely for tests",
    value       = {},
  },
  checksuppfiles = {
    description = "Files in the support directory needed for regression tests",
    value       = {},
  },
  cleanfiles = {
    description = "Files to delete when cleaning",
    value       = { "*.log", "*.pdf", "*.zip" },
  },
  demofiles = {
    description = "Demonstration files to use a module",
    value       = {},
  },
  docfiles = {
    description = "Files which are part of the documentation but should not be typeset",
    value       = {},
  },
  dynamicfiles = {
    description = "Secondary files to be cleared before each test is run",
    value       = {},
  },
  excludefiles = {
    description = "Files to ignore entirely (default for Emacs backup files)",
    value       = { "*~" },
  },
  installfiles = {
    description = "Files to install under the `tex` area of the `texmf` tree",
    value       = { "*.sty", "*.cls" },
  },
  makeindexfiles = {
    description = "MakeIndex files to be included in a TDS-style zip",
    value       = { "*.ist" },
  },
  scriptfiles = {
    description = "Files to install to the `scripts` area of the `texmf` tree",
    value       = {},
  },
  scriptmanfiles = {
    description = "Files to install to the `doc/man` area of the `texmf` tree",
    value       = {},
  },
  sourcefiles = {
    description = "Files to copy for unpacking",
    value       = { "*.dtx", "*.ins", "*-????-??-??.sty" },
  },
  tagfiles = {
    description = "Files for automatic tagging",
    value       = { "*.dtx" },
  },
  textfiles = {
    description = "Plain text files to send to CTAN as-is",
    value       = { "*.md", "*.txt" },
  },
  typesetdemofiles = {
    description = "Files to typeset before the documentation for inclusion in main documentation files",
    value       = {},
  },
  typesetfiles = {
    description = "Files to typeset for documentation",
    value       = { "*.dtx" },
  },
  typesetsuppfiles = {
    description = "Files needed to support typesetting when sandboxed",
    value       = {},
  },
  typesetsourcefiles = {
    description = "Files to copy to unpacking when typesetting",
    value       = {},
  },
  unpackfiles = {
    description = "Files to run to perform unpacking",
    value       = { "*.ins" },
  },
  unpacksuppfiles = {
    description = "Files needed to support unpacking when 'sandboxed'",
    value       = {},
  },
})
-- check
declare({
  includetests = {
    description = "Test names to include when checking",
    value       = { "*" },
  },
  excludetests = {
    description = "Test names to exclude when checking",
    value       = {},
  },
  checkdeps = {
    description = "List of dependencies for running checks",
    value       = {},
  },
  typesetdeps = {
    description = "List of dependencies for typesetting docs",
    value       = {},
  },
  unpackdeps = {
    description = "List of dependencies for unpacking",
    value       = {},
  },
  checkengines = {
    description = "Engines to check with `check` by default",
    value       = { "pdftex", "xetex", "luatex" },
    complete = function (env, k, result)
      local options = l3build.options
      if options.engine then
        if not options.force then
          ---@type flags_t
          local tt = {}
          for engine in entries(result) do
            tt[engine] = true
          end
          for opt_engine in entries(options.engine) do
            if not tt[opt_engine] then
              print("\n! Error: Engine \"" .. opt_engine .. "\" not set up for testing!")
              print("\n  Valid values are:")
              for engine in entries(result) do
                print("  - " .. engine)
              end
              print("")
              exit(1)
            end
          end
        end
        result = options.engine
      end
      rawset(env, k, result) -- cached here
      return result
    end,
  },
  stdengine = {
    description = "Engine to generate `.tlg` files",
    value       = "pdftex",
  },
  checkformat = {
    description = "Format to use for tests",
    value       = "latex",
  },
  specialformats = {
    description = "Non-standard engine/format combinations",
    value       = specialformats,
  },
  test_types = {
    description = "Custom test variants",
    index = function (env, k)
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
    value       = { "log", "pdf" },
  },
  checkconfigs = {
    description = "Configurations to use for tests",
    value       = {  "build"  },
    complete = function (env, k, result)
      local options = l3build.options
      -- When we have specific files to deal with, only use explicit configs
      -- (or just the std one)
      -- TODO: Justify this...
      if options.names then
        return options.config or { _G["stdconfig"] }
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
    value       = "pdflatex",
  },
  unpackexe = {
    description = "Executable for running `unpack`",
    value       = "pdftex",
  },
  zipexe = {
    description = "Executable for creating archive with `ctan`",
    value       = "zip",
  },
  biberexe = {
    description = "Biber executable",
    value       = "biber",
  },
  bibtexexe = {
    description = "BibTeX executable",
    value       = "bibtex8",
  },
  makeindexexe = {
    description = "MakeIndex executable",
    value       = "makeindex",
  },
  curlexe = {
    description = "Curl executable for `upload`",
    value       = "curl",
  },
})
-- CLI Options
declare({
  checkopts = {
    description = "Options passed to engine when running checks",
    value       = "-interaction=nonstopmode",
  },
  typesetopts = {
    description = "Options passed to engine when typesetting",
    value       = "-interaction=nonstopmode",
  },
  unpackopts = {
    description = "Options passed to engine when unpacking",
    value       = "",
  },
  zipopts = {
    description = "Options passed to zip program",
    value       = "-v -r -X",
  },
  biberopts = {
    description = "Biber options",
    value       = "",
  },
  bibtexopts = {
    description = "BibTeX options",
    value       = "-W",
  },
  makeindexopts = {
    description = "MakeIndex options",
    value       = "",
  },
  ps2pdfopt = { -- beware of the ending s (long term error)
    description = "ps2pdf options",
    value       = "",
  },
})

declare({
  config = {
    value       = "",
  },
  curl_debug  = {
    value       = false,
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
    value       = true,
  },
  unpacksearch = {
    description = "Switch to search the system `texmf` for during unpacking",
    value       = true,
  },
  checksearch = {
    description = "Switch to search the system `texmf` for during checking",
    value       = true,
  },
  -- Additional settings to fine-tune typesetting
  glossarystyle = {
    description = "MakeIndex style file for glossary/changes creation",
    value       = "gglo.ist",
  },
  indexstyle = {
    description = "MakeIndex style for index creation",
    value       = "gind.ist",
  },
  specialtypesetting = {
    description = "Non-standard typesetting combinations",
    value       = {},
  },
  forcecheckepoch = {
    description = "Force epoch when running tests",
    value       = true,
    complete = function (env, k, result)
      local options = l3build.options
      if options.epoch then
        return true
      end
      return result
    end
  },
  forcedocepoch = {
    description = "Force epoch when typesetting",
    value       = "false",
    complete = function (env, k, result)
      local options = l3build.options
      return (options.epoch or result) and true or false
    end,
  },
  asciiengines = {
    description = "Engines which should log as pure ASCII",
    value       = { "pdftex" },
  },
  checkruns = {
    description = "Number of runs to complete for a test before comparing the log",
    value       = 1,
  },
  ctanreadme = {
    description = "Name of the file to send to CTAN as `README`.md",
    value       = "README.md",
  },
  ctanzip = {
    description = "Name of the zip file (without extension) created for upload to CTAN",
    index = function (env, k)
      return env.ctanpkg .. "-ctan"
    end,
  },
  epoch = {
    description = "Epoch (Unix date) to set for test runs",
    index = function (env, k)
      local options = l3build.options
      return options.epoch or rawget(_G, "epoch") or 1463734800
    end,
    complete = function (env, k, result)
      return normalise_epoch(result)
    end,
  },
  flatten = {
    description = "Switch to flatten any source structure when sending to CTAN",
    value       = true,
  },
  flattentds = {
    description = "Switch to flatten any source structure when creating a TDS structure",
    value       = true,
  },
  flattenscript = {
    description = "Switch to flatten any script structure when creating a TDS structure",
    index = function (env, k)
      return G.flattentds -- by defaut flattentds and flattenscript are synonyms
    end,
  },
  maxprintline = {
    description = "Length of line to use in log files",
    value       = 79,
  },
  packtdszip = {
    description = "Switch to build a TDS-style zip file for CTAN",
    value       = false,
  },
  ps2pdfopts = {
    description = "Options for `ps2pdf`",
    value       = "",
  },
  typesetcmds = {
    description = "Instructions to be passed to TeX when doing typesetting",
    value       = "",
  },
  typesetruns = {
    description = "Number of cycles of typesetting to carry out",
    value       = 3,
  },
  recordstatus = {
    description = "Switch to include error level from test runs in `.tlg` files",
    value       = false,
  },
  manifestfile = {
    description = "File name to use for the manifest file",
    value       = "MANIFEST.md",
  },
  tdslocations = {
    description = "For non-standard file installations",
    value       = {},
  },
  uploadconfig = {
    value       = {},
    description = "Metadata to describe the package for CTAN",
    index =  function (env, k)
      return setmetatable({}, {
        __index = function (tt, kk)
          if kk == "pkg" then
            return env.ctanpkg
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
    value       = ".bak",
  },
  dviext = {
    description = "Extension of DVI files",
    value       = ".dvi",
  },
  lvtext = {
    description = "Extension of log-based test files",
    value       = ".lvt",
  },
  tlgext = {
    description = "Extension of test file output",
    value       = ".tlg",
  },
  tpfext = {
    description = "Extension of PDF-based test output",
    value       = ".tpf",
  },
  lveext = {
    description = "Extension of auto-generating test file output",
    value       = ".lve",
  },
  logext = {
    description = "Extension of checking output, before processing it into a `.tlg`",
    value       = ".log",
  },
  pvtext = {
    description = "Extension of PDF-based test files",
    value       = ".pvt",
  },
  pdfext = {
    description = "Extension of PDF file for checking and saving",
    value       = ".pdf",
  },
  psext = {
    description = "Extension of PostScript files",
    value       = ".ps",
  }
})

declare({
  abspath = {
    description = [[
Usage: `abspath("foo.bar")`
Returns "/absolute/path/to/foo.bar" on unix like systems
and "C:\absolute\path\to\foo.bar" on windows.
]],
    value       = fslib.absolute_path,
  },
  dirname = {
    description = [[
Usage: `dirname("path/to/foo.bar")`
Returns "path/to".
]],
    value       = pathlib.dir_name,
  },
  basename = {
    description = [[
Usage: `basename("path/to/foo.bar")`
Returns "foo.bar".
]],
    value       = pathlib.base_name,
  },
  cleandir = {
    description = [[
Usage: `cleandir("path/to/dir")`
Removes any content in "path/to/dir" directory.
Returns 0 on success, a positive number on error.
]],
    value       = fslib.make_clean_directory,
  },
  cp = {
    description = [[
Usage: `cp("*.bar", "path/to/source", "path/to/destination")`
Copies files matching the "*.bar" from "path/to/source" directory
to the "path/to/destination" directory.
Returns 0 on success, a positive number on error.
]],
    value       = fslib.copy_tree,
  },
  direxists = {
    description = [[
`direxists("path/to/dir")`
Returns `true` if there is a directory at "path/to/dir",
`false` otherwise.
]],
    value       = fslib.directory_exists,
  },
  fileexists = {
    description = [[
`fileexists("path/to/foo.bar")`
Returns `true` if there is a file at "path/to/foo.bar",
`false` otherwise.
]],
    value       = fslib.file_exists,
  },
  filelist = {
    description = [[
`filelist("path/to/dir", "*.bar")
Returns a regular table of all the files within "path/to/dir"
which name matches "*.bar";
if no glob is provided, returns a list of
all files at "path/to/dir".
]],
    value       = fslib.file_list,
  },
  glob_to_pattern = {
    description = [[
`glob_to_pattern("*.bar")`
Returns Lua pattern that corresponds to the glob "*.bar".
]],
    value       = pathlib.glob_to_pattern,
  },
  path_matcher = {
    description = [[
`f = path_matcher("*.bar")`
Returns a function that returns true if its file name argument
matches "*.bar", false otherwise. Lua pattern that corresponds to the glob "*.bar".
In that example `f("foo.bar")` is true whereas `f("foo.baz")` is false.
]],
    value       = pathlib.path_matcher,
  },
  jobname = {
    description = [[
`jobname("path/to/dir/foo.bar")`
Returns the argument with no extension and no parent directory path,
"foo" in the example. 
]],
    value       = pathlib.job_name,
  },
  mkdir = {
    description = [[
`mkdir("path/to/dir")`
Create "path/to/dir" with all intermediate levels;
returns 0 on success, a positive number on error.
]],
    value       = fslib.make_directory,
  },
  ren = {
    description = [[
`ren("foo.bar", "path/to/source", "path/to/destination")`
Renames "path/to/source/foo.bar" into "path/to/destination/foo.bar";
returns 0 on success, a positive number on error.
]],
    value       = fslib.rename,
  },
  rm = {
    description = [[
`rm("path/to/dir", "*.bar")
Removes all files in "path/to/dir" matching "*.bar";
returns 0 on success, a positive number on error.
]],
    value       = fslib.remove_tree,
  },
  run = {
    description = [[
`run(cmd, dir)`.
Executes `cmd`, from the `dir` directory;
returns an error level.
]],
    value       = oslib.run,
  },
  splitpath = {
    description = [[
Returns two strings split at the last `/`: the `dirname(...)` and
the `basename(...)`.
]],
    value       = pathlib.dir_base,
  },
  normalize_path = {
    description = [[
When called on Windows, returns a string comprising the `path` argument with
`/` characters replaced by `\\`. In other cases returns the path unchanged.
]],
    value       = fslib.to_host,
  },
  call = {
    description = [[
`call(modules, target, options)`.
Runs the  `l3build` given `target` (a string) for each directory in the
`dirs` list. This will pass command line options from the parent
script to the child processes. The `options` table should take the
same form as the global `options`, described above. If it is
absent then the global list is used.
Note that the `target` field in this table is ignored.
]],
    value       = l3b_aux.call,
  },
  install_files = {
    description = "",
    value       = NYI, -- l3b_inst.install_files,
  },
  manifest_setup = {
    description = "",
    value       = NYI,
  },
  manifest_extract_filedesc = {
    description = "",
    value       = NYI,
  },
  manifest_write_subheading = {
    description = "",
    value       = NYI,
  },
  manifest_sort_within_match = {
    description = "",
    value       = NYI,
  },
  manifest_sort_within_group = {
    description = "",
    value       = NYI,
  },
  manifest_write_opening = {
    description = "",
    value       = NYI,
  },
  manifest_write_group_heading = {
    description = "",
    value       = NYI,
  },
  manifest_write_group_file_descr = {
    description = "",
    value       = NYI,
  },
  manifest_write_group_file = {
    description = "",
    value       = NYI,
  },
})

declare({
  os_concat = {
    description = "The concatenation operation for using multiple commands in one system call",
    value       = OS.concat,
  },
  os_null = {
    description = "The location to redirect commands which should produce no output at the terminal: almost always used preceded by `>`",
    value       = OS.null,
  },
  os_pathsep = {
    description = "The separator used when setting an environment variable to multiple paths.",
    value       = OS.pathsep,
  },
  os_setenv = {
    description = "The command to set an environmental variable.",
    value       = OS.setenv,
  },
  os_yes = {
    description = "DEPRECATED.",
    value       = OS.yes,
  },
  os_ascii = {
    -- description = "",
    value       = OS.ascii,
  },
  os_cmpexe = {
    -- description = "",
    value       = OS.cmpexe,
  },
  os_cmpext = {
    -- description = "",
    value       = OS.cmpext,
  },
  os_diffexe = {
    -- description = "",
    value       = OS.diffexe,
  },
  os_diffext = {
    -- description = "",
    value       = OS.diffext,
  },
  os_grepexe = {
    -- description = "",
    value       = OS.grepexe,
  },
})
-- global fields
declare({
  ["uploadconfig.announcement"] = {
    description = "Announcement text",
  },
  ["uploadconfig.author"] = {
    description = "Author name (semicolon-separated for multiple)",
  },
  ["uploadconfig.ctanPath"] = {
    description = "CTAN path",
  },
  ["uploadconfig.email"] = {
    description = "Email address of uploader",
  },
  ["uploadconfig.license"] = {
    description = "Package license(s). See https://ctan.org/license",
  },
  ["uploadconfig.pkg"] = {
    description = "Name of the CTAN package (defaults to G.ctanpkg)",
  },
  ["uploadconfig.summary"] = {
    description = "One-line summary",
  },
  ["uploadconfig.uploader"] = {
    description = "Name of uploader",
  },
  ["uploadconfig.version"] = {
    description = "Package version",
  },
  ["uploadconfig.bugtracker"] = {
    description = "URL(s) of bug tracker",
  },
  ["uploadconfig.description"] = {
    description = "Short description/abstract",
  },
  ["uploadconfig.development"] = {
    description = "URL(s) of development channels",
  },
  ["uploadconfig.home"] = {
    description = "URL(s) of home page",
  },
  ["uploadconfig.note"] = {
    description = "Internal note to CTAN",
  },
  ["uploadconfig.repository"] = {
    description = "URL(s) of source repositories",
  },
  ["uploadconfig.support"] = {
    description = "URL(s) of support channels",
  },
  ["uploadconfig.topic"] = {
    description = "Topic(s), see https://ctan.org/topics/highscore",
  },
  ["uploadconfig.update"] = {
    description = "Boolean `true` for an update, `false` for a new package",
  },
  ["uploadconfig.announcement_file"] = {
    description = "Announcement text file",
  },
  ["uploadconfig.note_file"] = {
    description = "Note text file",
  },
  ["uploadconfig.curlopt_file"] = {
    description = "The filename containing the options passed to curl",
  },
})

local LOCAL = "local"

-- An auxiliary used to set up the environmental variables
---comment
---@param cmd   string
---@param dir?  string
---@param vars? string[]
---@return boolean?  @suc
---@return exitcode? @exitcode
---@return integer?  @code
local function runcmd(cmd, dir, vars)
  dir = quoted_absolute_path(dir or ".")
  vars = vars or {}
  local local_texmf = ""
  if Dir.texmf and Dir.texmf ~= "" and directory_exists(Dir.texmf) then
    local_texmf = OS.pathsep .. quoted_absolute_path(Dir.texmf) .. "//"
  end
  local env_paths = "."
    .. local_texmf .. OS.pathsep
    .. quoted_absolute_path(Dir[LOCAL]) .. OS.pathsep
    .. dir .. (G.typesetsearch and OS.pathsep or "")
  -- Deal with spaces in paths
  if os_type == "windows" and env_paths:match(" ") then
    env_paths = first_of(env_paths:gsub('"', '')) -- no '"' in windows!!!
  end
  -- Allow for local texmf files
  local setenv_cmd = OS.setenv .. " TEXMFCNF=." .. OS.pathsep
  for var in entries(vars) do
    setenv_cmd = cmd_concat(setenv_cmd, OS.setenv .. " " .. var .. "=" .. env_paths)
  end
  print("set_epoch_cmd(G.epoch, G.forcedocepoch)", set_epoch_cmd(G.epoch, G.forcedocepoch))
  print(setenv_cmd)
  print(cmd)
  return run(dir, cmd_concat(set_epoch_cmd(G.epoch, G.forcedocepoch), setenv_cmd, cmd))
end

---biber
---@param name string
---@param dir string
---@return error_level_n
local function biber(name, dir)
  if file_exists(dir / name .. ".bcf") then
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
  if file_exists(dir / name .. ".aux") then
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
  if file_exists(dir / name .. in_ext) then
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
  if is_error(error_level) then
    return error_level
  end
  local name = job_name(file)
  error_level = G.biber(name, dir) + G.bibtex(name, dir)
  if is_error(error_level) then
    return error_level
  end
  for i = 2, G.typesetruns do
    error_level = G.makeindex(name, dir, ".glo", ".gls", ".glg", G.glossarystyle)
                + G.makeindex(name, dir, ".idx", ".ind", ".ilg", G.indexstyle)
                + G.tex(file, dir, cmd)
    if is_error(error_level) then break end
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
    description = [[
Runs Biber on file `name` (i.e a jobname lacking any extension)
inside the dir` folder. If there is no `.bcf` file then
no action is taken with a return value of `0`.
]],
    value       = biber,
  },
  bibtex = {
    description = [[
Runs BibTeX on file `name` (i.e a jobname lacking any extension)
inside the `dir` folder. If there are no `\citation` lines in
the `.aux` file then no action is taken with a return value of `0`.
]],
    value       = bibtex,
  },
  tex = {
    description = [[
Runs `cmd` (by default `typesetexe` `typesetopts`) on the
`name` inside the `dir` folder.
]],
    value       = tex,
  },
  makeindex = {
    description = [[
Runs MakeIndex on file `name` (i.e a jobname lacking any extension)
inside the `dir` folder. The various extensions and the `style`
should normally be given as standard for MakeIndex.
]],
    value       = makeindex,
  },
  runcmd = {
    description = [[
A generic function which runs the `cmd` in the `dir`, first
setting up all of the environmental variables specified to
point to the `local` and `working` directories. This function is useful
when creating non-standard typesetting steps.
]],
    value       = runcmd,
  },
  typeset = {
    description = "",
    value       = typeset,
  },
  typeset_demo_tasks = {
    description = "runs after copying files to the typesetting location but before the main typesetting run.",
    value       = typeset_demo_tasks,
  },
  docinit_hook = {
    description = "A hook to initialize doc process",
    value       = docinit_hook,
  },
  checkinit_hook = {
    description = "A hook to initialize check process",
    value       = checkinit_hook,
  },
  tag_hook = {
    description = [[
Usage: `function tag_hook(tag_name, date)
  ...
end`
  To allow more complex tasks to take place, a hook `tag_hook()` is also
available. It will receive the tag name and date as arguments, and
may be used to carry out arbitrary tasks after all files have been updated.
For example, this can be used to set a version control tag for an entire repository.
]],
    index = function (env, k)
      return require("l3build-tag").tag_hook
    end,
  },
  update_tag = {
    description = [[
Usage: function update_tag(file, content, tag_name, tag_date)
  ...
  return content
end
The `tag` target can automatically edit source files to
modify date and release tag name. As standard, no automatic
replacement takes place, but setting up a `update_tag` function
will allow this to happen.
]],
    index = function (env, k)
      return require("l3build-tag").update_tag
    end,
  },
  runtest_tasks = {
    description = "A hook to allow additional tasks to run for the tests",
    value       = runtest_tasks,
  },
})

---Computed global variables
---Used only when the eponym global variable is not set.
---@param env table
---@param k   string
---@return any
local G_index = function (env, k)
  ---@type VariableEntry
  local entry = get_entry(k)
  if entry then
    local result
    if entry.index then
      result = entry.index(env, k)
      if result ~= nil then
        return result
      end
    end
    result = entry.value
    if result ~= nil then
      return result
    end
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
    return env.bundle == ""
  end
  if k == "at_top" then
    return l3build.main_dir == l3build.work_dir
  end
  if k == "at_bundle_top" then
    return env.at_top and not env.is_standalone
  end
  if k == "bundleunpack" then
    return require("l3build-unpack").bundleunpack
  end
  if k == "bundleunpackcmd" then
    return require("l3build-unpack").bundleunpackcmd
  end
  if k == "tds_main" then
    return env.is_standalone
      and env.tdsroot / env.module
      or  env.tdsroot / env.bundle
  end
  if k == "tds_module" then
    return env.is_standalone
      and env.module
      or  env.bundle / env.module
  end
end

G = bridge({
  index    = G_index,
  complete = function (env, k, result)
    local entry = get_entry(k)
    if entry and entry.complete then
      return entry.complete(env, k, result)
    end
    return result
  end,
  newindex = function (env, k, v)
    if k == "typeset_list" then
      rawset(env, k, v)
      return true
    end
    if k == "config_suffix" then
      --print(debug.traceback())
      rawset(env, k, v)
      return true
    end
  end,
})

Dir = bridge({
  primary = G,
  suffix = "dir",
  complete = function (env, k, result) -- In progress
    -- No trailing /
    -- What about the leading "./"
    if k.match then
      if not result then
        error("No result for key ".. k)
      end
      result = result / "."
      if result == "." then
        result = "./" -- bad smell
      end
      return quoted_path(result) -- any return result will be quoted_path
    end
    return result
  end,
})

-- Dir.work = work TODO: what is this ?

Files = bridge({
  primary = G,
  suffix = "files",
  index = function (t, k)
    if k == "_all_typeset" then
      local result = {}
      for glob in entries(t.typeset) do
        push(result, glob)
      end
      for glob in entries(t.typesetdemo) do
        push(result, glob)
      end
      return result
    end
    if k == "_all_pdf" then
      local result = {}
      for glob in entries(t._all_typeset) do
        push(result, first_of(glob:gsub( "%.%w+$", ".pdf")))
      end
      return result
    end
  end
})

Deps = bridge({
  primary = G,
  suffix = "deps",
})

Exe = bridge({
  primary = G,
  suffix = "exe",
})

Opts = bridge({
  primary = G,
  suffix = "opts"
})

Xtn = bridge({
  primary = G,
  suffix = "ext", -- Xtn.bak -> _G.bakext
})

---Get the description of the named global variable
---@param name string
---@return string
local function get_description(name)
  ---@type VariableEntry
  local entry = get_entry(name)
  return entry and entry.description
    or ("No global variable named ".. name)
end

---Export globals in the metatable of the given table.
---At the end, `env` will know about any variable
---that was previously `declare`d.
---@generic T
---@param env? T @defaults to `_G`
---@return T
local function export(env)
  env = env or _G
  -- if there is already an __index function metamethod, we amend it
  -- if there is no such metamethod, we add a fresh one
  local MT = getmetatable(env) or {}
  local __index = MT.__index
  ---@type function | nil
  local f_index = type(__index) == "function" and __index or nil
  ---@type table | nil
  local t_index = type(__index) == "table"    and __index or nil
  function MT.__index(t, k)
    local result
    ---@type VariableEntry
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
      -- fall back to the static value when defined
      result = entry.value
      if result ~= nil then
        return result
      end
    end
    -- use the original metamethod, if any
    if t_index then
      result = t_index[k]
    elseif f_index then
      result = f_index(t, k)
    end
    return result
  end
  return setmetatable(env, MT)
end

local vanilla
---Get the vanilla global environment
---@return table
local function get_vanilla()
  if not vanilla then
    vanilla = {}
    export(vanilla)
  end
  return vanilla
end

VariableEntry.__instance_table = {
  type = function (self)
    local result = type(self.vanilla_value)
    rawset(self, "type", result)
    return result
  end,
  vanilla_value = function (self)
    local result = get_vanilla()[self.name]
    rawset(self, "vanilla_value", result)
    return result
  end,
}

local level_by_type = {
  ["nil"] = 5,
  ["number"] = 2,
  ["string"] = 2,
  ["boolean"] = 2,
  ["table"] = 2,
  ["function"] = 1,
  ["thread"] = 3,
  ["userdata"] = 4,
}

---Get the level of the receiver
---@param self VariableEntry
---@return integer
function VariableEntry.__instance_table:level()
  local result = level_by_type[self.type]
  rawset(self, "level", result)
  return result
end

---metamethod to compare 2 variable entries
---@param lhs VariableEntry
---@param rhs VariableEntry
---@return boolean
function VariableEntry.__lt(lhs, rhs)
  local lhs_level = lhs.level
  local rhs_level = rhs.level
  if lhs_level < rhs_level then
    return true
  elseif lhs_level > rhs_level then
    return false
  else
    return lhs.name < rhs.name
  end
end

---@alias entry_exclude_f fun(entry: VariableEntry): boolean
---@alias entry_enumerator_f fun(): VariableEntry

---Iterator over all the global variable names
---@param exclude? entry_exclude_f
---@return entry_enumerator_f
local function all_entries(exclude)
  return entries(entry_by_index, {
    compare = compare_ascending,
    exclude = exclude,
  })
end

---@class l3b_globals_t
---@field public LOCAL  any
---@field public G      G_t
---@field public Dir    Dir_t
---@field public Files  Files_t
---@field public Deps   Deps_t
---@field public Exe    Exe_t
---@field public Opts   Opts_t
---@field public Xtn    Xtn_t
---@field public get_main_variable         fun(name: string, dir: string): string
---@field public handle_get_main_variable  fun(name: string): error_level_n
---@field public export                    function
---@field public get_vanilla               fun(): table
---@field public get_entry                 fun(name: string): VariableEntry
---@field public get_descriptions          fun(name: string): string
---@field public all_entries               fun(exclude: entry_exclude_f): entry_enumerator_f

return {
  LOCAL                 = LOCAL,
  G                     = G,
  Dir                   = Dir,
  Files                 = Files,
  Deps                  = Deps,
  Exe                   = Exe,
  Opts                  = Opts,
  Xtn                   = Xtn,
  get_main_variable     = get_main_variable,
  handle_get_main_variable = handle_get_main_variable,
  export                = export,
  get_vanilla           = get_vanilla,
  get_entry             = get_entry,
  get_description       = get_description,
  all_entries           = all_entries,
},
---@class __l3b_globals_t
---@field private VariableEntry   VariableEntry
---@field private entry_by_name   table<string,VariableEntry>
---@field private entry_by_index  VariableEntry[]
---@field private declare         fun(by_name: table<string,pre_variable_entry_t>)
---@field private get_entry       fun(name: string), ValiableEntry
_ENV.during_unit_testing and {
  VariableEntry   = VariableEntry,
  entry_by_name   = entry_by_name,
  entry_by_index  = entry_by_index,
  declare         = declare,
  get_entry       = get_entry,
}
