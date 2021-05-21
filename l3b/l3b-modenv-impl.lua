--[[

File l3b-modenv.lua Copyright (C) 2018-2020 The LaTeX Project

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

--[===[
Define the `ModEnv` class as model to a module environment.
--]===]
---@module modenv

local _G = _G

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

local lpeg = require("lpeg")
local C = lpeg.C
local P = lpeg.P
local V = lpeg.V

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
local shallow_copy      = corelib.shallow_copy

---@type utlib_t
local utlib             = require("l3b-utillib")
local is_error          = utlib.is_error
local entries           = utlib.entries
local compare_ascending = utlib.compare_ascending
local first_of          = utlib.first_of
local to_quoted_string  = utlib.to_quoted_string
local items             = utlib.items

---@type oslib_t
local oslib         = require("l3b-oslib")
local quoted_path   = oslib.quoted_path
local OS            = oslib.OS
local cmd_concat    = oslib.cmd_concat
local run           = oslib.run
local read_command  = oslib.read_command

---@type fslib_t
local fslib                 = require("l3b-fslib")
local directory_exists      = fslib.directory_exists
local file_exists           = fslib.file_exists
local all_names             = fslib.all_names
local quoted_absolute_path  = fslib.quoted_absolute_path
local push_pop_current_directory = fslib.push_pop_current_directory

---@type l3b_aux_t
local l3b_aux = require("l3build-aux")
local set_epoch_cmd = l3b_aux.set_epoch_cmd

---@type l3build_t
local l3build = require("l3build")

---@type modlib_t
local modlib = require("l3b-modlib")

-- Package implementation

---@type Module
local Module = modlib.Module
---@type Module
local ModEnv = modlib.ModEnv


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
---@field public pkg           string        @Name of the CTAN package (defaults to env.ctanpkg)
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

---@class ModEnv: Env
---@field public _G table @ a readonly _G
---The main directory of a module
---In general the path of the topmost module including the receiver.
---This is meant to be shared by all the modules in the same bundle.
---@field public maindir string
---_ENV.ctorydir containing general support files
---Defaults to the `support` directory in the main one.
---@field public supportdir string
---_ENV.ctorydir containing support files in tree form
---Defaults to the `texmf` directory in the main one.
---@field public texmfdir string
---_ENV.ctorydir for building and testing
---Defaults to the `build` directory in the main one.
---@field public builddir string
---_ENV.ctorydir containing documentation files
---Defaults to the directory of the module.
---@field public docfiledir string
---_ENV.ctorydir containing source files
---Defaults to the directory of the module.
---@field public sourcefiledir string
---_ENV.ctorydir containing test files
---Defaults to the "testfiles" subdirectory of the module.
---@field public testfiledir string
---_ENV.ctorydir containing test-specific support files
---Defaults to the "support" subdirectory of the module.
---The contents of this folder will be copied to the testing folder
---in the build area.
---@field public testsuppdir string
---_ENV.ctorydir containing plain text files
---Defaults to the directory of the module.
---@field public textfiledir string
---_ENV.ctorydir for generating distribution structure
---Defaults to the "distrib" directory in the build folder.
---@field public distribdir string
-- Substructure for CTAN release material
---_ENV.ctorydir for extracted files in 'sandboxed' TeX runs
---Defaults to the "local" directory in the build folder.
---@field public localdir string
---_ENV.ctorydir for PDF files when using PDF-based tests
---Defaults to the "result" directory in the build folder.
---@field public resultdir string
---_ENV.ctorydir for running tests
---Defaults to the directory in the build folder named "test"
---with an eventual confiuration suffix.
---@field public testdir string
---_ENV.ctorydir for building documentation
---Defaults to the "doc" directory in the build folder
---@field public typesetdir string
---_ENV.ctorydir for unpacking sources
---Defaults to the "unpacked" directory in the build folder.
---@field public unpackdir string
---_ENV.ctorydir for organising files for CTAN
---Defaults to the "ctan" directory in the distribution folder.
---@field public ctandir string
---_ENV.ctorydir for organised files into TDS structure
---Defaults to the "tds" directory in the distribution folder.
---@field public tdsdir string
---Module directory
---@field public workdir string
---_ENV.ctorydir for organised files into TDS structure
---Defaults to the "tds" directory in the distribution folder.
---@field public config_suffix string
-- File types for various operations
-- Use Unix-style globs
---@field public auxfiles           string[] @Secondary files to be saved as part of running tests
---@field public bibfiles           string[] @BibTeX database files
---@field public binaryfiles        string[] @Files to be added in binary mode to zip files
---@field public bstfiles           string[] @BibTeX style files
---@field public checkfiles         string[] @Extra files unpacked purely for tests
---@field public checksuppfiles     string[] @Files needed for performing regression tests
---@field public cleanfiles         string[] @Files to delete when cleaning
---@field public demofiles          string[] @Files which show how to use a module
---@field public docfiles           string[] @Files which are part of the documentation but should not be typeset
---@field public dynamicfiles       string[] @Secondary files to cleared before each test is run
---@field public excludefiles       string[] @Files to ignore entirely (default for Emacs backup files)
---@field public installfiles       string[] @Files to install to the `tex` area of the `texmf` tree
---@field public makeindexfiles     string[] @MakeIndex files to be included in a TDS-style zip
---@field public scriptfiles        string[] @Files to install to the `scripts` area of the `texmf` tree
---@field public scriptmanfiles     string[] @Files to install to the `doc/man` area of the `texmf` tree
---@field public sourcefiles        string[] @Files to copy for unpacking
---@field public tagfiles           string[] @Files for automatic tagging
---@field public textfiles          string[] @Plain text files to send to CTAN as-is
---@field public typesetdemofiles   string[] @Files to typeset before the documentation for inclusion in main documentation files
---@field public typesetfiles       string[] @Files to typeset for documentation
---@field public typesetsuppfiles   string[] @Files needed to support typesetting when 'sandboxed'
---@field public typesetsourcefiles string[] @Files to copy to unpacking when typesetting
---@field public unpackfiles        string[] @Files to run to perform unpacking
---@field public unpacksuppfiles    string[] @Files needed to support unpacking when 'sandboxed'
-- TODO= XFER to the module!!!
---@field public _all_typesetfiles  string[] @To combine `typeset` files and `typesetdemo` files
---@field public _all_pdffiles      string[] @Counterpart of "_all_typeset"
--ANCHOR File extensions
---@field public bakext string @ Extension of backup files
---@field public dviext string @ Extension of DVI files
---@field public lvtext string @ Extension of log-based test files
---@field public tlgext string @ Extension of test files output
---@field public tpfext string @ Extension of PDF-based test output
---@field public lveext string @ Extension of auto-generating test file output
---@field public logext string @ Extension of checking output, before processing it into a `.tlg`
---@field public pvtext string @ Extension of PDF-based test files
---@field public pdfext string @ Extension of PDF file for checking and saving
---@field public psext  string @ Extension of PostScript files
--ANCHOR: what's net?
---@field public tdsroot       string   @Root directory of the TDS structure for the bundle/module to be installed into
---@field public ctanupload    boolean  @Only validation is attempted
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
---@field public packtdszip      boolean @Switch to build a TDS-style zip file for CTAN
---@field public curl_debug      boolean
---@field public uploadconfig    upload_config_t @Metadata to describe the package for CTAN
---@field public texmf_home      string
---@field public typeset_list    string[]
-- tag
---@field public tag_hook        tag_hook_f
---@field public update_tag      update_tag_f
-- OS related
---@field public os_ascii                           string @ nil,
---@field public os_cmpexe                          string @ nil,
---@field public os_cmpext                          string @ nil,
---@field public os_concat                          string @ The concatenation operation for using multiple commands in one system call,
---@field public os_diffexe                         string @ nil,
---@field public os_diffext                         string @ nil,
---@field public os_grepexe                         string @ nil,
---@field public os_null                            string @ The location to redirect commands which should produce no output at the terminal: almost always used preceded by `>`,
---@field public os_pathsep                         string @ The separator used when setting an environment variable to multiple paths.,
---@field public os_setenv                          string @ The command to set an environmental variable.,
---@field public os_yes                             string @ DEPRECATED.,
-- function tools
---@field public abspath                            function  @ The absolute path
---@field public basename                           function  @ The base name of a path
---@field public call                               function  @ Call targets on modules with options.
---@field public cleandir                           string    @ Clean directory
---@field public cp                                 function  @ copy files matching a glob
---@field public direxists                          function  @ Whether a directory exists at the given path
---@field public dirname                            function @ The directory name of a path
---@field public fileexists                         function @ Whether a file exists at the given path
---@field public filelist                           function @ The list of file rooted at some directory matching some glob
---@field public glob_to_pattern                    function @ Turn a glob to lua pattern for find
---@field public jobname                            function @ Base name without its extension
---@field public mkdir                              string @ Make a (deep) directory at the given path
---@field public normalize_path                     fun(path:string):string @ When called on Windows, returns a properly escaped string
---@field public path_matcher                       fun(glob:string):fun(name:string):boolean  @ To obtain a glob matcher
---@field public ren                                function @ Move a file
---@field public rm                                 function @ Remove all files matching some glob
---@field public run                                function @ Execute a shell command from a directory.
---@field public splitpath                          function @ Returns two strings split at the last `/`
-- Other
---@field public bundle                             string @ The name of the bundle in which the module belongs (where relevant),
---@field public module                             string @ The name of the module,
---@field public ctanpkg                            string @ Name of the CTAN package matching this module,
---@field public ctanreadme                         string @ Name of the file to send to CTAN as `README`.md,
---@field public ctanzip                            string @ Name of the zip file (without extension) created for upload to CTAN,
---@field public epoch                              number @ Epoch (Unix date) to set for test runs,
---@field public exclmodules                        string[] @ directories to be excluded from automatic module detection,
---@field public flatten                            boolean @ Switch to flatten any source structure when sending to CTAN,
---@field public flattenscript                      boolean @ Switch to flatten any script structure when creating a TDS structure,
---@field public flattentds                         boolean @ Switch to flatten any source structure when creating a TDS structure,
---@field public install_files                      string @ ,
---@field public ps2pdfopts                         string @ Options for `ps2pdf`,
---@field public manifest_extract_filedesc          any @ ,
---@field public manifest_setup                     fun():table[] @ ,
---@field public manifest_sort_within_group         fun(files: string[]):string[] @ ,
---@field public manifest_sort_within_match         fun(files: string[]):string[] @ ,
---@field public manifest_write_group_file          string @ ,
---@field public manifest_write_group_file_descr    string @ ,
---@field public manifest_write_group_heading       string @ ,
---@field public manifest_write_opening             string @ ,
---@field public manifest_write_subheading          string @ ,
---@field public manifestfile                       string @ File name to use for the manifest file,
---@field public modules                            string[] @ The list of all modules in a bundle (when not auto-detecting),
---@field public options                            table @ nil,
---@field public tdslocations                       string[] @ For non-standard file installations,


-- We populate the ModEnv class table.
-- This will define computed properties that
-- will be available to the class, its instances
-- and will be inherited by descendants
-- In all fields of this table,
-- self is either an instance or a class.
-- If it is an instance, it has an owning module.
-- If it is a class, its module is the Module class.
-- Alternate design: one can have a phantom module
-- associate to the class

local GTR = ModEnv.__.getter

local short_module_dir = "." -- shortcut to the module directory

function GTR:supportdir()
  return self.maindir / "support"
end

function GTR:texmfdir()
  return self.maindir / "texmf"
end

function GTR:builddir()
  return self.maindir / "build"
end

function GTR.docfiledir()
  return short_module_dir
end

function GTR.sourcefiledir()
  return short_module_dir
end

function GTR:testfiledir()
  return short_module_dir / "testfiles"
end

function GTR:testsuppdir()
  return self.testfiledir / "support"
end

function GTR.textfiledir()
  return short_module_dir
end

function GTR:distribdir()
  return self.builddir / "distrib"
end

function GTR:localdir()
  return self.builddir / "local"
end

function GTR:resultdir()
  return self.builddir / "result"
end

function GTR:testdir()
  return self.builddir / "test" .. self.config_suffix
end

function GTR:typesetdir()
  return self.builddir / "doc"
end

function GTR:unpackdir()
  return self.builddir / "unpacked"
end

function GTR:ctandir()
  return self.distribdir / "ctan"
end

function GTR:tdsdir()
  return self.distribdir / "tds"
end

function GTR:workdir()
  local module = Module.__get_module_of_env(self)
  return module.path
end

-- overwritten after load_unique_config call
function GTR:config_suffix()
  local module = Module.__get_module_of_env(self)
  return module.config_suffix
end

function GTR:tdsroot()
  return "latex"
end

function GTR:ctanupload()
  return false
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

-- file globs

---Make a shallow copy of the argument
---Different modules must have their own copy.
---Moreover, we must support both reaffectation
---and modification
---@param ra any
---@return function
local function array_getter(ra)
  return function (self, k)
    local result = ra and shallow_copy(ra) or {}
    rawset(self, k, result)
    return result
  end
end

GTR.auxfiles        = array_getter({ "*.aux", "*.lof", "*.lot", "*.toc" })

GTR.bibfiles        = array_getter({ "*.bib" })

GTR.binaryfiles     = array_getter({ "*.pdf", "*.zip" })

GTR.bstfiles        = array_getter({ "*.bst" })

GTR.checkfiles      = array_getter()

GTR.checksuppfiles  = array_getter()

GTR.cleanfiles      = array_getter({ "*.log", "*.pdf", "*.zip" })

GTR.demofiles       = array_getter()

GTR.docfiles        = array_getter()

GTR.dynamicfiles    = array_getter()

GTR.excludefiles    = array_getter({ "*~" })

GTR.installfiles    = array_getter({ "*.sty", "*.cls" })

GTR.makeindexfiles  = array_getter({ "*.ist" })

GTR.scriptfiles     = array_getter()

GTR.scriptmanfiles  = array_getter()

GTR.sourcefiles     = array_getter({ "*.dtx", "*.ins", "*-????-??-??.sty" })

GTR.tagfiles        = array_getter({ "*.dtx" })

GTR.textfiles       = array_getter({ "*.md", "*.txt" })

GTR.typesetdemofiles    = array_getter()

GTR.typesetfiles        = array_getter({ "*.dtx" })

GTR.typesetsuppfiles    = array_getter()

GTR.typesetsourcefiles  = array_getter()

GTR.unpackfiles     = array_getter({ "*.ins" })

GTR.unpacksuppfiles = array_getter()

-- check
GTR.includetests    = array_getter({ "*" })

GTR.excludetests    = array_getter()

GTR.checkdeps       = array_getter()

GTR.typesetdeps     = array_getter()

GTR.unpackdeps      = array_getter()

GTR.checkengines    = array_getter({ "pdftex", "xetex", "luatex" })

print("ERROR, NEXT should go to module")
--[[
  checkengines
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
  end

]]
function GTR:stdengine()
  return "pdftex"
end
function GTR:checkformat()
  return "latex"
end
function GTR:specialformats()
  return specialformats
end
function GTR:test_types()
  ---@type l3b_check_t
  local l3b_check = require("l3build-check")
  return {
    log = {
      test        = self.lvtext,
      generated   = self.logext,
      reference   = self.tlgext,
      expectation = self.lveext,
      compare     = l3b_check.compare_tlg,
      rewrite     = l3b_check.rewrite_log,
    },
    pdf = {
      test      = self.pvtext,
      generated = self.pdfext,
      reference = self.tpfext,
      rewrite   = l3b_check.rewrite_pdf,
    }
  }
end

GTR.test_order    = array_getter({ "log", "pdf" })

GTR.checkconfigs  = array_getter({ "build" })

print("ERROR: Next should go to module")
--[[
  checkconfigs:
    local options = self[MODULE].options
  -- When we have specific files to deal with, only use explicit configs
  -- (or just the std one)
  -- TODO: Justify this...
  if options.names then
    return options.config or { _G["stdconfig"] }
  else
    return options.config or result
  end
]]
-- Executable names
function GTR:typesetexe()
  return "pdflatex"
end
function GTR:unpackexe()
  return "pdftex"
end
function GTR:zipexe()
  return "zip"
end
function GTR:biberexe()
  return "biber"
end
function GTR:bibtexexe()
  return "bibtex8"
end
function GTR:makeindexexe()
  return "makeindex"
end
function GTR:curlexe()
  return "curl"
end
-- CLI Options
function GTR:checkopts()
  return "-interaction=nonstopmode"
end
function GTR:typesetopts()
  return "-interaction=nonstopmode"
end
function GTR:unpackopts()
  return ""
end
function GTR:zipopts()
  return "-v -r -X"
end
function GTR:biberopts()
  return ""
end
function GTR:bibtexopts()
  return "-W"
end
function GTR:makeindexopts()
  return ""
end
function GTR:ps2pdfopt() -- beware of the ending s (long term error)
  return ""
end
-- Synonyms: ps2pdfopt and ps2pdfopts
function GTR:ps2pdfopts()
  return self.ps2pdfopt
end

function GTR.__.setter:ps2pdfopts(k, v)
  self.ps2pdfopt = v
end

--TODO what is the description
function GTR:config()
  return ""
end
--TODO what is the description
function GTR:curl_debug()
  return false
end

-- file extensions
function GTR:bakext()
  return ".bak"
end
function GTR:dviext()
  return ".dvi"
end
function GTR:lvtext()
  return ".lvt"
end
function GTR:tlgext()
  return ".tlg"
end
function GTR:tpfext()
  return ".tpf"
end
function GTR:lveext()
  return ".lve"
end
function GTR:logext()
  return ".log"
end
function GTR:pvtext()
  return ".pvt"
end
function GTR:pdfext()
  return ".pdf"
end
function GTR:psext()
  return ".ps"
end

-- OS related

function GTR:os_ascii()
  return OS.ascii
end

function GTR:os_cmpexe()
  return OS.cmpexe
end

function GTR:os_cmpext()
  return OS.cmpext
end

function GTR:os_concat()
  return OS.concat
end

function GTR:os_diffexe()
  return OS.diffexe
end

function GTR:os_diffext()
  return OS.diffext
end

function GTR:os_grepexe()
  return OS.grepexe
end

function GTR:os_null()
  return OS.null
end

function GTR:os_pathsep()
  return OS.pathsep
end

function GTR:os_setenv()
  return OS.setenv
end

function GTR:os_yes()
  return OS.yes
end

-- function tools

function GTR:abspath()
  return fslib.absolute_path
end

function GTR:dirname()
  return pathlib.dir_name
end

function GTR:basename()
  return pathlib.base_name
end

function GTR:cleandir()
  return fslib.make_clean_directory
end

function GTR:cp()
  return fslib.copy_tree
end

function GTR:direxists()
  return fslib.directory_exists
end

function GTR:fileexists()
  return fslib.file_exists
end

function GTR:filelist()
  return fslib.file_list
end

function GTR:glob_to_pattern()
  return pathlib.glob_to_pattern
end

function GTR:jobname()
  return pathlib.job_name
end

function GTR:mkdir()
  return fslib.make_directory
end

function GTR:path_matcher()
  return pathlib.path_matcher
end

function GTR:ren()
  return fslib.rename
end

function GTR:rm()
  return fslib.remove_tree
end

function GTR:run()
  return oslib.run
end

function GTR:splitpath()
  return pathlib.dir_base
end

function GTR:normalize_path()
  return fslib.to_host
end

function GTR:call()
  return l3b_aux.call
end

--ANCHOR Commands

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
  local texmfdir = _ENV.texmfdir
  if texmfdir and texmfdir ~= "" and directory_exists(texmfdir) then
    local_texmf = OS.pathsep .. quoted_absolute_path(texmfdir) .. "/"
  end
  local localdir = _ENV.localdir
  local typesetsearch = _ENV.typesetsearch
  local env_paths = "."
    .. local_texmf .. OS.pathsep
    .. quoted_absolute_path(localdir) .. OS.pathsep
    .. dir .. (typesetsearch and OS.pathsep or "")
  -- Deal with spaces in paths
  if os_type == "windows" and env_paths:match(" ") then
    env_paths = first_of(env_paths:gsub('"', '')) -- no '"' in windows!!!
  end
  -- Allow for local texmf files
  local setenv_cmd = OS.setenv .. " TEXMFCNF=." .. OS.pathsep
  for var in entries(vars) do
    setenv_cmd = cmd_concat(setenv_cmd, OS.setenv .. " " .. var .. "=" .. env_paths)
  end
  local epoch = _ENV.epoch
  local forcedocepoch = _ENV.forcedocepoch
  local epoch_cmd = set_epoch_cmd(epoch, forcedocepoch)
  print("set_epoch_cmd(epoch, forcedocepoch)", set_epoch_cmd(epoch, forcedocepoch))
  print(setenv_cmd)
  print(cmd)
  return run(dir, cmd_concat(epoch_cmd, setenv_cmd, cmd))
end

---biber
---@param name string
---@param dir string
---@return error_level_n
local function biber(name, dir)
  if file_exists(dir / name .. ".bcf") then
    return _ENV.runcmd(
      _ENV.biberexe + _ENV.biberopts + name,
      dir,
      { "BIBINPUTS" }
    )
  end
  return 0
end

---bibtex
---@param name string
---@param dir string
---@return error_level_n
local function bibtex(name, dir)
  if file_exists(dir / name .. ".aux") then
    -- LaTeX always generates an .aux file, so there is a need to
    -- look inside it for a \citation line
    local grep = os_type == "windows"
      and [[\\]]
      or  [[\\\\]]
    if not is_error(
      run(
        dir,
        OS.grepexe
        + "\"^" .. grep .. "citation{\""
        + name .. ".aux"
        + ">" .. OS.null
      )
    + run(
        dir,
        OS.grepexe
        + "\"^" .. grep .. "bibdata{\""
        + name .. ".aux"
        + ">"  .. OS.null
      )
    )
    then
      return _ENV.runcmd(
        _ENV.bibtexexe + _ENV.bibtexopts + name,
        dir,
        { "BIBINPUTS", "BSTINPUTS" }
      )
    end
  end
  return 0
end

---makeindex
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
    return _ENV.runcmd(
      _ENV.makeindexexe
        + _ENV.makeindexopts
        + "-o" + name .. out_ext
        .. (style == "" and "" or ("-s" + style))
        + "-t" + name .. log_ext
        + name .. in_ext,
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
  cmd = cmd or _ENV.typesetexe + _ENV.typesetopts
  return _ENV.runcmd(
    cmd
      + '"' .. _ENV.typesetcmd .. [[\input]] + file .. '"',
    dir,
    { "TEXINPUTS", "LUAINPUTS" }
  )
end

---typeset. Default command is the same as for `tex`.
---@param file string
---@param dir string
---@param cmd string|nil
---@return error_level_n
local function typeset(file, dir, cmd)
  local error_level = _ENV.tex(file, dir, cmd)
  if is_error(error_level) then
    return error_level
  end
  local name = job_name(file)
  error_level = _ENV.biber(name, dir) + _ENV.bibtex(name, dir)
  if is_error(error_level) then
    return error_level
  end
  for i = 2, _ENV.typesetruns do
    error_level = _ENV.makeindex(name, dir, ".glo", ".gls", ".glg", _ENV.glossarystyle)
                + _ENV.makeindex(name, dir, ".idx", ".ind", ".ilg", _ENV.indexstyle)
                + _ENV.tex(file, dir, cmd)
    if is_error(error_level) then
      break
    end
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

-- typesetting functions

function GTR:biber()
  return biber
end

function GTR:bibtex()
  return bibtex
end

function GTR:tex()
  return tex
end

function GTR:makeindex()
  return makeindex
end

function GTR:runcmd()
  return runcmd
end

function GTR:typeset()
  return typeset
end

function GTR:typeset_demo_tasks()
  return typeset_demo_tasks
end

function GTR:docinit_hook()
  return docinit_hook
end

function GTR:checkinit_hook()
  return checkinit_hook
end

function GTR:tag_hook()
  return require("l3build-tag").tag_hook
end

function GTR:update_tag()
  return require("l3build-tag").update_tag
end

function GTR:runtest_tasks()
  return runtest_tasks
end

-- Other

GTR.asciiengines = array_getter({ "pdftex" })

function GTR:checkruns()
  return 3
end

function GTR:checksearch()
  return true
end

--[[
---@field public abspath                            function
---Usage: `abspath("foo.bar")`
---Returns "/absolute/path/to/foo.bar" on unix like systems
---and "C:\absolute\path\to\foo.bar" on windows.

---@field public basename                           function
---Usage: `basename("path/to/foo.bar")`
---Returns "foo.bar".

---@field public biber                              function
---Runs Biber on file `name` (i.e a jobname lacking any extension)
---inside the dir` folder. If there is no `.bcf` file then
---no action is taken with a return value of `0`.

---@field public bibtex                             function
---Runs BibTeX on file `name` (i.e a jobname lacking any extension)
---inside the `dir` folder. If there are no `\citation` lines in
---the `.aux` file then no action is taken with a return value of `0`.

---@field public call                               function
---`call(modules, target, options)`.
---Runs the  `l3build` given `target` (a string) for each directory in the
---`dirs` list. This will pass command line options from the parent
---script to the child processes. The `options` table should take the
---same form as the global `options`, described above. If it is
---absent then the global list is used.
---Note that the `target` field in this table is ignored.

---@field public cleandir                           string
---Usage: `cleandir("path/to/dir")`
---Removes any content in "path/to/dir" directory.
---Returns 0 on success, a positive number on error.

---@field public cp                                 function
---Usage: `cp("*.bar", "path/to/source", "path/to/destination")`
---Copies files matching the "*.bar" from "path/to/source" directory
---to the "path/to/destination" directory.
---Returns 0 on success, a positive number on error.

---@field public direxists                          function
---`direxists("path/to/dir")`
---Returns `true` if there is a directory at "path/to/dir",
---`false` otherwise.

---@field public dirname                            function
---Usage: `dirname("path/to/foo.bar")`
---Returns "path/to".

---@field public fileexists                         function
---`fileexists("path/to/foo.bar")`
---Returns `true` if there is a file at "path/to/foo.bar",
---`false` otherwise.

---@field public filelist                           function
---`filelist("path/to/dir", "*.bar")
---Returns a regular table of all the files within "path/to/dir"
---which name matches "*.bar";
---if no glob is provided, returns a list of
---all files at "path/to/dir".

---@field public glob_to_pattern                    function
---`glob_to_pattern("*.bar")`
---Returns Lua pattern that corresponds to the glob "*.bar".

---@field public jobname                            function
---`jobname("path/to/dir/foo.bar")`
---Returns the argument with no extension and no parent directory path,
---"foo" in the example. 

---@field public makeindex                          function
---Runs MakeIndex on file `name` (i.e a jobname lacking any extension)
---inside the `dir` folder. The various extensions and the `style`
---should normally be given as standard for MakeIndex.

---@field public mkdir                              string
---`mkdir("path/to/dir")`
---Create "path/to/dir" with all intermediate levels;
---returns 0 on success, a positive number on error.

---@field public normalize_path                     function
---When called on Windows, returns a string comprising the `path` argument with
---`/` characters replaced by `\\`. In other cases returns the path unchanged.

---@field public path_matcher                       function
---`f = path_matcher("*.bar")`
---Returns a function that returns true if its file name argument
---matches "*.bar", false otherwise. Lua pattern that corresponds to the glob "*.bar".
---In that example `f("foo.bar")` is true whereas `f("foo.baz")` is false.

---@field public ren                                function
---`ren("foo.bar", "path/to/source", "path/to/destination")`
---Renames "path/to/source/foo.bar" into "path/to/destination/foo.bar";
---returns 0 on success, a positive number on error.

---@field public rm                                 function
---`rm("path/to/dir", "*.bar")
---Removes all files in "path/to/dir" matching "*.bar";
---returns 0 on success, a positive number on error.

---@field public run                                function
---`run(cmd, dir)`.
---Executes `cmd`, from the `dir` directory;
---returns an error level.

---@field public runcmd                             function
---A generic function which runs the `cmd` in the `dir`, first
---setting up all of the environmental variables specified to
---point to the `local` and `working` directories. This function is useful
---when creating non-standard typesetting steps.

---@field public splitpath                          function
---Returns two strings split at the last `/`: the `dirname(...)` and
---the `basename(...)`.

---@field public tag_hook                           function
---Usage: `function tag_hook(tag_name, date)
---  ...
---end`
---  To allow more complex tasks to take place, a hook `tag_hook()` is also
---available. It will receive the tag name and date as arguments, and
---may be used to carry out arbitrary tasks after all files have been updated.
---For example, this can be used to set a version control tag for an entire repository.

---@field public tex                                function
---Runs `cmd` (by default `typesetexe` `typesetopts`) on the
---`name` inside the `dir` folder.

---@field public update_tag                         function
---Usage: function update_tag(file, content, tag_name, tag_date)
---  ...
---  return content
---end
---The `tag` target can automatically edit source files to
---modify date and release tag name. As standard, no automatic
---replacement takes place, but setting up a `update_tag` function
---will allow this to happen.

]]

function GTR:module()
  local module = Module.__get_module_of_env(self)
  return job_name(module.path)
end

function GTR:bundle()
  local module = Module.__get_module_of_env(self)
  return module.bundle
end

function GTR:ctanpkg()
  return  self.is_standalone
      and self.module
      or (self.bundle / self.module)
end

function GTR:ctanreadme()
  return "README.md"
end

function GTR:ctanzip()
  return self.ctanpkg .. "-ctan"
end

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

function GTR:epoch()
  local options = l3build.options
  return options.epoch or 1463734800
end

function ModEnv.__.complete:epoch(k, v)
  if k == "epoch" then
    return normalise_epoch(v)
  end
end

GTR.exclmodules = array_getter()

function GTR:flatten()
  return true
end

function GTR:flattenscript()
  return self.flattentds
end

function GTR:flattentds()
  return true
end

function ModEnv.__.complete:flatten(k, v)
  return v ~= nil and v ~= false and v ~= "false"
end

function ModEnv.__.complete:flattenscript(k, v)
  return v ~= nil and v ~= false and v ~= "false"
end

function ModEnv.__.complete:flattentds(k, v)
  return v ~= nil and v ~= false and v ~= "false"
end

function GTR:forcecheckepoch()
  return true
end

function ModEnv.__.complete:forcecheckepoch(k, v)
  local options = l3build.options
  if options.epoch then
    return true
  end
  return v ~= nil and v ~= false and v ~= "false"
end

function GTR:forcedocepoch()
  return false
end

function ModEnv.__.complete:forcedocepoch(k, v)
  v = v ~= nil and v ~= false and v ~= "false"
  local options = l3build.options
  return (options.epoch or v) and true or false
end

function GTR:glossarystyle()
  return "gglo.ist"
end

function GTR:indexstyle()
  return "gind.ist"
end

function GTR:install_files()
  local module = Module.__get_module_of_env(self)
  return module.install_files
end

function GTR:maxprintline()
  return 79
end

function GTR:packtdszip()
  return false
end

function GTR:recordstatus()
  return false
end

function GTR:manifest_extract_filedesc()
  return function ()
    error("DEPRECATED")
  end
end

function GTR:manifest_setup()
  return function ()
    error("Missing manifest_setup")
  end
end

function GTR:manifest_sort_within_group()
  return function (files)
    return files
  end
end

function GTR:manifest_sort_within_match()
  return function (files)
    return files
  end
end

function GTR:manifest_write_group_file()
  return function ()
    error("DEPRECATED")
  end
end

function GTR:manifest_write_group_file_descr()
  return function ()
    error("DEPRECATED")
  end
end

function GTR:manifest_write_group_heading()
  return function ()
    error("DEPRECATED")
  end
end

function GTR:manifest_write_opening()
  return function ()
    error("DEPRECATED")
  end
end

function GTR:manifest_write_subheading()
  return function ()
    error("DEPRECATED")
  end
end

function GTR:manifestfile()
  return function ()
    error("DEPRECATED")
  end
end

function GTR:modules()
  local module = Module.__get_module_of_env(self)
  local result = {}
  for m in items(module.child_modules) do
    push(result, m.name)
  end
  return result
end

function GTR:options()
  local module = Module.__get_module_of_env(self)
  return module.options
end

function GTR:tdslocations(k)
  local result = {}
  rawset(self, k, result)
  return result
end

function GTR:typesetcmds()
  return ""
end

function GTR:typesetruns()
  return 3
end

function GTR:typesetsearch()
  return true
end

function GTR:unpacksearch()
  return true
end

function GTR:uploadconfig(k)
  local result = setmetatable({}, {
    __index = {
      pkg = self.ctanpkg,
    }
  })
  rawset(self, k, result)
  return result
end

function GTR:specialtypesetting(k)
  local result = {}
  rawset(self, k, result)
  return result
end

--ANCHOR ---@field

--[=====[
---@field public asciiengines                       table @ Engines which should log as pure ASCII,
---@field public biber                              function @ Runs Biber on file `name` (i.e a jobname lacking any extension)
inside the dir` folder. If there is no `.bcf` file then
no action is taken with a return value of `0`.
,
---@field public bibtex                             function @ Runs BibTeX on file `name` (i.e a jobname lacking any extension)
inside the `dir` folder. If there are no `\citation` lines in
the `.aux` file then no action is taken with a return value of `0`.
,
---@field public bundle                             string @ The name of the bundle in which the module belongs (where relevant),
---@field public checkinit_hook                     function @ A hook to initialize check process,
---@field public checkruns                          number @ Number of runs to complete for a test before comparing the log,
---@field public checksearch                        boolean @ Switch to search the system `texmf` for during checking,
---@field public ctanpkg                            string @ Name of the CTAN package matching this module,
---@field public ctanreadme                         string @ Name of the file to send to CTAN as `README`.md,
---@field public ctanzip                            string @ Name of the zip file (without extension) created for upload to CTAN,
---@field public docinit_hook                       function @ A hook to initialize doc process,
---@field public epoch                              number @ Epoch (Unix date) to set for test runs,
---@field public exclmodules                        string[] @ directories to be excluded from automatic module detection,
---@field public flatten                            boolean @ Switch to flatten any source structure when sending to CTAN,
---@field public flattenscript                      boolean @ Switch to flatten any script structure when creating a TDS structure,
---@field public flattentds                         boolean @ Switch to flatten any source structure when creating a TDS structure,
---@field public forcecheckepoch                    boolean @ Force epoch when running tests,
---@field public forcedocepoch                      string @ Force epoch when typesetting,
---@field public glossarystyle                      string @ MakeIndex style file for glossary/changes creation,
---@field public indexstyle                         string @ MakeIndex style for index creation,
---@field public install_files                      string @ ,
---@field public makeindex                          function @ Runs MakeIndex on file `name` (i.e a jobname lacking any extension)
inside the `dir` folder. The various extensions and the `style`
should normally be given as standard for MakeIndex.
,
---@field public manifest_extract_filedesc          string @ ,
---@field public manifest_setup                     string @ ,
---@field public manifest_sort_within_group         string @ ,
---@field public manifest_sort_within_match         string @ ,
---@field public manifest_write_group_file          string @ ,
---@field public manifest_write_group_file_descr    string @ ,
---@field public manifest_write_group_heading       string @ ,
---@field public manifest_write_opening             string @ ,
---@field public manifest_write_subheading          string @ ,
---@field public manifestfile                       string @ File name to use for the manifest file,
---@field public maxprintline                       number @ Length of line to use in log files,
---@field public module                             string @ The name of the module,
---@field public modules                            string[] @ The list of all modules in a bundle (when not auto-detecting),
---@field public options                            table @ nil,
---@field public packtdszip                         boolean @ Switch to build a TDS-style zip file for CTAN,
---@field public ps2pdfopts                         string @ Options for `ps2pdf`,
---@field public recordstatus                       boolean @ Switch to include error level from test runs in `.tlg` files,
---@field public runcmd                             function @ A generic function which runs the `cmd` in the `dir`, first
setting up all of the environmental variables specified to
point to the `local` and `working` directories. This function is useful
when creating non-standard typesetting steps.
,
---@field public runtest_tasks                      function @ A hook to allow additional tasks to run for the tests,
---@field public specialtypesetting                 table @ Non-standard typesetting combinations,
---@field public tag_hook                           function @ Usage: `function tag_hook(tag_name, date)
  ...
end`
  To allow more complex tasks to take place, a hook `tag_hook()` is also
available. It will receive the tag name and date as arguments, and
may be used to carry out arbitrary tasks after all files have been updated.
For example, this can be used to set a version control tag for an entire repository.
,
---@field public tdslocations                       table @ For non-standard file installations,
---@field public tex                                function @ Runs `cmd` (by default `typesetexe` `typesetopts`) on the
`name` inside the `dir` folder.
,
---@field public typeset                            function @ ,
---@field public typeset_demo_tasks                 function @ runs after copying files to the typesetting location but before the main typesetting run.,
---@field public typesetcmds                        string @ Instructions to be passed to TeX when doing typesetting,
---@field public typesetruns                        number @ Number of cycles of typesetting to carry out,
---@field public typesetsearch                      boolean @ Switch to search the system `texmf` for during typesetting,
---@field public unpacksearch                       boolean @ Switch to search the system `texmf` for during unpacking,
---@field public update_tag                         function @ Usage: function update_tag(file, content, tag_name, tag_date)
  ...
  return content
end
The `tag` target can automatically edit source files to
modify date and release tag name. As standard, no automatic
replacement takes place, but setting up a `update_tag` function
will allow this to happen.
,
---@field public uploadconfig                       table @ Metadata to describe the package for CTAN,
--]=====]
---@class BARN

--ANCHOR Variable entries

---@class pre_variable_entry_tX
---@field public description string
---@field public value       any
---@field public index       fun(self: VariableEntryX, env: table, k: string): any @ takes precedence over the value
---@field public complete    fun(self: VariableEntryX, env: table, k: string, v: any): any

---@class VariableEntryX: pre_variable_entry_tX
---@field public name           string
---@field public level          integer
---@field public type           string
---@field public vanilla_value  any

local VariableEntryX = Object:make_subclass("VariableEntryX")

---@class variable_entry_kvX: object_kv
---@field public name string

---@type table<string,VariableEntryX>
local entry_by_name = {}
---@type VariableEntryX[]
local entry_by_index = {}

---Declare the given variable
---@param by_name table<string,pre_variable_entry_tX>
local function declare(by_name)
  for name, entry in pairs(by_name) do
    assert(not entry_by_name[name], "Duplicate declaration ".. tostring(name))
    entry.name = name
    entry = VariableEntryX({
      data = entry,
    })
    entry_by_name[name] = entry
    push(entry_by_index, entry)
  end
end

---Get the variable entry for the given name.
---@param name string
---@return VariableEntryX
local function get_entry(name)
  return entry_by_name[name]
end

--ANCHOR Variable declarations

declare({
  modules = {
    description = "The list of all modules in a bundle (when not auto-detecting)",
    value_type = "string[]",
    index = function (env, k)
      local result = {}
      local excl_modules = env.exclmodules
      for name in all_names(_ENV.workdir) do
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
    description = "directories to be excluded from automatic module detection",
    value_type = "string[]",
    value       = {},
  },
  options = {
    value_type = "table",
    index = function (env, k)
      return l3build.options
    end,
  },
  module = {
    description = "The name of the module",
    value_type = "string",
    index = function (env, k)
      env:guess_bundle_module()
      return rawget(env, k)
    end,
  },
  bundle = {
    description = "The name of the bundle in which the module belongs (where relevant)",
    value_type = "string",
    index = function (env, k)
      env:guess_bundle_module()
      return rawget(env, k)
    end,
  },
  ctanpkg = {
    description = "Name of the CTAN package matching this module",
    value_type = "string",
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
      error("THIS IS DEPRECATED")
    end,
  },
  supportdir = {
    description = "_ENV.ctorydir containing general support files",
    index = function (env, k)
      return env.maindir / "support"
    end,
  },
  texmfdir = {
    description = "_ENV.ctorydir containing support files in tree form",
    index = function (env, k)
      return env.maindir / "texmf"
    end
  },
  builddir = {
    description = "_ENV.ctorydir for building and testing",
    index = function (env, k)
      return env.maindir / "build"
    end
  },
  docfiledir = {
    description = "_ENV.ctorydir containing documentation files",
    value       = short_module_dir,
  },
  sourcefiledir = {
    description = "_ENV.ctorydir containing source files",
    value       = short_module_dir,
  },
  testfiledir = {
    description = "_ENV.ctorydir containing test files",
    index = function (env, k)
      return short_module_dir / "testfiles"
    end,
  },
  testsuppdir = {
    description = "_ENV.ctorydir containing test-specific support files",
    index = function (env, k)
      return env.testfiledir / "support"
    end
  },
  -- Structure within a development area
  textfiledir = {
    description = "_ENV.ctorydir containing plain text files",
    value       = short_module_dir,
  },
  distribdir = {
    description = "_ENV.ctorydir for generating distribution structure",
    index = function (env, k)
      return env.builddir / "distrib"
    end
  },
  -- Substructure for CTAN release material
  localdir = {
    description = "_ENV.ctorydir for extracted files in 'sandboxed' TeX runs",
    index = function (env, k)
      return env.builddir / "local"
    end
  },
  resultdir = {
    description = "_ENV.ctorydir for PDF files when using PDF-based tests",
    index = function (env, k)
      return env.builddir / "result"
    end
  },
  testdir = {
    description = "_ENV.ctorydir for running tests",
    index = function (env, k)
      return env.builddir / "test" .. env.config_suffix
    end
  },
  typesetdir = {
    description = "_ENV.ctorydir for building documentation",
    index = function (env, k)
      return env.builddir / "doc"
    end
  },
  unpackdir = {
    description = "_ENV.ctorydir for unpacking sources",
    index = function (env, k)
      return env.builddir / "unpacked"
    end
  },
  ctandir = {
    description = "_ENV.ctorydir for organising files for CTAN",
    index = function (env, k)
      return env.distribdir / "ctan"
    end
  },
  tdsdir = {
    description = "_ENV.ctorydir for organised files into TDS structure",
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
    value_type = "string[]",
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
    value_type = "table",
    index = function (env, k)
      ---@type l3b_check_t
      local l3b_check = require("l3build-check")
      return {
        log = {
          test        = env.lvtext,
          generated   = env.logext,
          reference   = env.tlgext,
          expectation = env.lveext,
          compare     = l3b_check.compare_tlg,
          rewrite     = l3b_check.rewrite_log,
        },
        pdf = {
          test      = env.pvtext,
          generated = env.pdfext,
          reference = env.tpfext,
          rewrite   = l3b_check.rewrite_pdf,
        }
      }
    end,
  },
  test_order = {
    description = "Which kinds of tests to perform, keys of `test_types`",
    value_type  = "string[]",
    value       = { "log", "pdf" },
  },
  checkconfigs = {
    description = "Configurations to use for tests",
    value_type  = "string[]",
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
    value_type  = "string",
    index = function (env, k)
      return env.ctanpkg .. "-ctan"
    end,
  },
  epoch = {
    description = "Epoch (Unix date) to set for test runs",
    value_type  = "number",
    index = function (env, k)
      local options = l3build.options
      return options.epoch or env.epoch or 1463734800
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
    value_type  = "boolean",
    index = function (env, k)
      return env.flattentds -- by defaut flattentds and flattenscript are synonyms
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
    value_type  = "table",
    index =  function (env, k)
      return setmetatable({}, {
        __index = {
          pkg = env.ctanpkg,
        }
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
    value       = "NYI", -- l3b_inst.install_files,
  },
  manifest_setup = {
    description = "",
    value       = "NYI",
  },
  manifest_extract_filedesc = {
    description = "",
    value       = "NYI",
  },
  manifest_write_subheading = {
    description = "",
    value       = "NYI",
  },
  manifest_sort_within_match = {
    description = "",
    value       = "NYI",
  },
  manifest_sort_within_group = {
    description = "",
    value       = "NYI",
  },
  manifest_write_opening = {
    description = "",
    value       = "NYI",
  },
  manifest_write_group_heading = {
    description = "",
    value       = "NYI",
  },
  manifest_write_group_file_descr = {
    description = "",
    value       = "NYI",
  },
  manifest_write_group_file = {
    description = "",
    value       = "NYI",
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
    description = "Name of the CTAN package (defaults to env.ctanpkg)",
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
    value_type  = "function",
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
    value_type  = "function",
  },
  runtest_tasks = {
    description = "A hook to allow additional tasks to run for the tests",
    value       = runtest_tasks,
  },
})


--[==[ Package implementation ]==]

--[=====[ ]]
---@class _G_t
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
---@field public tds_main      string  @env.tdsroot / env.bundle or env.module

---@type G_t
local G


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

---@class main_variable_gmr_anchor_t
---@field public B_VARIABLE string
---@field public E_VARIABLE string
---@field public B_NAME     string
---@field public E_NAME     string
---@field public B_VALUE    string
---@field public E_VALUE    string

local short_module_dir = "."

-- default static values for variables

local function "NYI"()
  error("Missing implementation")
end

---@class pre_variable_entry_tX
---@field public description string
---@field public value       any
---@field public index       fun(self: VariableEntryX, env: table, k: string): any @ takes precedence over the value
---@field public complete    fun(self: VariableEntryX, env: table, k: string, v: any): any

---@class VariableEntryX: pre_variable_entry_tX
---@field public name           string
---@field public level          integer
---@field public type           string
---@field public vanilla_value  any

local VariableEntryX = Object:make_subclass("VariableEntryX")

function VariableEntryX.__:initialize(kv)
  self.name = name
end

---@type table<string,VariableEntryX>
local entry_by_name = {}
---@type VariableEntryX[]
local entry_by_index = {}

---Declare the given variable
---@param by_name table<string,pre_variable_entry_tX>
local function declare(by_name)
  for name, entry in pairs(by_name) do
    assert(not entry_by_name[name], "Duplicate declaration ".. tostring(name))
    entry = VariableEntryX(entry, name)
    entry_by_name[name] = entry
    push(entry_by_index, entry)
  end
end

---Get the variable entry for the given name.
---@param name string
---@return VariableEntryX
local function get_entry(name)
  return entry_by_name[name]
end

HERE

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
  if self.is_embedded then
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
    s = base_name(dir_name(_ENV.work)):lower()dir
    if not module then
      module = s
    elseif module ~= s then
      print(("Warning, module names are not consistent: %s and %s")
            :format(module, s))
    end
  else -- not an embeded module
    local modules = self.modules
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
function CT.exclmodules
    description = "_ENV.ctoriesdir to be excluded from automatic module detection",
    value       = {},
  },
function CT.modules
    description = "The list of all modules in a bundle (when not auto-detecting)",
    index function CT:=(k)
      local result = {}
      local excl_modules = self.exclmodules
      for name in all_names(_ENV.work)dir do
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
function CT.options
    index function CT:=(k)
      return l3build.options
    end,
  },
function CT.module
    description = "The name of the module",
    index function CT:=(k)
      guess_bundle_module(env)
      return rawget(self, k)
    end,
  },
function CT.bundle
    description = "The name of the bundle in which the module belongs (where relevant)",
    index function CT:=(k)
      guess_bundle_module(env)
      return rawget(self, k)
    end,
  },
function CT.ctanpkg
    description = "Name of the CTAN package matching this module",
    index function CT:=(k)
      return  self.is_standalone
          and self.module
          or (self.bundle / self.module)
    end,
  },
})
-- directory structure
declare({
function CT.tdsroot
    description = "Root directory of the TDS structure for the bundle/module to be installed into",
    value       = "latex",
  },
function CT.ctanupload
    description = "Only validation is attempted",
    value       = false,
  },
})
-- file globs
declare({
function CT.auxfiles
    description = "Secondary files to be saved as part of running tests",
    value       = { "*.aux", "*.lof", "*.lot", "*.toc" },
  },
function CT.bibfiles
    description = "BibTeX database files",
    value       = { "*.bib" },
  },
