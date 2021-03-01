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

---@type install_t
local l3b_install = require("l3b.install")
local install_files = l3b_install.install_files

-- Copy files to the main CTAN release directory
local function copy_ctan()
  make_directory(ctandir .. "/" .. ctanpkg)
  local function copyfiles(files, source)
    if source == currentdir or flatten then
      for filetype in entries(files) do
        copy_tree(filetype, source, ctandir .. "/" .. ctanpkg)
      end
    else
      for filetype in entries(files) do
        for file in values(tree(source, filetype)) do
          local path = dir_name(file)
          local ctantarget = ctandir .. "/" .. ctanpkg .. "/" .. path
          make_directory(ctantarget)
          copy_tree(file, source, ctantarget)
        end
      end
    end
  end
  for tab in items(
    bibfiles, demofiles, docfiles,
    pdffiles, scriptmanfiles, typesetlist
  ) do
    copyfiles(tab, docfiledir)
  end
  copyfiles(sourcefiles, sourcefiledir)
  for file in entries(textfiles) do
    copy_tree(file, textfiledir, ctandir .. "/" .. ctanpkg)
  end
end

---comment
---@return integer
local function bundle_ctan()
  local errorlevel = install_files(tdsdir, true)
  if errorlevel ~=0 then return errorlevel end
  copy_ctan()
  return 0
end

---comment
---@return integer
function ctan()
  -- Always run tests for all engines
  options["engine"] = nil
  local function dirzip(dir, name)
    local zipname = name .. ".zip"
    -- Convert the tables of files to quoted strings
    local binfiles = to_quoted_string(binaryfiles)
    local exclude = to_quoted_string(excludefiles)
    -- First, zip up all of the text files
    run(
      dir,
      zipexe .. " " .. zipopts .. " -ll ".. zipname .. " " .. "."
        .. (
          (binfiles or exclude) and (" -x" .. binfiles .. " " .. exclude)
          or ""
        )
    )
    -- Then add the binary ones
    run(
      dir,
      zipexe .. " " .. zipopts .. " -g ".. zipname .. " " .. ". -i" ..
        binfiles .. (exclude and (" -x" .. exclude) or "")
    )
  end
  local error_level
  local standalone = false
  if bundle == "" then
    standalone = true
  end
  if standalone then
    error_level = call({ "." }, "check")
    bundle = module
  else
    error_level = call(modules, "bundlecheck")
  end
  if error_level == 0 then
    remove_directory(ctandir)
    make_directory(ctandir .. "/" .. ctanpkg)
    remove_directory(tdsdir)
    make_directory(tdsdir)
    if standalone then
      error_level = install_files(tdsdir, true)
      if error_level ~=0 then return error_level end
      copy_ctan()
    else
      error_level = call(modules, "bundlectan")
    end
  else
    print("\n====================")
    print("Tests failed, zip stage skipped!")
    print("====================\n")
    return error_level
  end
  if error_level == 0 then
    for i in entries(textfiles) do
      for j in items(unpackdir, textfiledir) do
        copy_tree(i, j, ctandir .. "/" .. ctanpkg)
        copy_tree(i, j, tdsdir .. "/doc/" .. tdsroot .. "/" .. bundle)
      end
    end
    -- Rename README if necessary
    if ctanreadme ~= "" and not match(lower(ctanreadme), "^readme%.%w+") then
      local newfile = "README." .. match(ctanreadme, "%.(%w+)$")
      for dir in items(
        ctandir .. "/" .. ctanpkg,
        tdsdir .. "/doc/" .. tdsroot .. "/" .. bundle
      ) do
        if file_exists(dir .. "/" .. ctanreadme) then
          remove_tree(dir, newfile)
          rename(dir, ctanreadme, newfile)
        end
      end
    end
    dirzip(tdsdir, ctanpkg .. ".tds")
    if packtdszip then
      copy_tree(ctanpkg .. ".tds.zip", tdsdir, ctandir)
    end
    dirzip(ctandir, ctanzip)
    copy_tree(ctanzip .. ".zip", ctandir, currentdir)
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

---@class ctan_t
---@field ctan function
---@field bundle_ctan function

return {
  global_symbol_map = global_symbol_map,
  ctan = ctan,
  bundle_ctan = bundle_ctan,
}
