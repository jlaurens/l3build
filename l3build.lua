#!/usr/bin/env texlua

--[[

File l3build.lua Copyright (C) 2014-2020 The LaTeX3 Project

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

-- Version information
release_date = "2020-06-04"

-- Local access to functions

local lookup           = kpse.lookup
local match            = string.match

-- l3build setup and functions
kpse.set_program_name("kpsewhich")
local build_kpse_path = match(lookup("l3build.lua"),"(.*[/])")
function build_require(s)
  return require(lookup("l3build-"..s..".lua", { path = build_kpse_path } ) )
end

-- Minimal code to do basic checks
local arguments = build_require("arguments")
options = arguments.parse(arg)
option_list = arguments.option_list

local std = build_require("stdmain")

std.do_help(_ENV)

std.setup(_ENV, arg[0])

-- Load standard settings for variables:
-- comes after any user versions
build_require("variables")

std.check_env(_ENV)
std.do_multi_check(_ENV)
-- Call the main function
if main then
  main(options["target"], options["names"])
else
  std.main(_ENV)
end