function CT.binaryfiles
    description = "Files to be added in binary mode to zip files",
    value       = { "*.pdf", "*.zip" },
  },
function CT.bstfiles
    description = "BibTeX style files to install",
    value       = { "*.bst" },
  },
function CT.checkfiles
    description = "Extra files unpacked purely for tests",
    value       = {},
  },
function CT.checksuppfiles
    description = "Files in the support directory needed for regression tests",
    value       = {},
  },
function CT.cleanfiles
    description = "Files to delete when cleaning",
    value       = { "*.log", "*.pdf", "*.zip" },
  },
function CT.demofiles
    description = "Demonstration files to use a module",
    value       = {},
  },
function CT.docfiles
    description = "Files which are part of the documentation but should not be typeset",
    value       = {},
  },
function CT.dynamicfiles
    description = "Secondary files to be cleared before each test is run",
    value       = {},
  },
function CT.excludefiles
    description = "Files to ignore entirely (default for Emacs backup files)",
    value       = { "*~" },
  },
function CT.installfiles
    description = "Files to install under the `tex` area of the `texmf` tree",
    value       = { "*.sty", "*.cls" },
  },
function CT.makeindexfiles
    description = "MakeIndex files to be included in a TDS-style zip",
    value       = { "*.ist" },
  },
function CT.scriptfiles
    description = "Files to install to the `scripts` area of the `texmf` tree",
    value       = {},
  },
