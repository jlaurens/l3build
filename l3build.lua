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

-- Local safe guard

local lookup           = kpse.lookup
local match            = string.match
local print            = print
local exit             = os.exit

-- global tables

OS = {} -- os related
FS = {} -- file system related
Vars = {}
Args = {}
Ins = {}
Chk = {}
CTAN = {}
Pack = {}
Main = {}

-- Main utilities

Require = function (M)
  return assert(#M) and M
end

Provide = function (M)
  return M or {}
end

-- l3build setup and functions
kpse.set_program_name("kpsewhich")
local build_kpse_path = match(lookup("l3build.lua"),"(.*[/])")
local function build_require(s)
  return require(lookup("l3build-"..s..".lua", { path = build_kpse_path } ) )
end

-- Minimal code to do basic checks

build_require("arguments")
Opts = Args.argparse(arg)

build_require("os")
build_require("file-functions")
build_require("variables")

build_require("typesetting")
build_require("aux")

build_require("clean")
build_require("check")
build_require("ctan")
build_require("install")
build_require("unpack")
build_require("manifest")
build_require("manifest-setup")
build_require("tagging")
build_require("upload")
build_require("stdmain")

-- This has to come after stdmain(),
-- and that has to come after the functions are defined
if Opts.target == "help" then
  Main.help(arg[0])
  exit(0)
elseif Opts.target == "version" then
  Main.version()
  exit(0)
end

-- Allow main function to be disabled 'higher up'

-- Load configuration file if running as a script
-- start by exposing globals
OS.expose()
FS.expose()

local M = Main
local O = Opts

if arg[0]:match("l3build$") or arg[0]:match("l3build%.lua$") then
  -- Look for some configuration details
  if FS.fileexists("build.lua") then
    dofile("build.lua")
  else
    print("Error: Cannot find configuration build.lua")
    exit(1)
  end
end

-- Call the main function
M.preflight()
M.main(O.target, O.names)
