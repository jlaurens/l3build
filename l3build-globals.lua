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
In former implementation, quite all variables were global.
This design rendered code maintenance very delicate because:
- the same name was used for global variables and local ones
- variable definitions were spread over the code
- names were difficult to read

How things are organized:
1) low level packages do not use global variables at all.
2) High level packages only use bridges to some global variables.
3) Setting global variables is only made in either `build.lua` or a configuration file.

Global variables are used as static parameters to customize
the behaviour of `l3build`. Default values are defined before
various configuration files are loaded and executed.
For that, a metatable is added to `_G`.

--]=]

if type(module) == "function" then
  module = nil
end

local append  = table.insert
local os_time = os["time"]
local os_type = os["type"]

local status          = require("status")

local kpse        = require("kpse")
local set_program = kpse.set_program_name
local var_value   = kpse.var_value

---@type wklib_t
local wklib         = require("l3b-walklib")
local job_name  = wklib.job_name

---@type gblib_t
local gblib   = require("l3b-globlib")

---@type utlib_t
local utlib         = require("l3b-utillib")
local items         = utlib.items
local bridge        = utlib.bridge
local entries       = utlib.entries
local first_of      = utlib.first_of

---@type oslib_t
local oslib       = require("l3b-oslib")
local quoted_path = oslib.quoted_path
local OS          = oslib.OS
local cmd_concat  = oslib.cmd_concat
local run         = oslib.run

---@type fslib_t
local fslib             = require("l3b-fslib")
local directory_exists  = fslib.directory_exists
local file_exists       = fslib.file_exists
local all_names         = fslib.all_names
local absolute_path     = fslib.absolute_path

---@type l3build_t
local l3build = require("l3build")

---@type l3b_aux_t
local l3b_aux       = require("l3build-aux")
local set_epoch_cmd = l3b_aux.set_epoch_cmd

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

---@alias bundleunpack_f fun(source_dirs: string_list_t, sources: string_list_t): error_level_n

