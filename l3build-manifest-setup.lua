--[[

File l3build-manifest-setup.lua Copyright (C) 2028-2020 The LaTeX Project

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


--[[
      L3BUILD MANIFEST SETUP
      ======================
      This file contains all of the code that is easily replaceable by the user.
      Either create a copy of this file, rename, and include alongside your `build.lua`
      script and load it with `dofile()`, or simply copy/paste the definitions below
      into your `build.lua` script directly.
--]]


--[[
      Setup of manifest "groups"
      --------------------------

      The grouping of manifest files is broken into three subheadings:

      * The development repository
      * The TDS structure from `ctan`
      * The CTAN structure from `ctan`

      The latter two will only be produced if the `manifest` target is run *after*
      the `ctan` target. Contrarily, if you run `clean` before `manifest` then
      only the first grouping will be printed.

      If you want to omit the files in the development repository, essentially
      producing a minimalist manifest with only the files included for distribution,
      make a copy of the `setup` function and delete the groups under
      the ‘Repository manifest’ subheading below.
--]]

-- TODO: remove this counter productive file handle

local sort = table.sort

---@type Object
local Object = require("l3b-object")

---@type l3build_t
local l3build = require("l3build")

---@class MnfstGroup @ The metadata about each `group' in the manifest listing
local MnfstGroup = Object:make_subclass("MnfstGroup")

---@class MnfstGroupFiles: MnfstGroup  @ The metadata about each `group' in the manifest listing
---@field public name                string @ The heading of the group
---@field public description         string @ The description printed below the heading
---@field public dir                 string @ The directory to search (default |maindir|)
---@field public exclude             string[]|string[][] @ env.tofiles exclude (default |{excludefiles}|)
---@field public files               string[]|string[][] @ env.tofiles include in this group
---@field public rename              string[] @ An array with a `gsub` redefinition for the filename
---@field public skipfiledescription boolean @ Whether to extract file descriptions from these files (default `false`)
local MnfstGroupFiles = MnfstGroup:make_subclass("MnfstGroupFiles")

---@class MnfstGroupSubheading: MnfstGroup @ The metadata about each `subheading' in the manifest listing
---@field public description         string @ The description printed below the subheading
---@field public subheading          string @ The subheading
local MnfstGroupSubheading = MnfstGroup:make_subclass("MnfstGroupSubheading")

---@class FOOO
---@field public flag                boolean
---@field public N                   integer @matched files
---@field public ND                  integer @descriptions
---@field public matches             table
---@field public excludes            table
---@field public files_ordered       table
---@field public descr               table
---@field public Nchar_file          integer
---@field public Nchar_descr         integer

---comment
---@return MnfstGroup[]
local function manifest_setup()
  ---@type ModEnv
  local mod_env = l3build.module.env
  local groups = {
    {
      subheading = "Repository manifest",
      description = [[
The following groups list the files included in the development repository of the package.
env.listedfiles with a ‘†’ marker are included in the TDS but not CTAN files, and files listed
with ‘‡’ are included in both.
]],
    },
    {
      name    = "Source files",
      description = [[
These are source files for a number of purposes, including the `unpack` process which
generates the installation files of the package. Additional files included here will also
be installed for processing such as testing.
]],
      files   = { mod_env.sourcefiles },
      dir     = mod_env.sourcefiledir or mod_env.maindir, -- TODO: remove "or env.maindir" after rebasing onto master
    },
    {
      name    = "Typeset documentation source files",
      description = [[
These files are typeset using LaTeX to produce the PDF documentation for the package.
]],
      files   = { mod_env.typesetfiles, mod_env.typesetsourcefiles, mod_env.typesetdemofiles },
    },
    {
      name    = "Documentation files",
      description = [[
These files form part of the documentation but are not typeset. Generally they will be
additional input files for the typeset documentation files listed above.
]],
      files   = { mod_env.docfiles },
      dir     = mod_env.docfiledir or mod_env.maindir, -- TODO: remove "or env.maindir" after rebasing onto master
    },
    {
      name    = "Text files",
      description = [[
Plain text files included as documentation or metadata.
]],
      files   = { mod_env.textfiles },
      skipfiledescription = true,
    },
    {
      name    = "Demo files",
      description = [[
env.includedfiles to demonstrate package functionality. These files are *not*
typeset or compiled in any way.
]],
      files   = { mod_env.demofiles },
    },
    {
      name    = "Bibliography and index files",
      description = [[
Supplementary files used for compiling package documentation.
]],
      files   = { mod_env.bibfiles, mod_env.bstfiles, mod_env.makeindexfiles },
    },
    {
      name    = "Derived files",
      description = [[
The files created by ‘unpacking’ the package sources. This typically includes
`.sty` and `.cls` files created from DocStrip `.dtx` files.
]],
      files   = { mod_env.installfiles },
      exclude = { mod_env.excludefiles, mod_env.sourcefiles },
      dir     = mod_env.unpackdir,
      skipfiledescription = true,
    },
    {
      name    = "Typeset documents",
      description = [[
The output files (PDF, essentially) from typesetting the various source, demo,
etc., package files.
]],
      files   = { mod_env.typesetfiles,mod_env.typesetsourcefiles,mod_env.typesetdemofiles },
      rename  = { "%.%w+$", ".pdf" },
      skipfiledescription = true,
    },
    {
      name    = "Support files",
      description = [[
These files are used for unpacking, typesetting, or checking purposes.
]],
      files   = { mod_env.unpacksuppfiles,mod_env.typesetsuppfiles,mod_env.checksuppfiles },
      dir     = mod_env.supportdir,
    },
    {
      name    = "Checking-specific support files",
      description = [[
Support files for checking the test suite.
]],
      files   = { "*.*" },
      exclude = { { ".", ".." }, mod_env.excludefiles },
      dir     = mod_env.testsuppdir,
    },
    {
      name    = "Test files",
      description = [[
These files form the test suite for the package. `.lvt` or `.lte` files are the individual
unit tests, and `.tlg` are the stored output for ensuring changes to the package produce
the same output. These output files are sometimes shared and sometime specific for
different engines (pdfTeX, XeTeX, LuaTeX, etc.).
]],
      files   = { "*"..mod_env.lvtext, "*"..mod_env.lveext, "*"..mod_env.tlgext },
      dir     = mod_env.testfiledir,
      skipfiledescription = true,
    },
    {
      subheading = "TDS manifest",
      description = [[
The following groups list the files included in the TeX env.ctorydir Structure used to install
the package into a TeX distribution.
]],
    },
    {
      name    = "Source files (TDS)",
      description = "All files included in the `"..mod_env.tds_module.."/source` directory.\n",
      dir     = mod_env.tdsdir.."/source/"..mod_env.tds_module,
      files   = { "*.*" },
      exclude = { ".", ".." },
      flag    = false,
      skipfiledescription = true,
    },
    {
      name    = "TeX files (TDS)",
      description = "All files included in the `"..mod_env.tds_module.."/tex` directory.\n",
      dir     = mod_env.tdsdir.."/tex/"..mod_env.tds_module,
      files   = { "*.*" },
      exclude = { ".", ".." },
      flag    = false,
      skipfiledescription = true,
    },
    {
      name    = "Doc files (TDS)",
      description = "All files included in the `"..mod_env.tds_module/"doc` directory.\n",
      dir     = mod_env.tdsdir/"doc"/mod_env.tds_module,
      files   = { "*.*" },
      exclude = { ".", ".." },
      flag    = false,
      skipfiledescription = true,
    },
    {
      subheading = "CTAN manifest",
      description = [[
The following group lists the files included in the CTAN package.
]],
    },
    {
      name    = "CTAN files",
      dir     = mod_env.ctandir/mod_env.tds_module,
      files   = { "*.*" },
      exclude = { ".", ".." },
      flag    = false,
      skipfiledescription = true,
    },
  }
  return groups
end

---Sort
---@param files string[]
---@return string[]
local function sort_within_match(files)
  sort(files)
  return files
end

---Sort
---@param files string[]
---@return string[]
local function sort_within_group(files)
  --[[
      -- no-op by default; make your own definition to customise. E.g.:
      table.sort(files)
  --]]
  return files
end

local function write_opening(fh)
  fh:write("# Manifest for " .. module .. "\n\n")
  fh:write([[
This file is a listing of all files considered to be part of this package.
It is automatically generated with `texlua build.lua manifest`.
]])
end

---Write subheading
---@param fh table @file handle
---@param heading string
---@param description string
local function write_heading(fh, heading, description)
  fh:write("\n\n## " .. heading .. "\n\n")
  if description then
    fh:write(description)
  end
end

---@class manifest_kv
---@field public dir          string    @the directory of the file
---@field public count        integer   @the count of the filename to be written
---@field public filemaxchar  integer   @the maximum number of chars of all filenames in this group
---@field public descmaxchar  integer   @the maximum number of chars of all descriptions in this group
---@field public flag         boolean|string  @false OR string for indicating CTAN/TDS location
---@field public ctanfile     boolean   @if file is in CTAN dir
---@field public tdsfile      boolean   @if file is in TDS dir

---comment
---@param fh       table @write file handle
---@param filename string @the name of the file to write
---@param kv       manifest_kv
local function write_group_file(fh, filename, kv)
  -- no file description: plain bullet list item:
  local flagstr = kv.flag or  ""
  fh:write("* " .. filename .. " " .. flagstr .. "\n")
  --[[
    -- or if you prefer an enumerated list:
    fh:write(param.count..". " .. filename .. "\n")
  --]]
end

---comment
---@param fh table @write file handle
---@param filename   string @the name of the file to write
---@param descr string @description of the file to write
---@param param manifest_kv
local function write_group_file_descr(fh, filename, descr, param)
  -- filename+description: Github-flavoured Markdown table
  local filestr = string.format(" | %-"..param.filemaxchar.."s", filename)
  local flagstr = param.flag and string.format(" | %s", param.flag) or  ""
  local descstr = string.format(" | %-"..param.descmaxchar.."s", descr)
  fh:write(filestr..flagstr..descstr.." |\n")
end

--[[
      Extracting ‘descriptions’ from source files
      -------------------------------------------
--]]

---@alias manifest_extract_filedesc_f  fun(fh: table, file_name: string)
---@alias manifest_setup_f             fun(fh: table, file_name: string)
---@alias manifest_sort_within_group_f fun(fh: table, file_name: string)
---@alias manifest_sort_within_match_f fun(fh: table, file_name: string)
---@alias manifest_write_group_file_f  fun(fh: table, file_name: string)
---@alias manifest_write_group_file_descr_f  fun(fh: table, file_name: string)
---@alias manifest_write_group_heading_f     fun(fh: table, file_name: string)
---@alias manifest_write_opening_f     fun(fh: table, file_name: string)
---@alias manifest_write_subheading_f  fun(fh: table, file_name: string)
---@alias manifestfile_f               fun(fh: table, file_name: string)

---Extract file description
---@param fh table @file handle
local function extract_filedesc(fh)

  -- no-op by default; two examples below

end

--[[

-- From the first match of a pattern in a file:
manifest_extract_filedesc = function(filehandle)

  local all_file = filehandle:read("a")
  local matchstr = "\\section{(.-)}"

  filedesc = string.match(all_file,matchstr)

  return filedesc
end

-- From the match of the 2nd line (say) of a file:
manifest_extract_filedesc = function(filehandle)

  local end_read_loop = 2
  local matchstr      = "%%%S%s+(.*)"
  local this_line     = ""

  for ii = 1, end_read_loop do
    this_line = filehandle:read("*line")
  end

  filedesc = string.match(this_line,matchstr)

  return filedesc
end

]]--

---@class l3b_mfst_setup_t
---@field public setup function
---@field public sort_within_match function
---@field public sort_within_group function
---@field public write_opening function
---@field public write_heading function
---@field public write_group_file function
---@field public write_group_file_descr function
---@field public extract_filedesc function

return {
  setup              = manifest_setup,
  sort_within_match  = sort_within_match,
  sort_within_group  = sort_within_group,
  write_opening      = write_opening,
  write_heading      = write_heading,
  write_group_file   = write_group_file,
  write_group_file_descr = write_group_file_descr,
  extract_filedesc   = extract_filedesc,
}
