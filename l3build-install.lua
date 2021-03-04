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

local append = table.insert

---@type utlib_t
local utlib       = require("l3b.utillib")
local chooser     = utlib.chooser
local entries     = utlib.entries
local keys        = utlib.keys

---@type gblib_t
local gblib         = require("l3b.globlib")
local glob_matcher  = gblib.glob_matcher

---@type wklib_t
local wklib           = require("l3b.walklib")
local dir_base        = wklib.dir_base
local base_name       = wklib.base_name
local dir_name        = wklib.dir_name

---@type fslib_t
local fslib                 = require("l3b.fslib")
local file_list             = fslib.file_list
local directory_exists      = fslib.directory_exists
local remove_directory      = fslib.remove_directory
local copy_name             = fslib.copy_name
local copy_tree             = fslib.copy_tree
local file_exists           = fslib.file_exists
local remove_tree           = fslib.remove_tree
local tree                  = fslib.tree
local make_clean_directory  = fslib.make_clean_directory
local make_directory        = fslib.make_directory
local rename                = fslib.rename

---@type l3build_t
local l3build = require("l3build")

---@type l3b_vars_t
local l3b_vars  = require("l3b.variables")
---@type Dir_t
local Dir       = l3b_vars.Dir
---@type Main_t
local Main      = l3b_vars.Main
---@type Files_t
local Files     = l3b_vars.Files

---@type l3b_unpack_t
local l3b_unpack  = require("l3b.unpack")
local unpack      = l3b_unpack.unpack

---@type l3b_typesetting_t
local l3b_typesetting = require("l3b.typesetting")
local doc             = l3b_typesetting.doc

local Vars = chooser(_G, {
  -- Non-standard installation locations
  tdslocations = {}
})

local function gethome()
  set_program("latex")
  local options = l3build.options
  return options["texmfhome"] or var_value("TEXMFHOME")
end

---Uninstall
---@return error_level_t
local function uninstall()
  local function zapdir(dir)
    local install_dir = gethome() .. "/" .. dir
    local options = l3build.options
    if options["dry-run"] then
      local files = file_list(install_dir)
      if next(files) then
        print("\n" .. "For removal from " .. install_dir .. ":")
        for file in entries(install_dir) do
          print("- " .. file)
        end
      end
      return 0
    else
      if directory_exists(install_dir) then
        return remove_directory(install_dir)
      end
    end
    return 0
  end
  local function uninstall_files(dir, subdir)
    subdir = subdir or Dir.module
    dir = dir .. "/" .. subdir
    return zapdir(dir)
  end
  local error_level = 0
  -- Any script man files need special handling
  local manfiles = {}
  for glob in entries(Files.scriptman) do
    for file in keys(tree(Dir.docfile, glob)) do
      -- Man files should have a single-digit extension: the type
      local man = "man" .. match(file, ".$")
      local install_dir = gethome() .. "/doc/man/"  .. man
      if file_exists(install_dir .. "/" .. file) then
        local options = l3build.options
        if options["dry-run"] then
          append(manfiles, man .. "/" .. base_name(file))
        else
          error_level = error_level + remove_tree(install_dir, file)
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
              + uninstall_files("bibtex/bst", Main.module)
              + uninstall_files("makeindex", Main.module)
              + uninstall_files("scripts", Main.module)
              + error_level
  if error_level ~= 0 then return error_level end
  -- Finally, clean up special locations
  for location in entries(Vars.tdslocations) do
    local path = dir_name(location)
    error_level = zapdir(path)
    if error_level ~= 0 then return error_level end
  end
  return 0
end

