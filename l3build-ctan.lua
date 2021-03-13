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

local lower = string.lower
local match = string.match

---@type utlib_t
local utlib    = require("l3b-utillib")
local chooser = utlib.chooser
local entries = utlib.entries
local items   = utlib.items
local values  = utlib.values
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

---@type l3b_vars_t
local l3b_vars  = require("l3build-variables")
---@type Main_t
local Main      = l3b_vars.Main
---@type Dir_t
local Dir       = l3b_vars.Dir
---@type Files_t
local Files     = l3b_vars.Files
---@type Exe_t
local Exe       = l3b_vars.Exe
---@type Opts_t
local Opts      = l3b_vars.Opts

---@type l3b_aux_t
local l3b_aux = require("l3build-aux")
local call    = l3b_aux.call

---@type l3b_inst_t
local l3b_inst = require("l3build-install")
local install_files = l3b_inst.install_files
---@type l3b_inst_vars_t
local l3b_inst_vars = l3b_inst.Vars

---@class l3b_ctan_vars_t
---@field flatten boolean Switch to flatten any source structure when sending to CTAN
---@field packtdszip boolean Switch to build a TDS-style zip file for CTAN

---@type l3b_ctan_vars_t
local Vars = chooser({
  global = _G,
  default = {
    flatten = true,
    packtdszip = false,
  },
})

-- Copy files to the main CTAN release directory
local function copy_ctan()
  local ctanpkg_dir = Dir.ctan .. "/" .. Main.ctanpkg
  make_directory(ctanpkg_dir)
  local function copy_files(files, source)
    if source == Dir.work or Vars.flatten then
      for file_type in entries(files) do
        copy_tree(file_type, source, ctanpkg_dir)
      end
    else
      for file_type in entries(files) do
        for p in tree(source, file_type) do
          local file = p.wrk
          local path = dir_name(file)
          local ctantarget = ctanpkg_dir .. "/" .. path
          make_directory(ctantarget)
          copy_tree(file, source, ctantarget)
        end
      end
    end
  end
  for tab in items(
    Files.bib, Files.demo, Files.doc,
    Files.scriptman, Files._all_pdf, l3b_inst_vars.typeset_list
  ) do
    copy_files(tab, Dir.docfile)
  end
  copy_files(Files.source, Dir.sourcefile)
  for file in entries(Files.text) do
    copy_tree(file, Dir.textfile, ctanpkg_dir)
  end
end

---One of the bundle private targets
---@return error_level_n
local function module_ctan()
  local error_level = install_files(Dir.tds, true)
  if error_level ~=0 then
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
  local standalone = Main._standalone
  if standalone then
    error_level = call({ "." }, "check")
  else
    error_level = call(Main.modules, "module_check")
  end
  if error_level ~= 0 then
    print("\n====================")
    print("Tests failed, zip stage skipped!")
    print("====================\n")
    return error_level
  end
  remove_directory(Dir.ctan)
  make_directory(Dir.ctan .. "/" .. Main.ctanpkg)
  remove_directory(Dir.tds)
  make_directory(Dir.tds)
  if standalone then
    error_level = install_files(Dir.tds, true)
    if error_level ~=0 then
      return error_level
    end
    copy_ctan()
  else
    error_level = call(Main.modules, "module_ctan")
    if error_level ~= 0 then
      print("\n====================")
      print("Typesetting failed, zip stage skipped!")
      print("====================\n")
      return error_level
    end
  end
  for glob in entries(Files.text) do
    for src_dir in items(Dir.unpack, Dir.textfile) do
      copy_tree(glob, src_dir, Dir.ctan .. "/"     .. Main.ctanpkg)
      copy_tree(glob, src_dir, Dir.tds  .. "/doc/" .. Main.tdsroot .. "/" .. Main.bundle)
    end
  end
  -- Rename README if necessary
  local readme = l3b_inst_vars.ctanreadme
  if readme ~= "" and not lower(readme):match("^readme%.%w+") then
    local newfile = "README." .. readme:match("%.(%w+)$")
    for dir in items(
      Dir.ctan .. "/" .. Main.ctanpkg,
      Dir.tds .. "/doc/" .. Main.tdsroot .. "/" .. Main.bundle
    ) do
      if file_exists(dir .. "/" .. readme) then
        remove_tree(dir, newfile)
        rename(dir, readme, newfile)
      end
    end
  end
  local function dirzip(dir, name)
    local zipname = name .. ".zip"
    -- Convert the tables of files to quoted strings
    local bin_files = to_quoted_string(Files.binary)
    local exclude = to_quoted_string(Files.exclude)
    -- First, zip up all of the text files
    local cmd = Exe.zip .. " " .. Opts.zip .. " -ll ".. zipname .. " ."
      .. (
        (bin_files or exclude)
        and (" -x " .. bin_files .. " " .. exclude)
        or ""
      )
    run(dir, cmd)
    -- Then add the binary ones
    cmd = Exe.zip .. " " .. Opts.zip .. " -g ".. zipname .. " ."
      .. " -i " .. bin_files
      .. (exclude and (" -x " .. exclude) or "")
    run(dir, cmd)
  end
  dirzip(Dir.tds, Main.ctanpkg .. ".tds")
  if Vars.packtdszip then
    copy_tree(Main.ctanpkg .. ".tds.zip", Dir.tds, Dir.ctan)
  end
  dirzip(Dir.ctan, Main.ctanzip)
  copy_tree(Main.ctanzip .. ".zip", Dir.ctan, Dir.work)
  return error_level
end

---@class l3b_ctan_t
---@field Vars              l3b_ctan_vars_t
---@field ctan_impl         target_impl_t
---@field module_ctan_impl  target_impl_t

return {
  Vars              = Vars,
  ctan_impl         = {
    run = ctan,
  },
  module_ctan_impl  = {
    run = module_ctan,
  },
}
