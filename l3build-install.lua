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

local print     = print
local not_empty = next

local kpse        = require("kpse")
local set_program = kpse.set_program_name
local var_value   = kpse.var_value

local append = table.insert

---@type utlib_t
local utlib       = require("l3b-utillib")
local chooser     = utlib.chooser
local entries     = utlib.entries
local keys        = utlib.keys

---@type gblib_t
local gblib           = require("l3b-globlib")
local to_glob_match = gblib.to_glob_match

---@type wklib_t
local wklib           = require("l3b-walklib")
local dir_base        = wklib.dir_base
local base_name       = wklib.base_name
local dir_name        = wklib.dir_name

---@type fslib_t
local fslib                 = require("l3b-fslib")
local file_list             = fslib.file_list
local directory_exists      = fslib.directory_exists
local remove_directory      = fslib.remove_directory
local copy_file             = fslib.copy_file
local file_exists           = fslib.file_exists
local remove_tree           = fslib.remove_tree
local tree                  = fslib.tree
local make_clean_directory  = fslib.make_clean_directory
local make_directory        = fslib.make_directory
local rename                = fslib.rename

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

---@type l3b_unpk_t
local l3b_unpk  = require("l3build-unpack")
local unpack    = l3b_unpk.unpack

---@type l3b_tpst_t
local l3b_tpst  = require("l3build-typesetting")
local doc       = l3b_tpst.doc

---@class l3b_inst_vars_t
---@field flattentds    boolean Switch to flatten any source structure when creating a TDS structure
---@field flattenscript boolean Switch to flatten any script structure when creating a TDS structure
---@field texmf_home    string_list_t
---@field typeset_list  string_list_t
---@field ctanreadme    string  Name of the file to send to CTAN as \texttt{README.\meta{ext}}s
---@field tdslocations  string_list_t For non-standard file installations

---@type string_list_t
local typeset_list

---@type l3b_inst_vars_t
local Vars = chooser({
  global = _G,
  default = {
    flattentds    = true,
    ctanreadme    = "README.md",
    tdslocations    = {},
  },
  computed = {
    flattenscript = function (t, k, v_dflt)
      return t.flattentds -- by defaut flattentds and flattenscript are synonyms
    end,
    typeset_list = function (t, k, v_dflt)
      assert(typeset_list, "Documentation is not installed")
      return typeset_list
    end,
    texmf_home = function (t, k, v_dflt)
      local result = l3build.options.texmfhome
      if not result then
        set_program("latex")
        result = var_value("TEXMFHOME")
      end
      return result
    end,
  },
})

---Uninstall
---@return error_level_n
local function uninstall()
  local error_level = 0
  local dry_run = l3build.options["dry-run"]
  -- Any script man files need special handling
  local man_files = {}
  for glob in entries(Files.scriptman) do
    for p in tree(Dir.docfile, glob) do
      local p_src = p.src
      -- Man files should have a single-digit extension: the type
      local man = "man" .. p_src:match(".$")
      local install_dir = Vars.texmf_home .. "/doc/man/"  .. man
      if file_exists(install_dir .. "/" .. p_src) then
        if dry_run then
          append(man_files, man .. "/" .. base_name(p_src))
        else
          error_level = error_level + remove_tree(install_dir, p_src)
        end
      end
    end
  end
  if not_empty(man_files) then
    print("\n" .. "For removal from " .. Vars.texmf_home .. "/doc/man:")
    for v in entries(man_files) do
      print("- " .. v)
    end
  end
  local zap_dir = dry_run
    and function (dir)
      local install_dir = Vars.texmf_home .. "/" .. dir
      local files = file_list(install_dir)
      if not_empty(files) then
        print("\n" .. "For removal from " .. install_dir .. ":")
        for file in entries(files) do
          print("- " .. file)
        end
      end
      return 0
    end
    or function (dir)
      local install_dir = Vars.texmf_home .. "/" .. dir
      if directory_exists(install_dir) then
        return remove_directory(install_dir)
      end
      return 0
    end
  local function uninstall_files(dir, subdir)
    return zap_dir(dir .. "/" .. (subdir or Dir.tds_module))
  end
  error_level = uninstall_files("doc")
              + uninstall_files("source")
              + uninstall_files("tex")
              + uninstall_files("bibtex/bst", Main.module)
              + uninstall_files("makeindex", Main.module)
              + uninstall_files("scripts", Main.module)
              + error_level
  if error_level ~= 0 then
    return error_level
  end
  -- Finally, clean up special locations
  for location in entries(Vars.tdslocations) do
    local path = dir_name(location)
    error_level = zap_dir(path)
    if error_level ~= 0 then
      return error_level
    end
  end
  return 0