---Install files
---@param target string
---@param full boolean
---@param dry_run boolean
---@return error_level_t
local function install_files(target, full, dry_run)

  -- Needed so paths are only cleaned out once
  local cleanpaths = {}
  -- Collect up all file data before copying:
  -- ensures no files are lost during clean-up
  local install_map = {}

  local function feed_install_map(source, dir, files, subdir)
    subdir = subdir or Dir.module
    -- For material associated with secondary tools (BibTeX, MakeIndex)
    -- the structure needed is slightly different from those items going
    -- into the tex/doc/source trees
    if (dir == "makeindex" or match(dir, "$bibtex")) and Main.module == "base" then -- "base" is latex2e specific
      subdir = "latex"
    end
    if subdir then dir = dir .."/".. subdir end
    local file_names = {}
    local source_paths = {}
    local paths = {}
    -- Generate a file list and include the directory
    for glob_list in entries(files) do
      for glob in entries(glob_list) do
        for file in keys(tree(source, glob)) do
          local file_dir, file_base = dir_base(file)
          local source_path = "/"
          if file_dir == "." then
            source_paths[file_base] = source
          else
            file_dir = gsub(file_dir, "^%.", "")
            source_paths[file_base] = source .. file_dir
            if not Main.flattentds then
              source_path = file_dir .. "/"
            end
          end
          local matched = false
          for location in entries(Vars.tdslocations) do
            local l_dir, l_glob = dir_base(location)
            local accept = glob_matcher(l_glob)
            if accept(file_base) then
              append(paths, l_dir)
              append(file_names, l_dir .. source_path .. file_base)
              matched = true
              break
            end
          end
          if not matched then
            append(paths, dir)
            append(file_names, dir .. source_path .. file_base)
          end
        end
      end
    end

    local errorlevel = 0
    -- The target is only created if there are actual files to install
    if next(file_names) then
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
      for name in entries(file_names) do
        if dry_run then
          print("- " .. name)
        else
          local path, file = dir_base(name)
          append(install_map, {
            file = file,
            source = source_paths[file],
            dest = target .. "/" .. path
          })
        end
      end
    end
    return 0
  end

  local error_level = unpack()
  if error_level ~= 0 then return error_level end

    -- Creates a 'controlled' list of files
    local function create_file_list(dir, include, exclude)
      dir = dir or Dir.current
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
            append(result, file)
          end
        end
      end
      return result
    end

  local install_list = create_file_list(Dir.unpack, Files.install, { Files.script })

  if full then
    error_level = doc()
    if error_level ~= 0 then return error_level end

    -- Set up lists: global as they are also needed to do CTAN releases
    _G.typesetlist = create_file_list(Dir.docfile, Files.typeset, { Files.source })
    _G.sourcelist = create_file_list(Dir.sourcefile, Files.source,
      { Files.bst, Files.install, Files.makeindex, Files.script })

    if dry_run then
      print("\nFor installation inside " .. target .. ":")
    end

    error_level =
        feed_install_map(Dir.sourcefile, "source", { _G.sourcelist })
      + feed_install_map(Dir.docfile, "doc", {
          Files.bib, Files.demo, Files.doc,
          Files._all_pdffiles [[ For the purposes here,
          any typesetting demo files need to be part of the main typesetting list
        ]], Files.text, _G.typesetlist
      })
    if error_level ~= 0 then return error_level end

    -- Rename README if necessary
    if not dry_run then
      local readme = Main.ctanreadme
      if readme ~= "" and not match(lower(readme), "^readme%.%w+") then
        local install_dir = target .. "/doc/" .. Dir.module
        if file_exists(install_dir .. "/" .. readme) then
          rename(install_dir, readme, "README." .. match(readme, "%.(%w+)$"))
        end
      end
    end

    -- Any script man files need special handling
    for glob in entries(Files.scriptman) do -- shallow glob
      for name in keys(tree(Dir.docfile, glob)) do
        local man = "man" .. match(name, ".$")
        if dry_run then
          print("- doc/man/" .. man .. "/" .. base_name(name))
        else
          -- Man files should have a single-digit tail: the type
          local install_dir = target .. "/doc/man/"  .. man
          error_level = error_level + make_directory(install_dir)
                                    + copy_name(name, Dir.docfile, install_dir)
        end
      end
    end
  end

  if error_level ~= 0 then return error_level end

  error_level =
      feed_install_map(Dir.unpack, "tex", { install_list })
    + feed_install_map(Dir.unpack, "bibtex/bst", { Files.bst }, Main.module)
    + feed_install_map(Dir.unpack, "makeindex", { Files.makeindex }, Main.module)
    + feed_install_map(Dir.unpack, "scripts", { Files.script }, Main.module)

  if error_level ~= 0 then return error_level end

  -- Files are all copied in one shot: this ensures that cleandir()
  -- can't be an issue even if there are complex set-ups
  for v in entries(install_map) do
    error_level = copy_tree(v.file, v.source, v.dest)
    if error_level ~= 0  then return error_level end
  end

  return 0
end

local function install()
  local options = l3build.options
  return install_files(gethome(), options["full"], options["dry-run"])
end

---@class l3b_install_t
---@field uninstall     fun(): integer
---@field install_files fun(target: string, full: boolean, dry_run: boolean): integer
---@field install       fun(): integer

return {
  uninstall     = uninstall,
  install_files = install_files,
  install       = install,
}