---@class l3b_upld_config_t
---@field announcement  string        Announcement text
---@field author        string        Author name (semicolon-separated for multiple)
---@field ctanPath      string        CTAN path
---@field email         string        Email address of uploader
---@field license       string|string_list_t Package license(s)\footnote{See \url{https://ctan.org/license}}
---@field pkg           string        Name of the CTAN package (defaults to G.ctanpkg)
---@field summary       string        One-line summary
---@field uploader      string        Name of uploader
---@field version       string        Package version
---@field bugtracker    string|string_list_t URL(s) of bug tracker
---@field description   string        Short description/abstract
---@field development   string|string_list_t URL(s) of development channels
---@field home          string|string_list_t URL(s) of home page
---@field note          string        Internal note to CTAN
---@field repository    string|string_list_t URL(s) of source repositories
---@field support       string|string_list_t URL(s) of support channels
---@field topic         string|string_list_t Topic(s)\footnote{See \url{https://ctan.org/topics/highscore}}
---@field update        string        Boolean \texttt{true} for an update, \texttt{false} for a new package
---@field announcement_file string    Announcement text  file
---@field note_file     string        Note text file
---@field curlopt_file  string        The filename containing the options passed to curl

---@class G_t
---@field module        string The name of the module
---@field bundle        string The name of the bundle in which the module belongs (where relevant)
---@field ctanpkg       string Name of the CTAN package matching this module
---@field modules       string_list_t The list of all modules in a bundle (when not auto-detecting)
---@field exclmodules   string_list_t Directories to be excluded from automatic module detection
---@field tdsroot       string
---@field ctanzip       string  Name of the zip file (without extension) created for upload to CTAN
---@field epoch         integer Epoch (Unix date) to set for test runs
---@field flattentds    boolean Switch to flatten any source structure when creating a TDS structure
---@field flattenscript boolean Switch to flatten any script structure when creating a TDS structure
---@field ctanreadme    string  Name of the file to send to CTAN as \texttt{README.\meta{ext}}s
---@field tdslocations  string_list_t For non-standard file installations
-- unexposed computed properties
---@field is_embedded   boolean True means the module belongs to a bundle
---@field is_standalone boolean False means the module belongs to a bundle
---@field at_bundle_top boolean True means we are at the top of the bundle
---@field config        string
---@field unique_config string|nil
-- doc related
---@field typesetsearch boolean Switch to search the system \texttt{texmf} for during typesetting
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
---@field checkengines    string_list_t Engines to check with \texttt{check} by default
---@field stdengine       string  Engine to generate \texttt{.tlg} file from
---@field checkformat     string  Format to use for tests
---@field specialformats  table  Non-standard engine/format combinations
---@field test_types      test_types_t  Custom test variants
---@field test_order      string_list_t Which kinds of tests to evaluate
-- Configs for testing
---@field checkconfigs    table   Configurations to use for tests
---@field includetests    string_list_t Test names to include when checking
---@field excludetests    string_list_t Test names to exclude when checking
---@field recordstatus    boolean Switch to include error level from test runs in \texttt{.tlg} files
---@field forcecheckepoch boolean Force epoch when running tests
---@field asciiengines    string_list_t Engines which should log as pure ASCII
---@field checkruns       integer Number of runs to complete for a test before comparing the log
---@field checksearch     boolean Switch to search the system \texttt{texmf} for during checking
---@field maxprintline    integer Length of line to use in log files
---@field runtest_tasks   fun(test_name: string, run_number: integer): string
---@field checkinit_hook  fun(): error_level_n
---@field ps2pdfopt       string  Options for \texttt{ps2pdf}
---@field unpacksearch    boolean  Switch to search the system \texttt{texmf} for during unpacking
---@field bundleunpack    bundleunpack_f  bundle unpack overwrite
---@field flatten         boolean Switch to flatten any source structure when sending to CTAN
---@field packtdszip      boolean Switch to build a TDS-style zip file for CTAN
---@field manifestfile    string File name to use for the manifest file
---@field curl_debug      boolean
---@field uploadconfig    l3b_upld_config_t Metadata to describe the package for CTAN (see Table~\ref{tab:upload-setup})
---@field texmf_home    string_list_t
---@field typeset_list  string_list_t

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
---@field local       string Directory for extracted files in \enquote{sandboxed} \TeX{} runs
---@field result      string Directory for PDF files when using PDF-based tests
---@field test        string Directory for running tests
---@field typeset     string Directory for building documentation
---@field unpack      string Directory for unpacking sources
---@field ctan        string Directory for organising files for CTAN
---@field tds         string Directory for organised files into TDS structure
---@field tds_module  string

---@type Dir_t
local Dir

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

---@type Files_t
local Files

---@class Deps_t
---@field check   string_list_t -- List of dependencies for running checks
---@field typeset string_list_t -- List of dependencies for typesetting docs
---@field unpack  string_list_t -- List of dependencies for unpacking

---@type Deps_t
local Deps = bridge({
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
---@field log string  Extension of checking output, before processing it into a \texttt{.tlg}
---@field pvt string  Extension of PDF-based test files
---@field pdf string  Extension of PDF file for checking and saving
---@field ps  string  Extension of PostScript files

---@type Xtn_t
local Xtn = bridge({
  suffix = "ext", -- Xtn.bak -> _G.bakext
})

local dot_dir = "."

-- default static values for variables

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

local function NYI()
  error("Missing implementation")
end

local defaults = {
  bundle          = "",
  module          = "",
  exclmodules     = {},
  tdsroot         = "latex",
  epoch           = 1463734800,
  flattentds      = true,
  ctanreadme      = "README.md",
  tdslocations    = {},
  -- dir suffix
  workdir       = dot_dir,
  currentdir    = dot_dir,
  docfiledir    = dot_dir,
  sourcefiledir = dot_dir,
  textfiledir   = dot_dir,
  -- files suffix
  auxfiles            = { "*.aux", "*.lof", "*.lot", "*.toc" },
  bibfiles            = { "*.bib" },
  binaryfiles         = { "*.pdf", "*.zip" },
  bstfiles            = { "*.bst" },
  checkfiles          = {},
  checksuppfiles      = {},
  cleanfiles          = { "*.log", "*.pdf", "*.zip" },
  demofiles           = {},
  docfiles            = {},
  dynamicfiles        = {},
  excludefiles        = { "*~" },
  installfiles        = { "*.sty", "*.cls" },
  makeindexfiles      = { "*.ist" },
  scriptfiles         = {},
  scriptmanfiles      = {},
  sourcefiles         = { "*.dtx", "*.ins", "*-????-??-??.sty" },
  tagfiles            = { "*.dtx" },
  textfiles           = { "*.md", "*.txt" },
  typesetdemofiles    = {},
  typesetfiles        = { "*.dtx" },
  typesetsuppfiles    = {},
  typesetsourcefiles  = {},
  unpackfiles         = { "*.ins" },
  unpacksuppfiles     = {},
  -- deps suffix
  checkdeps   = {},
  typesetdeps = {},
  unpackdeps  = {},
  -- exe suffix
  typesetexe    = "pdflatex",
  unpackexe     = "pdftex",
  zipexe        = "zip",
  biberexe      = "biber",
  bibtexexe     = "bibtex8",
  makeindexexe  = "makeindex",
  curlexe       = "curl",
  -- opts suffix
  checkopts     = "-interaction=nonstopmode",
  typesetopts   = "-interaction=nonstopmode",
  unpackopts    = "",
  zipopts       = "-v -r -X",
  biberopts     = "",
  bibtexopts    = "-W",
  makeindexopts = "",
  ps2pdfopts    = "",
  -- ext suffix
  bakext  = ".bak",
  dviext  = ".dvi",
  lvtext  = ".lvt",
  tlgext  = ".tlg",
  tpfext  = ".tpf",
  lveext  = ".lve",
  logext  = ".log",
  pvtext  = ".pvt",
  pdfext  = ".pdf",
  psext   = ".ps" ,
  -- functions
  abspath         = fslib.absolute_path,
  dirname         = wklib.dir_name,
  basename        = wklib.base_name,
  cleandir        = fslib.make_clean_directory,
  cp              = fslib.copy_tree,
  direxists       = fslib.directory_exists,
  fileexists      = fslib.file_exists,
  filelist        = fslib.file_list,
  glob_to_pattern = gblib.glob_to_pattern,
  to_glob_match   = gblib.to_glob_match,
  jobname         = wklib.job_name,
  mkdir           = fslib.make_directory,
  ren             = fslib.rename,
  rm              = fslib.remove_tree,
  run             = oslib.run,
  splitpath       = wklib.dir_name,
  normalize_path  = fslib.to_host,
  --#region
  typesetruns         = 3,
  typesetcmds         = "",
  -- Enable access to trees outside of the repo
  -- As these may be set false, a more elaborate test than normal is needed
  typesetsearch       = true,
  -- Additional settings to fine-tune typesetting
  glossarystyle       = "gglo.ist",
  indexstyle          = "gind.ist",
  specialtypesetting  = {},
  forcedocepoch       = false,
  --
  call          = l3b_aux.call,
  install_files = NYI, -- l3b_inst.install_files,
  -- check
  includetests  = { "*" },
  excludetests  = {},
  checkengines  = { "pdftex", "xetex", "luatex" },
  stdengine     = "pdftex",
  checkformat   = "latex",
  checkconfigs  = { "build" },
  config        = "",
  checksearch   = true,
  recordstatus  = false,
  forcecheckepoch = true,
  asciiengines  = { "pdftex" },
  checkruns     = 1,
  maxprintline  = 79,
  ps2pdfopt     = "",
  test_types = {
    log = {
      test        = Xtn.lvt,
      generated   = Xtn.log,
      reference   = Xtn.tlg,
      expectation = Xtn.lve,
      -- compare     = compare_tlg,
      -- rewrite     = rewrite_log,
    },
    pdf = {
      test      = Xtn.pvt,
      generated = Xtn.pdf,
      reference = Xtn.tpf,
      -- rewrite   = rewrite_pdf,
    },
  },
  test_order      = { "log", "pdf" },
  specialformats  = specialformats,
  -- Enable access to trees outside of the repo
  -- As these may be set false, a more elaborate test than normal is needed
  unpacksearch    = true,
  bundleunpack    = function () error("MISSING IMPLEMENTATION") end,
  flatten         = true, -- Is it used?
  packtdszip      = false,
  manifestfile    = "MANIFEST.md",
  manifest_setup                   = NYI,
  manifest_extract_filedesc        = NYI,
  manifest_write_subheading        = NYI,
  manifest_sort_within_match       = NYI,
  manifest_sort_within_group       = NYI,
  manifest_write_opening           = NYI,
  manifest_write_group_heading     = NYI,
  manifest_write_group_file_descr  = NYI,
  manifest_write_group_file        = NYI,
  curl_debug  = false,
  
}

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
  defaults["os_".. item] = from_item
end

local LOCAL = "local"

-- An auxiliary used to set up the environmental variables
---comment
---@param cmd   string
---@param dir?  string
---@param vars? table
---@return boolean?  suc
---@return exitcode? exitcode
---@return integer?  code
function defaults.runcmd(cmd, dir, vars)
  dir = dir or "."
  dir = absolute_path(dir)
  vars = vars or {}
  -- Allow for local texmf files
  local env = OS.setenv .. " TEXMFCNF=." .. OS.pathsep
  local local_texmf = ""
  if Dir.texmf and Dir.texmf ~= "" and directory_exists(Dir.texmf) then
    local_texmf = OS.pathsep .. absolute_path(Dir.texmf) .. "//"
  end
  local env_paths = "." .. local_texmf .. OS.pathsep
    .. absolute_path(Dir[LOCAL]) .. OS.pathsep
    .. dir .. (G.typesetsearch and OS.pathsep or "")
  -- Deal with spaces in paths
  if os_type == "windows" and env_paths:match(" ") then
    env_paths = first_of(env_paths:gsub('"', '')) -- no '"' in windows!!!
  end
  for var in entries(vars) do
    env = cmd_concat(env, OS.setenv .. " " .. var .. "=" .. env_paths)
  end
  return run(dir, cmd_concat(set_epoch_cmd(G.epoch, G.forcedocepoch), env, cmd))
end

---biber
---@param name string
---@param dir string
---@return error_level_n
function defaults.biber(name, dir)
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
function defaults.bibtex(name, dir)
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
function defaults.makeindex(name, dir, in_ext, out_ext, log_ext, style)
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
function defaults.tex(file, dir, cmd)
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
function defaults.typeset(file, dir, cmd)
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
function defaults.typeset_demo_tasks()
  return 0
end

---Do nothing function
---@return error_level_n
function defaults.docinit_hook()
  return 0
end

---Default function that can be overwritten
---@return error_level_n
function defaults.checkinit_hook()
  return 0
end

-- A hook to allow additional tasks to run for the tests
---comment
---@param test_name string
---@param run_number integer
---@return string
function defaults.runtest_tasks(test_name, run_number)
  return ""
end

-- computed global variables
local G_computed = function (t, k)
  if k == "ctanpkg" then
    return  G.is_standalone
        and G.module
        or  G.bundle .."/".. G.module
  end
  if k == "ctanzip" then
    return t.ctanpkg .. "-ctan"
  end
  if k == "modules" then -- dynamically create the module list
    local result = {}
    local excl_modules = t.exclmodules
    for entry in all_names(require("l3build-globals").Dir.work) do -- Dir is not yet defined
      if directory_exists(entry) and not excl_modules[entry] then
        if file_exists(entry .."/build.lua") then
          append(result, entry)
        end
      end
    end
    return result
  end
  if k == "epoch" then
    local options = l3build.options
    return options.epoch or _G["epoch"]
  end
  if k == "flattenscript" then
    return G.flattentds -- by defaut flattentds and flattenscript are synonyms
  end
  if k == "maindir" then
    return l3build.main_dir:sub(1, -1)
  end
  if k == "supportdir" then
    return t.maindir .. "/support"
  end
  if k == "testfiledir" then
    return dot_dir .. "/testfiles"
  end
  if k == "testsuppdir" then
    return t.testfiledir .. "/support"
  end
  if k == "texmfdir" then
    return t.maindir .. "/texmf"
  -- Structure within a development area
  end
  if k == "builddir" then
    return t.maindir .. "/build"
  end
  if k == "distribdir" then
    return t.builddir .. "/distrib"
  -- Substructure for CTAN release material
  end
  if k == "ctandir" then
    return t.distribdir .. "/ctan"
  end
  if k == "tdsdir" then
    return t.distribdir .. "/tds"
  end
  if k == "localdir" then
    return t.builddir .. "/local"
  end
  if k == "resultdir" then
    return t.builddir .. "/result"
  end
  if k == "testdir" then
    return t.builddir .. G.config .."/test"
  end
  if k == "typesetdir" then
    return t.builddir .. "/doc"
  end
  if k == "unpackdir" then
    return t.builddir .. "/unpacked"
  -- Location for installation on CTAN or in TEXMFHOME
  end
end

G = bridge({
  index = function (t, k)
    if k == "is_embedded" then
      return l3build.main_dir ~= l3build.work_dir
    end
    if k == "is_standalone" then
      return l3build.main_dir == l3build.work_dir
    end
    if k == "at_bundle_top" then
      return t.module == ""
    end
    if k == "uploadconfig" then
      return setmetatable({}, {
        __index = function (tt, kk)
          if kk == "pkg" then
            return G.ctanpkg
          end
        end
      })
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
  end,
  complete = function (t, k, result)
    if k == "epoch" then
      return normalise_epoch(result)
    end
    if k == "forcedocepoch" then
      local options = l3build.options
      return (options.epoch or result) and true or false
    end
    if k == "forcecheckepoch" then
      local options = l3build.options
      if options.epoch then
        return true
      end
    end
    if k == "unique_config" then
      local configs = t.checkconfigs
      if #configs == 1 then
        local cfg = configs[1]
        if cfg ~= "build" then
          return cfg
        end
      end
    end
    -- No trailing /
    -- What about the leading "./"
    local options = l3build.options
    if k == "checkconfigs" then
      -- When we have specific files to deal with, only use explicit configs
      -- (or just the std one)
      -- TODO: Justify this...
      if options.names then
        return options.config or { _G.stdconfig }
      else
        return options.config or result
      end
    end
    return result
  end,
})

Dir = bridge({
  suffix = "dir",
  index = function (t, k)
    if k == "tds_module" then
      return G.tdsroot
      .. (G.is_standalone and "/" .. G.bundle .. "/" or "/")
      .. G.module
    end
  end,
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

---Export globals in the metatable of the given table.
---@param G? table
local function export(G)
  G = G or _G
  local MT = getmetatable(G) or {}
  local __index = MT.__index
  local f_index = type(__index) == "function" and __index
  local t_index = type(__index) == "table"    and __index
  function MT.__index(t, k)
    local result
    if type(k) == "string" then
      result = defaults[k]
      if result ~= nil then
        return result
      end
      result = G_computed(t, k)
      if result ~= nil then
        return result
      end
      if t_index then
        result = t_index[k]
        if result ~= nil then
          return result
        end
      end
      if f_index then
        result = f_index(t, k)
        if result ~= nil then
          return result
        end
      end
    end
  end
  setmetatable(G, MT)
end

-- Roots which should be unpacked to support unpacking/testing/typesetting

---@class l3b_globals_t
---@field LOCAL     any
---@field G         G_t
---@field Dir       Dir_t
---@field Files     Files_t
---@field Deps      Deps_t
---@field Exe       Exe_t
---@field Opts      Opts_t
---@field Xtn       Xtn_t
---@field defaults  table

return {
  LOCAL           = LOCAL,
  export  = export,
  defaults        = defaults,
  G               = G,
  Dir             = Dir,
  Files           = Files,
  Deps            = Deps,
  Exe             = Exe,
  Opts            = Opts,
  Xtn             = Xtn,
}
