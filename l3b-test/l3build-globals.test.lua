#!/usr/bin/env texlua
--[[
  This is a test file for l3build package.
  It is only intending for development and should appear in any distribution of the l3build package.
  For help, run `texlua ../l3build.lua test -h`
--]]
local push  = table.insert
local pop   = table.remove

local expect = _ENV.expect

---@type l3b_globals_t
local l3b_globals
---@type __l3b_globals_t
local __

l3b_globals, __ = _ENV.loadlib("l3build-globals", _ENV)

local function test_basic()
  expect(l3b_globals).NOT(nil)
end

local test_VariableEntry = {
  setup = function (self)
    self.pre_entry_1 = {
      description = "PRE ENTRY 1",
      value = "PRE VALUE 1",
    }
    self.pre_entry_2 = {
      description = "PRE ENTRY 2",
      index = function (env, k)
        return "PRE INDEX 2(env, ".. k .. ")"
      end,
    }
    self.pre_entry_3 = {
      description = "PRE ENTRY 3",
      complete = function (env, k, result)
        return "PRE COMPLETE 3(env, ".. k .. ", ".. tostring(result) ..")"
      end,
      value = "PRE VALUE 3",
    }
    self.pre_entry_4 = {
      description = "PRE ENTRY 4",
      complete = function (env, k, result)
        return "PRE COMPLETE 4(env, ".. k .. ", ".. tostring(result) ..")"
      end,
      index = function (env, k)
        return "PRE INDEX 4(env, ".. k .. ")"
      end,
    }
    self:push_entries()
  end,
  push_entries = function (self)
    self.old_entry_by_index = {}
    table.move(__.entry_by_index, 1, #__.entry_by_index, 1, self.old_entry_by_index)
    self:clean_entries()
  end,
  clean_entries = function (self)
    while pop(__.entry_by_index) do end
    for k, _ in pairs(__.entry_by_name) do
      __.entry_by_name[k] = nil
    end
  end,
  pop_entries = function (self)
    self:clean_entries()
    local from_t = self.old_entry_by_index
    for _, v in ipairs(from_t) do
      __.entry_by_name[v.name] = v
    end
    table.move(from_t, 1, #from_t, 1, __.entry_by_index)
    self.old_entry_by_index = {}
  end,
  teardown = function (self)
    self:pop_entries()
  end,
  test = function (self)
    local entry_1 = __.VariableEntry(self.pre_entry_1, "entry_1")
    expect(entry_1.name).is("entry_1")
    expect(entry_1.description).is("PRE ENTRY 1")
    expect(entry_1.value).is("PRE VALUE 1")
  end,
  test_declare = function (self)
    __.declare({
      entry_1 = self.pre_entry_1,
      entry_2 = self.pre_entry_2,
      entry_3 = self.pre_entry_3,
      entry_4 = self.pre_entry_4,
    })
    local entry_1 = __.get_entry("entry_1")
    expect(entry_1.name).is("entry_1")
    local entry_2 = __.get_entry("entry_2")
    expect(entry_2.name).is("entry_2")
    local entry_3 = __.get_entry("entry_3")
    expect(entry_3.name).is("entry_3")
    local entry_4 = __.get_entry("entry_4")
    expect(entry_4.name).is("entry_4")
    local G = l3b_globals.G
    expect(G["entry_1"]).is("PRE VALUE 1")
    expect(G["entry_2"]).is("PRE INDEX 2(env, entry_2)")
    expect(G["entry_3"]).is("PRE COMPLETE 3(env, entry_3, PRE VALUE 3)")
    expect(G["entry_4"]).is("PRE COMPLETE 4(env, entry_4, PRE INDEX 4(env, entry_4))")
  end,
}

local test_Dir = function ()
  local Dir = l3b_globals.Dir
  local function test(key)
    local path = Dir[key]
    expect(path:match("/$")).is("/")
    local expected = tostring(math.random(999999))
    _G[key .."dir"] = expected
    expect(Dir[key]).is("./"..expected.."/")
    _G[key .."dir"] = nil
  end
  test("work")
  test("main")
  test("docfile")
  test("sourcefile")
  test("support")
  test("testfile")
  test("testsupp")
  test("texmf")
  test("textfile")
  test("build")
  test("distrib")
  test("local")
  test("result")
  test("test")
  test("typeset")
  test("unpack")
  test("ctan")
  test("tds")
end

local test_Files = function ()
  local Files = l3b_globals.Files
  local function test(key)
    expect(Files[key]).type("table")
    local expected = { tostring(math.random(999999)) }
    _G[key.."files"] = expected
    expect(Files[key]).equals(expected)
    _G[key.."files"] = nil
  end
  test("aux")
  test("bib")
  test("binary")
  test("bst")
  test("check")
  test("checksupp")
  test("clean")
  test("demo")
  test("doc")
  test("dynamic")
  test("exclude")
  test("install")
  test("makeindex")
  test("script")
  test("scriptman")
  test("source")
  test("tag")
  test("text")
  test("typesetdemo")
  test("typeset")
  test("typesetsupp")
  test("typesetsource")
  test("unpack")
  test("unpacksupp")
  test("_all_typeset")
  test("_all_pdf")
end

local test_Deps = function ()
  local Deps = l3b_globals.Deps
  local function test(key)
    expect(Deps[key]).type("table")
    local expected = { tostring(math.random(999999)) }
    _G[key.."deps"] = expected
    expect(Deps[key]).equals(expected)
    _G[key.."deps"] = nil
  end
  test("check")
  test("typeset")
  test("unpack")
end

local test_Exe = function ()
  local Exe = l3b_globals.Exe
  local function test(key)
    expect(Exe[key]).type("string")
    local expected = "X" .. tostring(math.random(999999))
    _G[key.."exe"] = expected
    expect(Exe[key]).equals(expected)
    _G[key.."exe"] = nil
  end
  test("typeset")
  test("unpack")
  test("zip")
  test("biber")
  test("bibtex")
  test("makeindex")
  test("curl")
end

local test_Opts = function ()
  local Opts = l3b_globals.Opts
  local function test(key)
    expect(Opts[key]).type("string")
    local expected = "X" .. tostring(math.random(999999))
    _G[key.."opts"] = expected
    expect(Opts[key]).equals(expected)
    _G[key.."opts"] = nil
  end
  test("check")
  test("typeset")
  test("unpack")
  test("zip")
  test("biber")
  test("bibtex")
  test("makeindex")
end

local test_Xtn = function ()
  local Xtn = l3b_globals.Xtn
  local function test(key)
    expect(Xtn[key]).type("string")
    local expected = "X" .. tostring(math.random(999999))
    _G[key.."ext"] = expected
    expect(Xtn[key]).equals(expected)
    _G[key.."ext"] = nil
  end
  test("bak")
  test("dvi")
  test("lvt")
  test("tlg")
  test("tpf")
  test("lve")
  test("log")
  test("pvt")
  test("pdf")
  test("ps")
end

local test_G = {
  setup = function (self)
    self.G = l3b_globals.G
  end,
  teardown = function (self)
    _G.module = nil
  end,
  test_bundle = function (self)
    _G.module = "MY SUPER MODULE"
    expect(self.G.bundle).is("")
  end,
  test_module = function (self)
    -- normally _G.module is read from a build.lua file
    _G.module = "MY SUPER MODULE"
    expect(self.G.module).is("MY SUPER MODULE")
  end,
  test_modules = function (self)
    expect(self.G.modules).equals({})
  end,
  test_checkengines = function (self)
    expect(self.G.checkengines).equals({"pdftex", "xetex", "luatex"})
    self.G.checkengines = nil -- values have ben cached
    local expected = { tostring( math.random(999999) ) }
    expect(_G.checkengines).is(nil)
    _G.checkengines = expected
    expect(self.G.checkengines).equals(expected)
    _G.checkengines = nil
  end,
  test_typeset_list = function (self)
    expect(function () print(self.G.typeset_list) end).error()
    _G.typeset_list = { "A", "B", "C" }
    expect(self.G.typeset_list).equals({ "A", "B", "C" })
    _G.typeset_list = nil
  end,
  test_str = function (self)
    local test = function (key)
      expect(self.G[key]).type("string")
      local expected = tostring( math.random(999999) )
      _G[key] = expected
      expect(self.G[key]).equals(expected)
      _G[key] = nil
    end
    _G.module = "MY SUPER MODULE"
    test('ctanpkg')
    test('tdsroot')
    test('ctanzip')
    test('ctanreadme')
    test('glossarystyle')
    test('indexstyle')
    test('typesetcmds')
    test('stdengine')
    test('checkformat')
    test('ps2pdfopt')
    test('manifestfile')
  end,
  test_boolean = function (self)
    local test = function (key)
      expect(self.G[key]).type("boolean")
      local expected = true
      _G[key] = expected
      expect(self.G[key]).equals(expected)
      expected = not expected
      _G[key] = expected
      expect(self.G[key]).equals(expected)
      _G[key] = nil
    end
    test('flattentds')
    test('flattenscript')
    test('ctanupload')
    test('typesetsearch')
    test('recordstatus')
    test('forcecheckepoch')
    test('checksearch')
    test('unpacksearch')
    test('flatten')
    test('packtdszip')
    test('curl_debug')
  end,
  test_number = function (self)
    local test = function (key)
      expect(self.G[key]).type("number")
      local expected = math.random(999999)
      _G[key] = expected
      expect(self.G[key]).equals(expected)
      _G[key] = nil
    end
    test('epoch')
    test('typesetruns')
    test('checkruns')
    test('maxprintline')
  end,
  test_function = function (self)
    local test = function (key)
      expect(self.G[key]).type("function")
      local expected = function () end
      _G[key] = expected
      expect(self.G[key]).equals(expected)
      _G[key] = nil
    end
    test("runcmd")
    test("biber")
    test("bibtex")
    test("makeindex")
    test("tex")
    test("typeset")
    test("typeset_demo_tasks")
    test("docinit_hook")
    test("runtest_tasks")
    test("checkinit_hook")
    test("bundleunpack")
    test("tag_hook")
    test("update_tag")
  end,
  test_table = function (self)
    local test = function (key)
      expect(self.G[key]).type("table")
      local expected = { tostring( math.random(999999) ) }
      _G[key] = expected
      expect(self.G[key]).equals(expected)
      _G[key] = nil
    end
    test('exclmodules')
    test('tdslocations')
    test('test_order')
    test('includetests')
    test('excludetests')
    test('asciiengines')
    test("specialtypesetting")
    test('specialformats')
    test('test_types')
    test('checkconfigs')
    test('uploadconfig')
  end,
}

local test__G = {
  setup = function (self)
    self.G = l3b_globals.G
  end,
  teardown = function (self)
    _G.module = nil
  end,
  test_texmf_home = function (self)
    expect(self.G.texmf_home:match("texmf")).is("texmf")
    require("l3build").options.texmfhome = "FOO"
    expect(self.G.texmf_home).is("FOO")
  end,
  test_is = function (self)
    _G.module = "MY SUPER MODULE"
    expect(self.G.is_embedded).type("boolean")
    expect(self.G.is_standalone).type("boolean")
    expect(self.G.at_bundle_top).type("boolean")
  end,
  test_at_top = function (self)
    expect(self.G.at_top).type("boolean")
  end,
  test_str = function (self)
    local function test(key)
      expect(self.G[key]).type("string")
      local expected = "X" .. tostring(math.random(999999))
      _G[key] = expected
      expect(self.G[key]).equals(expected)
      _G[key] = nil
    end
    test("config")
    _G.module = "MY SUPER MODULE"
    test("tds_module")
    test("tds_main")
  end,
}

return {
  test_basic          = test_basic,
  test_VariableEntry  = test_VariableEntry,
  test_Dir            = test_Dir,
  test_Files          = test_Files,
  test_Deps           = test_Deps,
  test_Exe            = test_Exe,
  test_Opts           = test_Opts,
  test_Xtn            = test_Xtn,
  test_G              = test_G,
  test__G             = test__G,
}

--[=====[

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
---@field public is_embedded   boolean @True means the module belongs to a bundle
---@field public is_standalone boolean @False means the module belongs to a bundle
---@field public at_top        boolean @True means there is no bundle above
---@field public at_bundle_top boolean @True means we are at the top of the bundle
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
local Deps = bridge({
  suffix = "deps",
})

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
local Exe = bridge({
  suffix = "exe",
})

---@class Opts_t
---@field public check     string @Options passed to engine when running checks
---@field public typeset   string @Options passed to engine when typesetting
---@field public unpack    string @Options passed to engine when unpacking
---@field public zip       string @Options passed to zip program
---@field public biber     string @Biber options
---@field public bibtex    string @BibTeX options
---@field public makeindex string @MakeIndex options

---@type Opts_t
local Opts = bridge({
  suffix = "opts"
})

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
  local command = to_quoted_string({
    "texlua",
    quoted_path(l3build.script_path),
    "status",
    "--".. l3b_cli.GET_MAIN_VARIABLE,
    name,
  })
  local ok, packed = push_pop_current_directory(
    l3build.main_dir,
    function (cmd)
      local result = read_command(cmd)
      print("t", result)
      return result
    end,
    command
  )
  print("t", packed[1])
  print("l3build.main_dir", l3build.main_dir)
  print("Dir.main" , Dir.main)
  print("build.lua", read_content(l3build.main_dir .."build.lua"))
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
  local f, msg = loadfile(l3build.work_dir .. "build.lua")
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
---@field public name        string
---@field public description string
---@field public value       any
---@field public index       fun(t: table, k: string): any takes precedence over the value
---@field public complete    fun(t: table, k: string, v: any): any

---@class VariableEntry: pre_variable_entry_t
---@field public get_vanilla_value fun(self: VariableEntry): any
---@field public get_level         fun(self: VariableEntry): integer
---@field public get_type          fun(self: VariableEntry): string

---@type table<string,VariableEntry>
local entry_by_name = {}
---@type VariableEntry[]
local entry_by_index = {}

-- All variable entries share the same metatable
local MT_variable_entry = {}
MT_variable_entry.__index = MT_variable_entry

---Declare the given variable
---@param by_name table<string,pre_variable_entry_t>
local function declare(by_name)
  for name, entry in pairs(by_name) do
    assert(not entry_by_name[name], "Duplicate declaration ".. tostring(name))
    entry.name = name
    entry_by_name[name] = entry
    push(entry_by_index, entry)
    setmetatable(entry, MT_variable_entry)
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
  if G.is_embedded then
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
    s = Dir.work:match("([^/]+)/$"):lower()
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
  rawset(env, "bundle", bundle)
  rawset(env, "module", module)
end

declare({
  module = {
    description = "The name of the module",
    index = function (t, k)
      guess_bundle_module(t)
      return rawget(t, k)
    end,
  },
  bundle = {
    description = "The name of the bundle in which the module belongs (where relevant)",
    index = function (t, k)
      guess_bundle_module(t)
      return rawget(t, k)
    end,
  },
  ctanpkg = {
    description = "Name of the CTAN package matching this module",
    index = function (t, k)
      return  t.is_standalone
          and t.module
          or (t.bundle / t.module)
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
            push(result, name)
          end
        end
      end
      rawset(t, k, result)
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
    description = "Directory for extracted files in 'sandboxed' TeX runs",
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
  workdir = {
    description = "Working directory",
    index = function (t, k)
      return l3build.work_dir:gsub(1, -2) -- no trailing "/"
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
    description = "BibTeX database files",
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
    description = "Files to install to the `scripts` area of the `texmf` tree",
    value = {},
  },
  scriptmanfiles = {
    description = "Files to install to the `doc/man` area of the `texmf` tree",
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
    description = "Files needed to support unpacking when 'sandboxed'",
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
    description = "Engines to check with `check` by default",
    value = { "pdftex", "xetex", "luatex" },
    complete = function (t, k, result)
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
      rawset(t, k, result)
      return result
    end,
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
    description = "Name of the file to send to CTAN as `README`.md",
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
      return options.epoch or rawget(_G, "epoch") or 1463734800
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
    description = "Metadata to describe the package for CTAN",
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
    description = "Extension of checking output, before processing it into a `.tlg`",
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
    value = pathlib.dir_name,
  },
  basename = {
    description =
[[Usage: `basename("path/to/foo.bar")`
Returns "foo.bar".
]],
    value = pathlib.base_name,
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
  path_matcher = {
    description = 
[[`f = path_matcher("*.bar")`
Returns a function that returns true if its file name argument
matches "*.bar", false otherwise.Lua pattern that corresponds to the glob "*.bar".
In that example `f("foo.bar") == true` whereas `f("foo.baz") == false`.
]],
    value = gblib.path_matcher,
  },
  jobname = {
    description =
[[`jobname("path/to/dir/foo.bar")`
Returns the argument with no extension and no parent directory path,
"foo" in the example. 
]],
    value = pathlib.job_name,
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
    value = pathlib.dir_base,
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
---@param vars? table
---@return boolean?  @suc
---@return exitcode? @exitcode
---@return integer?  @code
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
    ---@type VariableEntry
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
  ---@type VariableEntry
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
      and t.tdsroot / t.module
      or  t.tdsroot / t.bundle
  end
  if k == "tds_module" then
    return t.is_standalone
      and t.module
      or  t.bundle / t.module
  end
end

G = bridge({
  index     = G_index,
  complete = function (t, k, result)
    local entry = get_entry(k)
    if entry and entry.complete then
      return entry.complete(t, k, result)
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
  local f_index = type(__index) == "function" and __index
  local t_index = type(__index) == "table"    and __index
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
      -- fall back to the static value
      return entry.value
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

local VANILLA_VALUE = {}
---Get the value of the receiver in the vanilla environment
---@return any
function MT_variable_entry:get_vanilla_value()
  if self[VANILLA_VALUE] == nil then
    self[VANILLA_VALUE] = get_vanilla()[self.name]
  end
  return self[VANILLA_VALUE]
end

local TYPE = {}
---Get the level of the receiver
---@param self VariableEntry
---@return integer
function MT_variable_entry.get_type(self)
  if self[TYPE] == nil then
    self[TYPE] = type(self:get_vanilla_value())
  end
  return self[TYPE]
end

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

local LEVEL = {}
---Get the level of the receiver
---@param self VariableEntry
---@return integer
function MT_variable_entry.get_level(self)
  if self[LEVEL] == nil then
    self[LEVEL] = level_by_type[self.type]
  end
  return self[LEVEL]
end

---metamethod to compare 2 variable entries
---@param lhs VariableEntry
---@param rhs VariableEntry
---@return boolean
function MT_variable_entry.__lt(lhs, rhs)
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
---@field public LOCAL     any
---@field public G         G_t
---@field public Dir       Dir_t
---@field public Files     Files_t
---@field public Deps      Deps_t
---@field public Exe       Exe_t
---@field public Opts      Opts_t
---@field public Xtn       Xtn_t
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
}
]=====]