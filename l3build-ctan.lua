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
local utlib    = require("l3b.utillib")
local chooser = utlib.chooser
local entries = utlib.entries
local items   = utlib.items
local values  = utlib.values
local to_quoted_string = utlib.to_quoted_string
local extend_with     = utlib.extend_with

---@type wklib_t
local wklib    = require("l3b.walklib")
local dir_name = wklib.dir_name

---@type oslib_t
local oslib = require("l3b.oslib")
local run   = oslib.run

---@type fslib_t
local fslib           = require("l3b.fslib")
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
local l3b_vars  = require("l3b.variables")
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
local l3b_aux = require("l3b.aux")
local call    = l3b_aux.call

---@type l3b_install_t
local l3b_install = require("l3b.install")
local install_files = l3b_install.install_files

---@class l3b_ctan_vars_t
---@field packtdszip boolean
---@field flatten boolean

---@type l3b_ctan_vars_t
local Vars = chooser(_G, {
  packtdszip = false,
  flatten = true,
})

-- Copy files to the main CTAN release directory
local function copy_ctan()
  local ctanpkg_dir = Dir.ctan .. "/" .. Main.ctanpkg
  make_directory(ctanpkg_dir)
  local function copyfiles(files, source)
    if source == Dir.current or Vars.flatten then
      for filetype in entries(files) do
        copy_tree(filetype, source, ctanpkg_dir)
      end
    else
      for filetype in entries(files) do
        for file in values(tree(source, filetype)) do
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
    _G.pdffiles, Files.scriptman, _G.typesetlist
  ) do
    copyfiles(tab, Dir.docfile)
  end
  copyfiles(Files.source, Dir.sourcefile)
  for file in entries(Files.text) do
    copy_tree(file, Dir.textfile, ctanpkg_dir)
  end
end

---comment
---@return integer
local function bundle_ctan()
  local errorlevel = install_files(Dir.tds, true)
  if errorlevel ~=0 then return errorlevel end
  copy_ctan()
  return 0
end

---comment
---@return integer
local function ctan()
  -- Always run tests for all engines
  local options = l3build.options
  options["engine"] = nil
  local function dirzip(dir, name)
    local zipname = name .. ".zip"
    -- Convert the tables of files to quoted strings
    local binfiles = to_quoted_string(Files.binary)
    local exclude = to_quoted_string(Files.exclude)
    -- First, zip up all of the text files
    run(
      dir,
      Exe.zip .. " " .. Opts.zip .. " -ll ".. zipname .. " " .. "."
        .. (
          (binfiles or exclude) and (" -x" .. binfiles .. " " .. exclude)
          or ""
        )
    )
    -- Then add the binary ones
    run(
      dir,
      Exe.zip .. " " .. Opts.zip .. " -g ".. zipname .. " " .. ". -i" ..
        binfiles .. (exclude and (" -x" .. exclude) or "")
    )
  end
  local error_level
  local standalone = false
  if Main.bundle == "" then
    standalone = true
  end
  if standalone then
    error_level = call({ "." }, "check")
    Main.bundle = module
  else
    error_level = call(_G.modules, "bundlecheck")
  end
  if error_level == 0 then
    remove_directory(Dir.ctan)
    make_directory(Dir.ctan .. "/" .. Main.ctanpkg)
    remove_directory(Dir.tds)
    make_directory(Dir.tds)
    if standalone then
      error_level = install_files(Dir.tds, true)
      if error_level ~=0 then return error_level end
      copy_ctan()
    else
      error_level = call(_G.modules, "bundlectan")
    end
  else
    print("\n====================")
    print("Tests failed, zip stage skipped!")
    print("====================\n")
    return error_level
  end
  if error_level == 0 then
    for i in entries(Files.text) do
      for j in items(Dir.unpack, Dir.textfile) do
        copy_tree(i, j, Dir.ctan .. "/" .. Main.ctanpkg)
        copy_tree(i, j, Dir.tds .. "/doc/" .. Main.tdsroot .. "/" .. Main.bundle)
      end
    end
    -- Rename README if necessary
    local readme = Main.ctanreadme
    if readme ~= "" and not match(lower(readme), "^readme%.%w+") then
      local newfile = "README." .. match(readme, "%.(%w+)$")
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
    dirzip(Dir.tds, Main.ctanpkg .. ".tds")
    if Vars.packtdszip then
      copy_tree(Main.ctanpkg .. ".tds.zip", Dir.tds, Dir.ctan)
    end
    dirzip(Dir.ctan, Main.ctanzip)
    copy_tree(Main.ctanzip .. ".zip", Dir.ctan, Dir.current)
  else
    print("\n====================")
    print("Typesetting failed, zip stage skipped!")
    print("====================\n")
  end
  return error_level
end

-- this is the map to export function symbols to the global space
local global_symbol_map = {
  ctan       = ctan,
  bundlectan = bundle_ctan,
}

--[=[ Export function symbols ]=]
extend_with(_G, global_symbol_map)
-- [=[ ]=]

---@class l3b_ctan_t
---@field ctan        fun(): integer
---@field bundle_ctan fun(): integer

return {
  global_symbol_map = global_symbol_map,
  ctan              = ctan,
  bundle_ctan       = bundle_ctan,
}
