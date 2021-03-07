#!/usr/bin/env texlua

--[[

File l3build-globales.lua Copyright (C) 2014-2020 The LaTeX Project

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

--[=[
This modules populates the global space with variables.
They all are described in `l3build.dtx`.

It is the responsability of `l3build.dtx` contributors to ensure
that all global variables referenced there are defined in that file.

This file is `dofile`d just before `options.lua` and `build.lua`
are `dofile`d such that both inherit all the global variables
defined here.
--]=]

-- Global variables

-- utility functions

---@type utlib_t
local utlib = require("l3b.utillib")
local items = utlib.items

---@type wklib_t
local wklib = require("l3b.walklib")

---@type oslib_t
local oslib = require("l3b.oslib")

---@type gblib_t
local gblib = require("l3b.globlib")

---@type fslib_t
local fslib = require("l3b.fslib")

_G.abspath        = fslib.absolute_path
_G.dirname        = wklib.dir_name
_G.basename       = wklib.base_name
_G.cleandir       = fslib.make_clean_directory
_G.cp             = fslib.copy_tree
_G.direxists      = fslib.directory_exists
_G.fileexists     = fslib.file_exists
_G.filelist       = fslib.file_list
_G.glob_to_pattern = gblib.glob_to_pattern
_G.to_glob_match  = gblib.to_glob_match
_G.jobname        = wklib.job_name
_G.mkdir          = fslib.make_directory
_G.ren            = fslib.rename
_G.rm             = fslib.remove_tree
_G.run            = oslib.run
_G.splitpath      = wklib.dir_name
_G.normalize_path = fslib.to_host

-- System dependent strings
--X os_concat
--X os_null
--X os_pathsep
--X os_setenv

local l3build = require("l3build")

--components of l3build
if l3build.in_document then
  for k in items(
    "call", "install_files", "biber", "makeindex", "tex", "runcmd"
  ) do
    if not _G[k] then
      -- only provide a global when not available
      -- `tex` is a table defined by luatex
      _G[k] = function ()
        error(k .." is not available in document mode.")
      end
    end
  end
  return
end

---@type l3b_aux_t
local l3b_aux = require("l3b.aux")

_G.call = l3b_aux.call

---@type l3b_install_t
local l3b_install = require("l3b.install")

_G.install_files = l3b_install.install_files

-- typesetting functions

---@type l3b_typesetting_t
local l3b_typesetting = require("l3b.typesetting")

_G.biber      = l3b_typesetting.biber
_G.bibtex     = l3b_typesetting.bibtex
_G.makeindex  = l3b_typesetting.makeindex
_G.tex        = l3b_typesetting.tex

_G.runcmd = l3b_typesetting.runcmd