function CT.scriptmanfiles
    description = "Files to install to the `doc/man` area of the `texmf` tree",
    value       = {},
  },
function CT.sourcefiles
    description = "Files to copy for unpacking",
    value       = { "*.dtx", "*.ins", "*-????-??-??.sty" },
  },
function CT.tagfiles
    description = "Files for automatic tagging",
    value       = { "*.dtx" },
  },
function CT.textfiles
    description = "Plain text files to send to CTAN as-is",
    value       = { "*.md", "*.txt" },
  },
function CT.typesetdemofiles
    description = "Files to typeset before the documentation for inclusion in main documentation files",
    value       = {},
  },
function CT.typesetfiles
    description = "Files to typeset for documentation",
    value       = { "*.dtx" },
  },
function CT.typesetsuppfiles
    description = "Files needed to support typesetting when sandboxed",
    value       = {},
  },
function CT.typesetsourcefiles
    description = "Files to copy to unpacking when typesetting",
    value       = {},
  },
function CT.unpackfiles
    description = "Files to run to perform unpacking",
    value       = { "*.ins" },
  },
function CT.unpacksuppfiles
    description = "Files needed to support unpacking when 'sandboxed'",
    value       = {},
  },
})
-- check
declare({
function CT.includetests
    description = "Test names to include when checking",
    value       = { "*" },
  },
function CT.excludetests
    description = "Test names to exclude when checking",
    value       = {},
  },
