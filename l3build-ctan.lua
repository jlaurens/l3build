--[[

File l3build-ctan.lua Copyright (C) 2018-2020 The LaTeX Project

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

local print = print

---@type utlib_t
local utlib   = require("l3b-utillib")
local entries = utlib.entries
local items   = utlib.items
local to_quoted_string = utlib.to_quoted_string

---@type wklib_t
local wklib    = require("l3b-walklib")
local dir_name = wklib.dir_name

---@type oslib_t
local oslib = require("l3b-oslib")
local run   = oslib.run

---@type fslib_t
local fslib           = require("l3b-fslib")
local make_directory  = fslib.make_directory
local file_exists     = fslib.file_exists
local tree            = fslib.tree
local remove_tree     = fslib.remove_tree
local copy_tree       = fslib.copy_tree
local rename          = fslib.rename
local remove_directory  = fslib.remove_directory

---@type l3build_t
local l3build = require("l3build")

---@type l3b_globals_t
local l3b_globals = require("l3build-globals")
---@type G_t
local G           = l3b_globals.G
---@type Dir_t
local Dir         = l3b_globals.Dir
---@type Files_t
local Files       = l3b_globals.Files
---@type Exe_t
local Exe         = l3b_globals.Exe
---@type Opts_t
local Opts        = l3b_globals.Opts

---@type l3b_aux_t
local l3b_aux = require("l3build-aux")
local call    = l3b_aux.call

---@type l3b_inst_t
local l3b_inst = require("l3build-install")
local install_files = l3b_inst.install_files

-- Copy files to the main CTAN release directory
local function copy_ctan()
  local ctanpkg_dir = Dir.ctan / G.ctanpkg
  make_directory(ctanpkg_dir)
  local function copy_files(files, source)
    if source == Dir.work or G.flatten then
      copy_tree(files, source, ctanpkg_dir)
    else
      for file_type in entries(files) do
        for p in tree(source, file_type) do
          local file = p.wrk
          local path = dir_name(file)
          local ctantarget = ctanpkg_dir / path
          make_directory(ctantarget)
          copy_tree(file, source, ctantarget)
        end
      end
    end
  end
  for tab in items(
    Files.bib, Files.demo, Files.doc,
    Files.scriptman, Files._all_pdf, G.typeset_list
  ) do
    copy_files(tab, Dir.docfile)
  end
  copy_files(Files.source, Dir.sourcefile)
  copy_tree (Files.text, Dir.textfile, ctanpkg_dir)
end

---One of the bundle private targets
---@return error_level_n
local function module_ctan()
  local error_level = install_files(Dir.tds, true)
  if error_level ~= 0 then
    return error_level
  end
  copy_ctan()
  return 0
end

---comment
---@return error_level_n
local function ctan()
  -- Always run tests for all engines
  l3build.options.engine = nil
  local error_level
  local is_embedded = G.is_embedded
  if is_embedded then
    error_level = call(G.modules, "module_check")
  else
    error_level = call({ "." }, "check")
  end
  if error_level ~= 0 then
    print("\n====================")
    print("Tests failed, zip stage skipped!")
    print("====================\n")
    return error_level
  end
  remove_directory(Dir.ctan)
  make_directory(Dir.ctan / G.ctanpkg)
  remove_directory(Dir.tds)
  make_directory(Dir.tds)
  if is_embedded then
    error_level = install_files(Dir.tds, true)
    if error_level ~= 0 then
      return error_level
    end
    copy_ctan()
  else
    error_level = call(G.modules, "module_ctan")
    if error_level ~= 0 then
      print("\n====================")
      print("Typesetting failed, zip stage skipped!")
      print("====================\n")
      return error_level
    end
  end
  for src_dir in items(Dir.unpack, Dir.textfile) do
    copy_tree(Files.text, src_dir,
              Dir.ctan / G.ctanpkg)
    copy_tree(Files.text, src_dir,
              Dir.tds  .. "/doc/" .. G.tds_main)
  end
  -- Rename README if necessary
  local readme = G.ctanreadme
  if readme ~= "" and not readme:lower():match("^readme%.%w+") then
    local newfile = "README." .. readme:match("%.(%w+)$")
    for dir in items(
      Dir.ctan / G.ctanpkg,
      Dir.tds .. "/doc/" .. G.tds_main
    ) do
      if file_exists(dir / readme) then
        remove_tree(dir, newfile)
        rename(dir, readme, newfile)
      end
    end
  end
  local function zip_directory(dir, name)
    os.execute("ls -al \"".. dir .. "\"")
    local zip_name = name .. ".zip"
    -- Convert the tables of files to quoted strings
    local bin_files = to_quoted_string(Files.binary)
    local exclude = to_quoted_string(Files.exclude)
    -- First, zip up all of the text files
    local cmd = Exe.zip .. " " .. Opts.zip .. " -ll ".. zip_name .. " ."
      .. (
        (bin_files or exclude)
        and (" -x " .. bin_files .. " " .. exclude)
        or ""
      )
    run(dir, cmd)
    -- Then add the binary ones
    cmd = Exe.zip .. " " .. Opts.zip .. " -g ".. zip_name .. " ."
      .. " -i " .. bin_files
      .. (exclude and (" -x " .. exclude) or "")
    run(dir, cmd)
  end
  zip_directory(Dir.tds, G.ctanpkg .. ".tds")
  if G.packtdszip then
    copy_tree(G.ctanpkg .. ".tds.zip", Dir.tds, Dir.ctan)
  end
  zip_directory(Dir.ctan, G.ctanzip)
  copy_tree(G.ctanzip .. ".zip", Dir.ctan, Dir.work)
end

---@class l3b_ctan_t
---@field public ctan_impl         target_impl_t
---@field public module_ctan_impl  target_impl_t

return {
  ctan_impl         = {
    run = ctan,
  },
  module_ctan_impl  = {
    run = module_ctan,
  },
}
