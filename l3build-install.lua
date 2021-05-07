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

local push   = table.insert

---@type pathlib_t
local pathlib      = require("l3b-pathlib")
local path_matcher = pathlib.path_matcher
local dir_base        = pathlib.dir_base
local base_name       = pathlib.base_name
local dir_name        = pathlib.dir_name

---@type utlib_t
local utlib       = require("l3b-utillib")
local entries     = utlib.entries

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

---@type l3b_globals_t
local l3b_globals  = require("l3build-globals")
---@type G_t
local G         = l3b_globals.G
---@type Dir_t
local Dir       = l3b_globals.Dir
---@type Files_t
local Files     = l3b_globals.Files
local get_global_variable_entry = l3b_globals.get_entry

---@type l3b_unpk_t
local l3b_unpk  = require("l3build-unpack")
local unpack    = l3b_unpk.unpack

---@type l3b_doc_t
local l3b_doc  = require("l3build-doc")
local doc       = l3b_doc.doc

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
      local install_dir = G.texmf_home .. "/doc/man/"  .. man
      if file_exists(install_dir / p_src) then
        if dry_run then
          push(man_files, man / base_name(p_src))
        else
          error_level = error_level + remove_tree(install_dir, p_src)
        end
      end
    end
  end
  if not_empty(man_files) then
    print("\n" .. "For removal from " .. G.texmf_home .. "/doc/man:")
    for v in entries(man_files) do
      print("- " .. v)
    end
  end
  local zap_dir = dry_run
    and function (dir)
      local install_dir = G.texmf_home / dir
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
      local install_dir = G.texmf_home / dir
      if directory_exists(install_dir) then
        return remove_directory(install_dir)
      end
      return 0
    end
  error_level = zap_dir("doc/"        .. G.tds_module)
              + zap_dir("source/"     .. G.tds_module)
              + zap_dir("tex/"        .. G.tds_module)
              + zap_dir("bibtex/bst/" .. G.module)
              + zap_dir("makeindex/"  .. G.module)
              + zap_dir("scripts/"    .. G.module)
              + error_level
  if error_level ~= 0 then
    return error_level
  end
  -- Finally, clean up special locations
  for location in entries(G.tdslocations) do
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
---@param full boolean, @true means with documentation and man pages
---@param dry_run boolean
---@return error_level_n
local function install_files(root_install_dir, full, dry_run)

  local error_level = unpack()
  if error_level ~= 0 then
    return error_level
  end

    -- Needed so paths are only cleaned out once
  ---@type flags_t
  local already_cleaned = {}

  -- Collect up all file entries before copying:
  -- ensures no files are lost during clean-up
  ---@type copy_name_kv_t[]
  local to_copy = {}

  local function feed_to_copy(src_dir, type, file_globs, flatten, module)
    -- For material associated with secondary tools (BibTeX, MakeIndex)
    -- the structure needed is slightly different from those items going
    -- into the tex/doc/source trees
    if (type == "makeindex" or type:match("^bibtex"))
      and G.module == "base" -- "base" is latex2e specific
    then
      module = "latex"
    end
    local type_module = type / module
    ---@type copy_name_kv_t[]
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
              src_path_end = dir / ""
            end
          end
          local matched = false
          for location in entries(G.tdslocations) do
            local l_dir, l_glob = dir_base(location)
            local glob_match = path_matcher(l_glob)
            if glob_match(name) then
              push(candidates, {
                name        = name,
                source      = source_dir,
                dest        = root_install_dir / l_dir .. src_path_end,
                install_dir = root_install_dir / l_dir, -- for cleanup
              })
              matched = true
              break
            end
          end
          if not matched then
            local p = type_module .. src_path_end
            if glob:match("l3blib") then
              print("NOT MATCHED")
              print(name)
              print(source_dir)
              print(root_install_dir / (p .. src_path_end) )
              print(root_install_dir / p)
            end
            push(candidates, {
              name        = name,
              source      = source_dir,
              dest        = root_install_dir / p,
              install_dir = root_install_dir / type_module, -- for cleanup
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
          push(to_copy, entry)
        end
      end
    end
    return 0
  end

  -- Creates a 'controlled' list of files
  local function create_file_list(dir, includes, excludes)
    dir = dir or Dir.work
    ---@type flags_t
    local exclude_list = {}
    for glob_table in entries(excludes) do
      for glob in entries(glob_table) do
        for p in tree(dir, glob) do
          exclude_list[p.src] = true
        end
      end
    end
    ---@type string[]
    local result = {}
    for glob in entries(includes) do
      for p in tree(dir, glob) do
        if not exclude_list[p.src] then
          push(result, p.src)
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
    G.typeset_list = create_file_list(
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
        G.flattentds,
        G.tds_module
      )
    + feed_to_copy(
        Dir.sourcefile,
        "source",
        { source_list_script },
        G.flattenscript,
        G.tds_module
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
          G.typeset_list
        },
        G.flattentds,
        G.tds_module
      )
    if error_level ~= 0 then
      return error_level
    end

    -- Rename README if necessary
    if not dry_run then
      local readme = G.ctanreadme
      if readme ~= "" and not readme:lower():match("^readme%.%w+") then
        local install_dir = root_install_dir .. "/doc/" .. G.tds_module
        if file_exists(install_dir / readme) then
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
          print("- doc/man/" .. man / base_name(p_src))
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
      feed_to_copy(Dir.unpack, "tex",        { install_list },    G.flattentds,    G.tds_module)
    + feed_to_copy(Dir.unpack, "bibtex/bst", { Files.bst },       G.flattentds,    G.module)
    + feed_to_copy(Dir.unpack, "makeindex",  { Files.makeindex }, G.flattentds,    G.module)
    + feed_to_copy(Dir.unpack, "scripts",    { Files.script },    G.flattenscript, G.module)

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
  return install_files(G.texmf_home, options.full, options["dry-run"])
end

do
  ---@type variable_entry_t
  local entry = get_global_variable_entry("install_files")
  entry.value = install_files
end

---@class l3b_inst_t
---@field public install_impl    target_impl_t
---@field public uninstall_impl  target_impl_t
---@field public install_files   fun(root_install_dir: string, full: boolean, dry_run: boolean): integer

return {
  install_impl    = {
    run = install
  },
  uninstall_impl  = {
    run = uninstall
  },
  install_files   = install_files,
}