function CT.checkdeps
    description = "List of dependencies for running checks",
    value       = {},
  },
function CT.typesetdeps
    description = "List of dependencies for typesetting docs",
    value       = {},
  },
function CT.unpackdeps
    description = "List of dependencies for unpacking",
    value       = {},
  },
function CT.checkengines
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
function CT.stdengine
    description = "Engine to generate `.tlg` files",
    value       = "pdftex",
  },
function CT.checkformat
    description = "Format to use for tests",
    value       = "latex",
  },
function CT.specialformats
    description = "Non-standard engine/format combinations",
    value       = specialformats,
  },
function CT.test_types
    description = "Custom test variants",
    index function CT:=(k)
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
function CT.test_order
    description = "Which kinds of tests to perform, keys of `test_types`",
    value       = { "log", "pdf" },
  },
function CT.checkconfigs
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
function CT.typesetexe
    description = "Executable for running `doc`",
    value       = "pdflatex",
  },
function CT.unpackexe
    description = "Executable for running `unpack`",
    value       = "pdftex",
  },
function CT.zipexe
    description = "Executable for creating archive with `ctan`",
    value       = "zip",
  },
function CT.biberexe
    description = "Biber executable",
    value       = "biber",
  },
function CT.bibtexexe
    description = "BibTeX executable",
    value       = "bibtex8",
  },
