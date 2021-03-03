--[[

File l3build-install.lua Copyright (C) 2018-2020 The LaTeX Project

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

local print  = print

local kpse        = require("kpse")
local set_program = kpse.set_program_name
local var_value   = kpse.var_value

local gsub  = string.gsub
local lower = string.lower
local match = string.match

local insert = table.insert

---@type utlib_t
local utlib       = require("l3b.utillib")
local entries     = utlib.entries
local keys        = utlib.keys
local first_of    = utlib.first_of
local extend_with = utlib.extend_with

---@type gblib_t
local gblib           = require("l3b.globlib")
local glob_to_pattern = gblib.glob_to_pattern

---@type wklib_t
local wklib           = require("l3b.walklib")
local dir_base        = wklib.dir_base
local dir_name        = wklib.dir_name

---@type fslib_t
local fslib                 = require("l3b.fslib")
local file_list             = fslib.file_list
local directory_exists      = fslib.directory_exists
local remove_directory      = fslib.remove_directory
local copy_tree             = fslib.copy_tree
local file_exists           = fslib.file_exists
local remove_tree           = fslib.remove_tree
local tree                  = fslib.tree
local make_clean_directory  = fslib.make_clean_directory
local make_directory        = fslib.make_directory
local rename                = fslib.rename

---@type l3b_unpack_t
local l3b_unpack  = require("l3b.unpack")
local unpack      = l3b_unpack.unpack

---@type l3b_typesetting_t
local l3b_typesetting = require("l3b.typesetting")
local doc             = l3b_typesetting.doc

local function gethome()
  set_program("latex")
  return (options["texmfhome"] or var_value("TEXMFHOME"))
end

local function uninstall()
  local function zapdir(dir)
    local installdir = gethome() .. "/" .. dir
    if options["dry-run"] then
      local files = file_list(installdir)
      if next(files) then
        print("\n" .. "For removal from " .. installdir .. ":")
        for file in entries(installdir) do
          print("- " .. file)
        end
      end
      return 0
    else
      if directory_exists(installdir) then
        return remove_directory(installdir)
      end
    end
    return 0
  end
  local function uninstall_files(dir, subdir)
    subdir = subdir or moduledir
    dir = dir .. "/" .. subdir
    return zapdir(dir)
  end
  local error_level = 0
  -- Any script man files need special handling
  local manfiles = {}
  for glob in entries(scriptmanfiles) do
    for file in keys(tree(docfiledir, glob)) do
      -- Man files should have a single-digit extension: the type
      local installdir = gethome() .. "/doc/man/man"  .. match(file, ".$")
      if file_exists(installdir .. "/" .. file) then
        if options["dry-run"] then
          insert(manfiles, "man" .. match(file, ".$") .. "/" ..
           select(2, dir_base(file)))
        else
          error_level = error_level + remove_tree(installdir, file)
        end
      end
    end
  end
  if next(manfiles) then
    print("\n" .. "For removal from " .. gethome() .. "/doc/man:")
    for v in entries(manfiles) do
      print("- " .. v)
    end
  end
  error_level = uninstall_files("doc")
         + uninstall_files("source")
         + uninstall_files("tex")
         + uninstall_files("bibtex/bst", module)
         + uninstall_files("makeindex", module)
         + uninstall_files("scripts", module)
         + error_level
  if error_level ~= 0 then return error_level end
  -- Finally, clean up special locations
  for location in entries(tdslocations) do
    local path = dir_name(location)
    error_level = zapdir(path)
    if error_level ~= 0 then return error_level end
  end
  return 0
end

local function install_files(target, full, dry_run)

  -- Needed so paths are only cleaned out once
  local cleanpaths = {}
  -- Collect up all file data before copying:
  -- ensures no files are lost during clean-up
  local installmap = {}

  local function create_install_map(source, dir, files, subdir)
    subdir = subdir or moduledir
    -- For material associated with secondary tools (BibTeX, MakeIndex)
    -- the structure needed is slightly different from those items going
    -- into the tex/doc/source trees
    if (dir == "makeindex" or match(dir, "$bibtex")) and module == "base" then
      subdir = "latex"
    end
    dir = dir .. (subdir and ("/" .. subdir) or "")
    local filenames = {}
    local sourcepaths = {}
    local paths = {}
    -- Generate a file list and include the directory
    for glob_table in entries(files) do
      for glob in entries(glob_table) do
        for file in keys(tree(source, glob)) do
          -- Just want the name
          local path, filename = dir_base(file)
          local sourcepath = "/"
          if path == "." then
            sourcepaths[filename] = source
          else
            path = gsub(path, "^%.", "")
            sourcepaths[filename] = source .. path
            if not flattentds then sourcepath = path .. "/" end
          end
          local matched = false
          for location in entries(tdslocations) do
            local l_dir, l_glob = dir_base(location)
            local pattern = glob_to_pattern(l_glob)
            if match(filename, pattern) then
              insert(paths, l_dir)
              insert(filenames, l_dir .. sourcepath .. filename)
              matched = true
              break
            end
          end
          if not matched then
            insert(paths, dir)
            insert(filenames, dir .. sourcepath .. filename)
          end
        end
      end
    end

    local errorlevel = 0
    -- The target is only created if there are actual files to install
    if next(filenames) then
      if not dry_run then
        for path in entries(paths) do
          local target_path = target .. "/" .. path
          if not cleanpaths[target_path] then
            errorlevel = make_clean_directory(target_path)
            if errorlevel ~= 0 then return errorlevel end
          end
          cleanpaths[target_path] = true
        end
      end
      for name in entries(filenames) do
        if dry_run then
          print("- " .. name)
        else
          local path, file = dir_base(name)
          insert(installmap,
            { file = file, source = sourcepaths[file], dest = target .. "/" .. path })
        end
      end
    end
    return 0
  end

  local errorlevel = unpack()
  if errorlevel ~= 0 then return errorlevel end

    -- Creates a 'controlled' list of files
    local function create_file_list(dir, include, exclude)
      dir = dir or currentdir
      include = include or {}
      exclude = exclude or {}
      local excludelist = {}
      for glob_table in entries(exclude) do
        for glob in entries(glob_table) do
          for file in keys(tree(dir, glob)) do
            excludelist[file] = true
          end
        end
      end
      local result = {}
      for glob in entries(include) do
        for file in keys(tree(dir, glob)) do
          if not excludelist[file] then
            insert(result, file)
          end
        end
      end
      return result
    end

  local installlist = create_file_list(unpackdir, installfiles, { scriptfiles })

  if full then
    errorlevel = doc()
    if errorlevel ~= 0 then return errorlevel end
    -- For the purposes here, any typesetting demo files need to be
    -- part of the main typesetting list
    local typesetfiles = typesetfiles
    for glob in entries(typesetdemofiles) do
      insert(typesetfiles, glob)
    end

    -- Find PDF files
    pdffiles = {}
    for glob in entries(typesetfiles) do
      insert(pdffiles, first_of(gsub(glob, "%.%w+$", ".pdf")))
    end

    -- Set up lists: global as they are also needed to do CTAN releases
    typesetlist = create_file_list(docfiledir, typesetfiles, { sourcefiles })
    sourcelist = create_file_list(sourcefiledir, sourcefiles,
      { bstfiles, installfiles, makeindexfiles, scriptfiles })
 
  if dry_run then
    print("\nFor installation inside " .. target .. ":")
  end 
    
    errorlevel = create_install_map(sourcefiledir, "source", { sourcelist })
      + create_install_map(docfiledir, "doc",
          { bibfiles, demofiles, docfiles, pdffiles, textfiles, typesetlist })
    if errorlevel ~= 0 then return errorlevel end

    -- Rename README if necessary
    if not dry_run then
      if ctanreadme ~= "" and not match(lower(ctanreadme), "^readme%.%w+") then
        local installdir = target .. "/doc/" .. moduledir
        if file_exists(installdir .. "/" .. ctanreadme) then
          rename(installdir, ctanreadme, "README." .. match(ctanreadme, "%.(%w+)$"))
        end
      end
    end

    -- Any script man files need special handling
    local manfiles = {}
    for glob in entries(scriptmanfiles) do
      for file in keys(tree(docfiledir, glob)) do
        if dry_run then
          insert(manfiles, "man" .. match(file, ".$") .. "/" ..
            select(2, dir_base(file)))
        else
          -- Man files should have a single-digit extension: the type
          local installdir = target .. "/doc/man/man"  .. match(file, ".$")
          errorlevel = errorlevel + make_directory(installdir)
          errorlevel = errorlevel + copy_tree(file, docfiledir, installdir)
        end
      end
    end
    if next(manfiles) then
      for v in entries(manfiles) do
        print("- doc/man/" .. v)
      end
    end
  end

  if errorlevel ~= 0 then return errorlevel end

  errorlevel = create_install_map(unpackdir, "tex", { installlist })
    + create_install_map(unpackdir, "bibtex/bst", { bstfiles }, module)
    + create_install_map(unpackdir, "makeindex", { makeindexfiles }, module)
    + create_install_map(unpackdir, "scripts", { scriptfiles }, module)

  if errorlevel ~= 0 then return errorlevel end

  -- Files are all copied in one shot: this ensures that cleandir()
  -- can't be an issue even if there are complex set-ups
  for v in entries(installmap) do
    errorlevel = copy_tree(v.file, v.source, v.dest)
    if errorlevel ~= 0  then return errorlevel end
  end

  return 0
end

local function install()
  return install_files(gethome(), options["full"], options["dry-run"])
end


-- this is the map to export function symbols to the global space
local global_symbol_map = {
  uninstall     = uninstall,
  install_files = install_files,
  install       = install,
}

--[=[ Export function symbols ]=]
extend_with(_G, global_symbol_map)
-- [=[ ]=]

---@class l3b_install_t
---@field uninstall function
---@field install_files function
---@field install function

return {
  global_symbol_map = global_symbol_map,
  uninstall     = uninstall,
  install_files = install_files,
  install       = install,
}
