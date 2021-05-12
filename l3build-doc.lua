--[[

File l3build-doc.lua Copyright (C) 2018-2020 The LaTeX Project

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

--
-- Auxiliary functions for typesetting: need to be generally available
--

local print     = print

local not_empty = next

---@type utlib_t
local utlib       = require("l3b-utillib")
local is_error    = utlib.is_error
local entries     = utlib.entries
local items       = utlib.items

---@type pathlib_t
local pathlib             = require("l3b-pathlib")
local job_name          = pathlib.job_name
local dir_base          = pathlib.dir_base

---@type fslib_t
local fslib             = require("l3b-fslib")
local remove_name       = fslib.remove_name
local copy_file         = fslib.copy_file
local copy_tree         = fslib.copy_tree
local make_clean_directory = fslib.make_clean_directory
local tree              = fslib.tree

--@type l3build_t
local l3build = require("l3build")

---@type l3b_globals_t
local l3b_globals  = require("l3build-globals")
---@type G_t
local G      = l3b_globals.G
---@type Xtn_t
local Xtn       = l3b_globals.Xtn
---@type Dir_t
local Dir       = l3b_globals.Dir
---@type Exe_t
local Exe       = l3b_globals.Exe
---@type Opts_t
local Opts      = l3b_globals.Opts
---@type Files_t
local Files     = l3b_globals.Files
---@type Deps_t
local Deps      = l3b_globals.Deps

--@type l3b_aux_t
local l3b_aux       = require("l3build-aux")
local deps_install  = l3b_aux.deps_install

--@type l3b_unpk_t
local l3b_unpk  = require("l3build-unpack")
local unpack      = l3b_unpk.unpack

---Local helper
---@param file string
---@param dir string
---@return error_level_n
local function typesetpdf(file, dir)
  local name = job_name(file)
  print("Typesetting " .. name)
  ---@type typeset_f
  local func  = G.typeset
  ---@type string
  local cmd   = Exe.typeset .. " " .. Opts.typeset
  local special = G.specialtypesetting[file]
  if special then
    func = special.func or func
    cmd  = special.cmd  or cmd
  end
  local error_level = func(file, dir, cmd)
  if is_error(error_level) then
    print(" ! Compilation failed")
    return error_level
  end
  local name_pdf = name .. Xtn.pdf
  remove_name(Dir.docfile, name_pdf)
  return copy_file(name_pdf, dir, Dir.docfile)
end

---comment
---@return error_level_n
local function docinit()
  -- Set up
  make_clean_directory(Dir.typeset)
  for filetype in items(
    Files.bib, Files.doc, Files.typeset, Files.typesetdemo
  ) do
    copy_tree(filetype, Dir.docfile, Dir.typeset)
  end
  copy_tree(Files.source, Dir.sourcefile, Dir.typeset)
  copy_tree(Files.typesetsupp, Dir.support, Dir.typeset)
  deps_install(Deps.typeset)
  unpack({ Files.source, Files.typesetsource }, { Dir.sourcefile, Dir.docfile })
  -- Main loop for doc creation
  local error_level = G.typeset_demo_tasks()
  if is_error(error_level) then
    return error_level
  end
  return G.docinit_hook()
end

---Typeset all required documents
---Uses a set of dedicated auxiliaries that need to be available to others
---@param files? string[]
---@return error_level_n
local function doc(files)
  local error_level = docinit()
  if is_error(error_level) then
    return error_level
  end
  ---@type flags_t
  local done = {}
  for typeset_globs in items(Files.typesetdemo, Files.typeset) do
    for glob in entries(typeset_globs) do
      for dir_path in items(Dir.typeset, Dir.unpack) do
        for p in tree(dir_path, glob) do
          local src_dir, src_name = dir_base(p.wrk)
          local name = job_name(src_name)
          if not done[name] then
            local should_typeset = true
            -- Allow for command line selection of files
            if files and not_empty(files) then
              should_typeset = false
              for file in entries(files) do
                if name == file then
                  should_typeset = true
                  break
                end
              end
            end
            -- Now know if we should typeset this source
            if should_typeset then
              error_level = typesetpdf(src_name, src_dir)
              if is_error(error_level) then
                return error_level
              end
              done[name] = true
            end
          end
        end
      end
    end
  end
  return 0
end

---@class l3b_doc_t
---@field public doc_impl  target_impl_t
---@field public doc       fun(files?: string[]): error_level_n

return {
  doc_impl  = {
    run = doc,
  },
  doc       = doc,
}