function CT.makeindexexe
    description = "MakeIndex executable",
    value       = "makeindex",
  },
function CT.curlexe
    description = "Curl executable for `upload`",
    value       = "curl",
  },
})
-- CLI Options
declare({
function CT.checkopts
    description = "Options passed to engine when running checks",
    value       = "-interaction=nonstopmode",
  },
function CT.typesetopts
    description = "Options passed to engine when typesetting",
    value       = "-interaction=nonstopmode",
  },
function CT.unpackopts
    description = "Options passed to engine when unpacking",
    value       = "",
  },
function CT.zipopts
    description = "Options passed to zip program",
    value       = "-v -r -X",
  },
function CT.biberopts
    description = "Biber options",
    value       = "",
  },
function CT.bibtexopts
    description = "BibTeX options",
    value       = "-W",
  },
function CT.makeindexopts
    description = "MakeIndex options",
    value       = "",
  },
function CT.ps2pdfopt -- beware of the ending s (long term error)
    description = "ps2pdf options",
    value       = "",
  },
})

declare({
function CT.config
    value       = "",
  },
  curl_debug  = {
    value       = false,
  },
})


declare({
  -- Enable access to trees outside of the repo
  -- As these may be set false, a more elaborate test than normal is needed
function CT.typesetsearch
    description = "Switch to search the system `texmf` for during typesetting",
    value       = true,
  },
function CT.unpacksearch
    description = "Switch to search the system `texmf` for during unpacking",
    value       = true,
  },
