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

local sort = table.sort

---@class manifest_entry_t
---@field subheading          string
---@field name                string
---@field description         string
---@field files               string_list_t|table<integer, string_list_t>
---@field dir                 string
---@field skipfiledescription boolean
---@field exclude             string_list_t|table<integer, string_list_t>
---@field rename              string_list_t
---@field flag                boolean
---@field N                   integer matched files
---@field ND                  integer descriptions
---@field matches             table
---@field excludes            table
---@field files_ordered       table
---@field descr               table
---@field Nchar_file          integer
---@field Nchar_descr         integer

---comment
---@return table<integer, manifest_entry_t>
local function setup()
  local groups = {
    {
       subheading = "Repository manifest",
       description = [[
The following groups list the files included in the development repository of the package.
Files listed with a ‘†’ marker are included in the TDS but not CTAN files, and files listed
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
       files   = { sourcefiles },
       dir     = sourcefiledir or maindir, -- TODO: remove "or maindir" after rebasing onto master
    },
    {
       name    = "Typeset documentation source files",
       description = [[
These files are typeset using LaTeX to produce the PDF documentation for the package.
]],
       files   = { typesetfiles,typesetsourcefiles,typesetdemofiles },
    },
    {
       name    = "Documentation files",
       description = [[
These files form part of the documentation but are not typeset. Generally they will be
additional input files for the typeset documentation files listed above.
]],
       files   = { docfiles },
       dir     = docfiledir or maindir, -- TODO: remove "or maindir" after rebasing onto master
    },
    {
       name    = "Text files",
       description = [[
Plain text files included as documentation or metadata.
]],
       files   = { textfiles },
       skipfiledescription = true,
    },
    {
       name    = "Demo files",
       description = [[
Files included to demonstrate package functionality. These files are *not*
typeset or compiled in any way.
]],
       files   = { demofiles },
    },
    {
       name    = "Bibliography and index files",
       description = [[
Supplementary files used for compiling package documentation.
]],
       files   = { bibfiles,bstfiles,makeindexfiles },
    },
    {
       name    = "Derived files",
       description = [[
The files created by ‘unpacking’ the package sources. This typically includes
`.sty` and `.cls` files created from DocStrip `.dtx` files.
]],
       files   = { installfiles },
       exclude = { excludefiles, sourcefiles },
       dir     = unpackdir,
       skipfiledescription = true,
    },
    {
       name    = "Typeset documents",
       description = [[
The output files (PDF, essentially) from typesetting the various source, demo,
etc., package files.
]],
       files   = { typesetfiles,typesetsourcefiles,typesetdemofiles },
       rename  = { "%.%w+$", ".pdf" },
       skipfiledescription = true,
    },
    {
       name    = "Support files",
       description = [[
These files are used for unpacking, typesetting, or checking purposes.
]],
       files   = { unpacksuppfiles,typesetsuppfiles,checksuppfiles },
       dir     = supportdir,
    },
    {
       name    = "Checking-specific support files",
       description = [[
Support files for checking the test suite.
]],
       files   = { "*.*" },
       exclude = { { ".", ".." }, excludefiles },
       dir     = testsuppdir,
    },
    {
       name    = "Test files",
       description = [[
These files form the test suite for the package. `.lvt` or `.lte` files are the individual
unit tests, and `.tlg` are the stored output for ensuring changes to the package produce
the same output. These output files are sometimes shared and sometime specific for
different engines (pdfTeX, XeTeX, LuaTeX, etc.).
]],
       files   = { "*"..lvtext, "*"..lveext, "*"..tlgext },
       dir     = testfiledir,
       skipfiledescription = true,
    },
    {
       subheading = "TDS manifest",
       description = [[
The following groups list the files included in the TeX Directory Structure used to install
the package into a TeX distribution.
]],
    },
    {
       name    = "Source files (TDS)",
       description = "All files included in the `"..module.."/source` directory.\n",
       dir     = tdsdir.."/source/"..moduledir,
       files   = { "*.*" },
       exclude = { ".", ".." },
       flag    = false,
       skipfiledescription = true,
    },
    {
       name    = "TeX files (TDS)",
       description = "All files included in the `"..module.."/tex` directory.\n",
       dir     = tdsdir.."/tex/"..moduledir,
       files   = { "*.*" },
       exclude = { ".",".." },
       flag    = false,
       skipfiledescription = true,
    },
    {
       name    = "Doc files (TDS)",
       description = "All files included in the `"..module.."/doc` directory.\n",
       dir     = tdsdir.."/doc/"..moduledir,
       files   = { "*.*" },
       exclude = { ".",".." },
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
       dir     = ctandir.."/"..module,
       files   = { "*.*" },
       exclude = { ".", ".." },
       flag    = false,
       skipfiledescription = true,
    },
  }
  return groups
end

---Sort
---@param files string_list_t
---@return string_list_t
local function sort_within_match(files)
  sort(files)
  return files
end

---Sort
---@param files string_list_t
---@return string_list_t
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
---@param fh table file handle
---@param heading string
---@param description string
local function write_heading(fh, heading, description)
  fh:write("\n\n## " .. heading .. "\n\n")
  if description then
    fh:write(description)
  end
end

---@class manifest_param_t
---@field dir          string    the directory of the file
---@field count        integer   the count of the filename to be written
---@field filemaxchar  integer   the maximum number of chars of all filenames in this group
---@field descmaxchar  integer   the maximum number of chars of all descriptions in this group
---@field flag         boolean|string  false OR string for indicating CTAN/TDS location
---@field ctanfile     boolean   if file is in CTAN dir
---@field tdsfile      boolean   if file is in TDS dir

---comment
---@param fh       table write file handle
---@param filename string the name of the file to write
---@param param    manifest_param_t
local function write_group_file(fh, filename, param)
  -- no file description: plain bullet list item:
  local flagstr = param.flag or  ""
  fh:write("* " .. filename .. " " .. flagstr .. "\n")
  --[[
    -- or if you prefer an enumerated list:
    fh:write(param.count..". " .. filename .. "\n")
  --]]
end

---comment
---@param fh table write file handle
---@param filename   string the name of the file to write
---@param descr string description of the file to write
---@param param manifest_param_t
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

---Extract file description
---@param fh table file handle
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

---@class l3b_manifest_setup_t
---@field setup function
---@field sort_within_match function
---@field sort_within_group function
---@field write_opening function
---@field write_heading function
---@field write_group_file function
---@field write_group_file_descr function
---@field extract_filedesc function

return {
  global_symbol_map  = {},
  setup              = setup,
  sort_within_match  = sort_within_match,
  sort_within_group  = sort_within_group,
  write_opening      = write_opening,
  write_heading      = write_heading,
  write_group_file   = write_group_file,
  write_group_file_descr = write_group_file_descr,
  extract_filedesc   = extract_filedesc,
}