end

---Install files
---@param root_install_dir string
---@param full boolean, true means with documentation and man pages
---@param dry_run boolean
---@return error_level_n
local function install_files(root_install_dir, full, dry_run)

  local error_level = unpack()
  if error_level ~= 0 then
    return error_level
  end

    -- Needed so paths are only cleaned out once
  ---@type flag_table_t
  local already_cleaned = {}

  -- Collect up all file entries before copying:
  -- ensures no files are lost during clean-up
  ---@type table<integer, copy_name_kv>
  local to_copy = {}

  local function feed_to_copy(src_dir, type, file_globs, flatten, module)
    module = module or Dir.tds_module
    -- For material associated with secondary tools (BibTeX, MakeIndex)
    -- the structure needed is slightly different from those items going
    -- into the tex/doc/source trees
    if (type == "makeindex" or type:match("^bibtex"))
      and Main.module == "base" -- "base" is latex2e specific
    then
      module = "latex"
    end
    local type_module = type .."/".. module
    ---@type table<integer, copy_name_kv>
    local candidates = {}
    -- Generate a candidates list
    -- each candidate is a table
    for glob_list in entries(file_globs) do
      for glob in entries(glob_list) do
        for p in tree(src_dir, glob) do
          local p_src = p.src
          local dir, name = dir_base(p_src)
          local src_path_end = "/"
          local source_dir = src_dir
          if dir ~= "." then
            dir = dir:gsub("^%.", "")
            source_dir = src_dir .. dir
            if not flatten then
              src_path_end = dir .. "/"
            end
          end
          local matched = false
          for location in entries(Vars.tdslocations) do
            local l_dir, l_glob = dir_base(location)
            local glob_match = to_glob_match(l_glob)
            if glob_match(name) then
              append(candidates, {
                name        = name,
                source      = source_dir,
                dest        = root_install_dir .."/".. l_dir .. src_path_end,
                install_dir = root_install_dir .."/".. l_dir, -- for cleanup
              })
              matched = true
              break
            end
          end
          if not matched then
            if glob:match("l3blib") then
              print("NOT MATCHED")
              print(name)
              print(source_dir)
              print(root_install_dir .."/".. type_module .. src_path_end .. src_path_end)
              print(root_install_dir .."/".. type_module .. src_path_end)
            end
            append(candidates, {
              name        = name,
              source      = source_dir,
              dest        = root_install_dir .."/".. type_module .. src_path_end,
              install_dir = root_install_dir .."/".. type_module, -- for cleanup
            })
          end
        end
      end
    end

    error_level = 0
    -- The target is only created if there are actual files to install
    if not_empty(candidates) then
      if dry_run then
        for entry in entries(candidates) do
          print("- " .. entry.dest .. entry.name)
        end
      else
        for entry in entries(candidates) do
          local install_dir = entry.install_dir
          if not already_cleaned[install_dir] then
            error_level = make_clean_directory(install_dir)
            if error_level ~= 0 then
              return error_level
            end
            already_cleaned[install_dir] = true
          end
          append(to_copy, entry)
        end
      end
    end
    return 0
  end

  -- Creates a 'controlled' list of files
  local function create_file_list(dir, includes, excludes)
    dir = dir or Dir.work
    ---@type flag_table_t
    local exclude_list = {}
    for glob_table in entries(excludes) do
      for glob in entries(glob_table) do
        for p in tree(dir, glob) do
          exclude_list[p.src] = true
        end
      end
    end
    ---@type string_list_t
    local result = {}
    for glob in entries(includes) do
      for p in tree(dir, glob) do
        if not exclude_list[p.src] then
          append(result, p.src)
        end
      end
    end
    return result
  end

  if full then
    error_level = doc()
    if error_level ~= 0 then
      return error_level
    end

    -- Set up lists: global as they are also needed to do CTAN releases
    typeset_list = create_file_list(
      Dir.docfile,
      Files.typeset,
      { Files.source }
    )
    local source_list = create_file_list(
      Dir.sourcefile,
      Files.source,
      {
        Files.bst,
        Files.install,
        Files.makeindex
      }
    )
    local source_list_script = create_file_list(
      Dir.sourcefile,
      Files.source,
      { Files.script }
    )
    if dry_run then
      print("\nFor installation inside " .. root_install_dir .. ":")
    end

    error_level =
      feed_to_copy(
        Dir.sourcefile,
        "source",
        { source_list },
        Vars.flattentds,
        Dir.tds_module
      )
    + feed_to_copy(
        Dir.sourcefile,
        "source",
        { source_list_script },
        Vars.flattenscript,
        Dir.tds_module
      )
    + feed_to_copy(
        Dir.docfile,
        "doc", {
          Files.bib,
          Files.demo,
          Files.doc,
          Files._all_pdf, --[[ For the purposes here,
            any typesetting demo files need to be part
            of the main typesetting list]] 
          Files.text,
          typeset_list
        },
        Vars.flattentds,
        Dir.tds_module
      )
    if error_level ~= 0 then
      return error_level
    end

    -- Rename README if necessary
    if not dry_run then
      local readme = Vars.ctanreadme
      if readme ~= "" and not readme:lower():match("^readme%.%w+") then
        local install_dir = root_install_dir .. "/doc/" .. Dir.tds_module
        if file_exists(install_dir .. "/" .. readme) then
          rename(install_dir, readme, "README." .. readme:match("%.(%w+)$"))
        end
      end
    end

    -- Any script man files need special handling
    for glob in entries(Files.scriptman) do -- shallow glob
      for p in tree(Dir.docfile, glob) do
        local p_src = p.src
        local man = "man" .. p_src:match(".$")
        if dry_run then
          print("- doc/man/" .. man .. "/" .. base_name(p_src))
        else
          -- Man files should have a single-digit tail: the type
          local install_dir = root_install_dir .. "/doc/man/"  .. man
          error_level = error_level
            + make_directory(install_dir)
            + copy_file(p_src, Dir.docfile, install_dir)
        end
      end
    end
  end

  local install_list = create_file_list(Dir.unpack, Files.install, { Files.script })

  if error_level ~= 0 then
    return error_level
  end
  error_level =
      feed_to_copy(Dir.unpack, "tex", { install_list }, Vars.flattentds, Dir.tds_module)
    + feed_to_copy(Dir.unpack, "bibtex/bst", { Files.bst }, Vars.flattentds, Main.module)
    + feed_to_copy(Dir.unpack, "makeindex", { Files.makeindex }, Vars.flattentds, Main.module)
    + feed_to_copy(Dir.unpack, "scripts", { Files.script }, Vars.flattenscript, Main.module)

  if error_level ~= 0 then
    return error_level
  end

  -- Files are all copied in one shot: this ensures that cleandir()
  -- can't be an issue even if there are complex set-ups
  for entry in entries(to_copy) do
    error_level = copy_file(entry)
    if error_level ~= 0  then
      return error_level
    end
  end

  return 0
end

local function install()
  local options = l3build.options
  return install_files(Vars.texmf_home, options.full, options["dry-run"])
end

---@class l3b_inst_t
---@field Vars            l3b_inst_vars_t
---@field install_impl    target_impl_t
---@field uninstall_impl  target_impl_t
---@field install_files   fun(root_install_dir: string, full: boolean, dry_run: boolean): integer

return {
  Vars            = Vars,
  install_impl    = {
    run = install
  },
  uninstall_impl  = {
    run = uninstall
  },
  install_files   = install_files,
}