function CT.checksearch
    description = "Switch to search the system `texmf` for during checking",
    value       = true,
  },
  -- Additional settings to fine-tune typesetting
function CT.glossarystyle
    description = "MakeIndex style file for glossary/changes creation",
    value       = "gglo.ist",
  },
function CT.indexstyle
    description = "MakeIndex style for index creation",
    value       = "gind.ist",
  },
function CT.specialtypesetting
    description = "Non-standard typesetting combinations",
    value       = {},
  },
function CT.forcecheckepoch
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
function CT.forcedocepoch
    description = "Force epoch when typesetting",
    value       = "false",
    complete = function (env, k, result)
      local options = l3build.options
      return (options.epoch or result) and true or false
    end,
  },
function CT.asciiengines
    description = "Engines which should log as pure ASCII",
    value       = { "pdftex" },
  },
function CT.checkruns
    description = "Number of runs to complete for a test before comparing the log",
    value       = 1,
  },
function CT.ctanreadme
    description = "Name of the file to send to CTAN as `README`.md",
    value       = "README.md",
  },
function CT.ctanzip
    description = "Name of the zip file (without extension) created for upload to CTAN",
    index function CT:=(k)
      return self.ctanpkg .. "-ctan"
    end,
  },
function CT.epoch
    description = "Epoch (Unix date) to set for test runs",
    index function CT:=(k)
      local options = l3build.options
      return options.epoch or rawget(_G, "epoch") or 1463734800
    end,
    complete = function (env, k, result)
      return normalise_epoch(result)
    end,
  },
function CT.flatten
    description = "Switch to flatten any source structure when sending to CTAN",
    value       = true,
  },
function CT.flattentds
    description = "Switch to flatten any source structure when creating a TDS structure",
    value       = true,
  },
function CT.flattenscript
    description = "Switch to flatten any script structure when creating a TDS structure",
    index function CT:=(k)
      return env.flattentds -- by defaut flattentds and flattenscript are synonyms
    end,
  },
function CT.maxprintline
    description = "Length of line to use in log files",
    value       = 79,
  },
function CT.packtdszip
    description = "Switch to build a TDS-style zip file for CTAN",
    value       = false,
  },
function CT.ps2pdfopts
    description = "Options for `ps2pdf`",
    value       = "",
  },
function CT.typesetcmds
    description = "Instructions to be passed to TeX when doing typesetting",
    value       = "",
  },
function CT.typesetruns
    description = "Number of cycles of typesetting to carry out",
    value       = 3,
  },
function CT.recordstatus
    description = "Switch to include error level from test runs in `.tlg` files",
    value       = false,
  },
function CT.manifestfile
    description = "File name to use for the manifest file",
    value       = "MANIFEST.md",
  },
function CT.tdslocations
    description = "For non-standard file installations",
    value       = {},
  },
function CT.uploadconfig
    value       = {},
    description = "Metadata to describe the package for CTAN",
    index =  function (self, k)
      return setmetatable({}, {
        __index = function (tt, kk)
          if kk == "pkg" then
            return self.ctanpkg
          end
        end
      })
    end,
  }
})
-- file extensions
declare({
})

declare({
function CT.abspath
    description = [[
Usage: `abspath("foo.bar")`
Returns "/absolute/path/to/foo.bar" on unix like systems
and "C:\absolute\path\to\foo.bar" on windows.
]],
    value       = fslib.absolute_path,
  },
function CT.dirname
    description = [[
Usage: `dirname("path/to/foo.bar")`
Returns "path/to".
]],
    value       = pathlib.dir_name,
  },
function CT.basename
    description = [[
Usage: `basename("path/to/foo.bar")`
Returns "foo.bar".
]],
    value       = pathlib.base_name,
  },
function CT.cleandir
    description = [[
Usage: `cleandir("path/to/dir")`
Removes any content in "path/to/dir" directory.
Returns 0 on success, a positive number on error.
]],
    value       = fslib.make_clean_directory,
  },
function CT.cp
    description = [[
Usage: `cp("*.bar", "path/to/source", "path/to/destination")`
Copies files matching the "*.bar" from "path/to/source" directory
to the "path/to/destination" directory.
Returns 0 on success, a positive number on error.
]],
    value       = fslib.copy_tree,
  },
function CT.direxists
    description = [[
`direxists("path/to/dir")`
Returns `true` if there is a directory at "path/to/dir",
`false` otherwise.
]],
    value       = fslib.directory_exists,
  },
function CT.fileexists
    description = [[
`fileexists("path/to/foo.bar")`
Returns `true` if there is a file at "path/to/foo.bar",
`false` otherwise.
]],
    value       = fslib.file_exists,
  },
function CT.filelist
    description = [[
`filelist("path/to/dir", "*.bar")
Returns a regular table of all the files within "path/to/dir"
which name matches "*.bar";
if no glob is provided, returns a list of
all files at "path/to/dir".
]],
    value       = fslib.file_list,
  },
function CT.glob_to_pattern
    description = [[
`glob_to_pattern("*.bar")`
Returns Lua pattern that corresponds to the glob "*.bar".
]],
    value       = pathlib.glob_to_pattern,
  },
function CT.path_matcher
    description = [[
`f = path_matcher("*.bar")`
Returns a function that returns true if its file name argument
matches "*.bar", false otherwise. Lua pattern that corresponds to the glob "*.bar".
In that example `f("foo.bar")` is true whereas `f("foo.baz")` is false.
]],
    value       = pathlib.path_matcher,
  },
function CT.jobname
    description = [[
`jobname("path/to/dir/foo.bar")`
Returns the argument with no extension and no parent directory path,
"foo" in the example. 
]],
    value       = pathlib.job_name,
  },
function CT.mkdir
    description = [[
`mkdir("path/to/dir")`
Create "path/to/dir" with all intermediate levels;
returns 0 on success, a positive number on error.
]],
    value       = fslib.make_directory,
  },
function CT.ren
    description = [[
`ren("foo.bar", "path/to/source", "path/to/destination")`
Renames "path/to/source/foo.bar" into "path/to/destination/foo.bar";
returns 0 on success, a positive number on error.
]],
    value       = fslib.rename,
  },
function CT.rm
    description = [[
`rm("path/to/dir", "*.bar")
Removes all files in "path/to/dir" matching "*.bar";
returns 0 on success, a positive number on error.
]],
    value       = fslib.remove_tree,
  },
function CT.run
    description = [[
`run(cmd, dir)`.
Executes `cmd`, from the `dir` directory;
returns an error level.
]],
    value       = oslib.run,
  },
function CT.splitpath
    description = [[
Returns two strings split at the last `/`: the `dirname(...)` and
the `basename(...)`.
]],
    value       = pathlib.dir_base,
  },
function CT.normalize_path
    description = [[
When called on Windows, returns a string comprising the `path` argument with
`/` characters replaced by `\\`. In other cases returns the path unchanged.
]],
    value       = fslib.to_host,
  },
function CT.call
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
function CT.install_files
    description = "",
    value       = "NYI", -- l3b_inst.install_files,
  },
function CT.manifest_setup
    description = "",
    value       = "NYI",
  },
function CT.manifest_extract_filedesc
    description = "",
    value       = "NYI",
  },
function CT.manifest_write_subheading
    description = "",
    value       = "NYI",
  },
function CT.manifest_sort_within_match
    description = "",
    value       = "NYI",
  },
function CT.manifest_sort_within_group
    description = "",
    value       = "NYI",
  },
function CT.manifest_write_opening
    description = "",
    value       = "NYI",
  },
function CT.manifest_write_group_heading
    description = "",
    value       = "NYI",
  },
function CT.manifest_write_group_file_descr
    description = "",
    value       = "NYI",
  },
function CT.manifest_write_group_file
    description = "",
    value       = "NYI",
  },
})

declare({
function CT.os_concat
    description = "The concatenation operation for using multiple commands in one system call",
    value       = OS.concat,
  },
function CT.os_null
    description = "The location to redirect commands which should produce no output at the terminal: almost always used preceded by `>`",
    value       = OS.null,
  },
function CT.os_pathsep
    description = "The separator used when setting an environment variable to multiple paths.",
    value       = OS.pathsep,
  },
function CT.os_setenv
    description = "The command to set an environmental variable.",
    value       = OS.setenv,
  },
function CT.os_yes
    description = "DEPRECATED.",
    value       = OS.yes,
  },
function CT.os_ascii
    -- description = "",
    value       = OS.ascii,
  },
function CT.os_cmpexe
    -- description = "",
    value       = OS.cmpexe,
  },
function CT:os_cmpext(k)
    -- description = "",
    value       = OS.cmpext,
  },
function CT.os_diffexe
    -- description = "",
    value       = OS.diffexe,
  },
function CT:os_diffext(k)
    -- description = "",
    value       = OS.diffext,
  },
function CT.os_grepexe
    -- description = "",
    value       = OS.grepexe,
  },
})
-- global fields
declare({
function CT.["uploadconfig.announcement"]
    description = "Announcement text",
  },
function CT.["uploadconfig.author"]
    description = "Author name (semicolon-separated for multiple)",
  },
function CT.["uploadconfig.ctanPath"]
    description = "CTAN path",
  },
function CT.["uploadconfig.email"]
    description = "Email address of uploader",
  },
function CT.["uploadconfig.license"]
    description = "Package license(s). See https://ctan.org/license",
  },
function CT.["uploadconfig.pkg"]
    description = "Name of the CTAN package (defaults to env.ctanpkg)",
  },
function CT.["uploadconfig.summary"]
    description = "One-line summary",
  },
function CT.["uploadconfig.uploader"]
    description = "Name of uploader",
  },
function CT.["uploadconfig.version"]
    description = "Package version",
  },
function CT.["uploadconfig.bugtracker"]
    description = "URL(s) of bug tracker",
  },
function CT.["uploadconfig.description"]
    description = "Short description/abstract",
  },
function CT.["uploadconfig.development"]
    description = "URL(s) of development channels",
  },
function CT.["uploadconfig.home"]
    description = "URL(s) of home page",
  },
function CT.["uploadconfig.note"]
    description = "Internal note to CTAN",
  },
function CT.["uploadconfig.repository"]
    description = "URL(s) of source repositories",
  },
function CT.["uploadconfig.support"]
    description = "URL(s) of support channels",
  },
function CT.["uploadconfig.topic"]
    description = "Topic(s), see https://ctan.org/topics/highscore",
  },
function CT.["uploadconfig.update"]
    description = "Boolean `true` for an update, `false` for a new package",
  },
function CT.["uploadconfig.announcement_file"]
    description = "Announcement text file",
  },
function CT.["uploadconfig.note_file"]
    description = "Note text file",
  },
function CT.["uploadconfig.curlopt_file"]
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
  if _ENV.texmfdir and _ENV.texmfdir ~= "" and directory_exists(_ENV.texmf)dir then
    local_texmf = OS.pathsep .. quoted_absolute_path(_ENV.texmf)dir .. "//"
  end
  local env_paths = "."
    .. local_texmf .. OS.pathsep
    .. quoted_absolute_path(_ENV.LOCAL])dir .. OS.pathsep
    .. dir .. (env.typesetsearch and OS.pathsep or "")
  -- Deal with spaces in paths
  if os_type == "windows" and env_paths:match(" ") then
    env_paths = first_of(env_paths:gsub('"', '')) -- no '"' in windows!!!
  end
  -- Allow for local texmf files
  local setenv_cmd = OS.setenv .. " TEXMFCNF=." .. OS.pathsep
  for var in entries(vars) do
    setenv_cmd = cmd_concat(setenv_cmd, OS.setenv .. " " .. var .. "=" .. env_paths)
  end
  print("set_epoch_cmd(env.epoch, env.forcedocepoch)", set_epoch_cmd(env.epoch, env.forcedocepoch))
  print(setenv_cmd)
  print(cmd)
  return run(dir, cmd_concat(set_epoch_cmd(env.epoch, env.forcedocepoch), setenv_cmd, cmd))
end

---biber
---@param name string
---@param dir string
---@return error_level_n
local function biber(name, dir)
  if file_exists(dir / name .. ".bcf") then
    return env.runcmd(
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
      return env.runcmd(
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
    return env.runcmd(
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
  return env.runcmd(cmd .. " \"" .. env.typesetcmds
    .. "\\input " .. file .. "\"",
    dir, { "TEXINPUTS", "LUAINPUTS" }) and 0 or 1
end

---typeset. Default command is the same as for `tex`.
---@param file string
---@param dir string
---@param cmd string|nil
---@return error_level_n
local function typeset(file, dir, cmd)
  local error_level = env.tex(file, dir, cmd)
  if is_error(error_level) then
    return error_level
  end
  local name = job_name(file)
  error_level = env.biber(name, dir) + env.bibtex(name, dir)
  if is_error(error_level) then
    return error_level
  end
  for i = 2, env.typesetruns do
    error_level = env.makeindex(name, dir, ".glo", ".gls", ".glg", env.glossarystyle)
                + env.makeindex(name, dir, ".idx", ".ind", ".ilg", env.indexstyle)
                + env.tex(file, dir, cmd)
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
function CT.biber
    description = [[
Runs Biber on file `name` (i.e a jobname lacking any extension)
inside the dir` folder. If there is no `.bcf` file then
no action is taken with a return value of `0`.
]],
    value       = biber,
  },
function CT.bibtex
    description = [[
Runs BibTeX on file `name` (i.e a jobname lacking any extension)
inside the `dir` folder. If there are no `\citation` lines in
the `.aux` file then no action is taken with a return value of `0`.
]],
    value       = bibtex,
  },
function CT.tex
    description = [[
Runs `cmd` (by default `typesetexe` `typesetopts`) on the
`name` inside the `dir` folder.
]],
    value       = tex,
  },
function CT.makeindex
    description = [[
Runs MakeIndex on file `name` (i.e a jobname lacking any extension)
inside the `dir` folder. The various extensions and the `style`
should normally be given as standard for MakeIndex.
]],
    value       = makeindex,
  },
function CT.runcmd
    description = [[
A generic function which runs the `cmd` in the `dir`, first
setting up all of the environmental variables specified to
point to the `local` and `working` directories. This function is useful
when creating non-standard typesetting steps.
]],
    value       = runcmd,
  },
function CT.typeset
    description = "",
    value       = typeset,
  },
function CT.typeset_demo_tasks
    description = "runs after copying files to the typesetting location but before the main typesetting run.",
    value       = typeset_demo_tasks,
  },
function CT.docinit_hook
    description = "A hook to initialize doc process",
    value       = docinit_hook,
  },
function CT.checkinit_hook
    description = "A hook to initialize check process",
    value       = checkinit_hook,
  },
function CT.tag_hook
    description = [[
Usage: `function tag_hook(tag_name, date)
  ...
end`
  To allow more complex tasks to take place, a hook `tag_hook()` is also
available. It will receive the tag name and date as arguments, and
may be used to carry out arbitrary tasks after all files have been updated.
For example, this can be used to set a version control tag for an entire repository.
]],
    index function CT:=(k)
      return require("l3build-tag").tag_hook
    end,
  },
function CT.update_tag
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
    index function CT:=(k)
      return require("l3build-tag").update_tag
    end,
  },
function CT.runtest_tasks
    description = "A hook to allow additional tasks to run for the tests",
    value       = runtest_tasks,
  },
})

---Computed global variables
---Used only when the eponym global variable is not set.
---@param env table
---@param k   string
---@return any
local G_index function CT:=(k)
  ---@type VariableEntryX
  local entry = get_entry(k)
  if entry then
    local result
    if entry.index then
      result = entry:index(k)
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
    return self.bundle == ""
  end
  if k == "at_top" then
    return l3build.main_dir == l3build.work_dir
  end
  if k == "at_bundle_top" then
    return self.at_top and not self.is_standalone
  end
  if k == "bundleunpack" then
    return require("l3build-unpack").bundleunpack
  end
  if k == "bundleunpackcmd" then
    return require("l3build-unpack").bundleunpackcmd
  end
  if k == "tds_main" then
    return self.is_standalone
      and self.tdsroot / self.module
      or  self.tdsroot / self.bundle
  end
  if k == "tds_module" then
    return self.is_standalone
      and self.module
      or  self.bundle / self.module
  end
end

env.= bridge({
  index    = G_index,
function CT.complete(env, k, result)
    local entry = get_entry(k)
    if entry and entry.complete then
      return entry.complete(env, k, result)
    end
    return result
  end,
function CT.newindex(env, k, v)
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

--[=====[
--]=====]

return ModEnv,
_ENV.during_unit_testing and
{ entry_by_name = entry_by_name, entry_by_index = entry_by_index}
