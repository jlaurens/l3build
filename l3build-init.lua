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

-- Local safe guard

local lookup           = kpse.lookup
local match            = string.match
local print            = print
local exit             = os.exit

-- global tables

Args = {
  __KEY__ = "arguments"
}
Aux = {
  __KEY__ = "aux"
}
Chk = {
  __KEY__ = "check"
}
Cln = {
  __KEY__ = "clean"
}
CTAN = {
  __KEY__ = "ctan"
}
FS = {
  __KEY__ = "file_functions"
}
Ins = {
  __KEY__ = "install"
}
MNSU = {
  __KEY__ = "manifest-setup"
}
Mfst = {
  __KEY__ = "manifest"
}
OS = {
  __KEY__ = "os"
}
Main = {
  __KEY__ = "stdmain"
}
Tag = {
  __KEY__ = "tagging"
}
Tpst = {
  __KEY__ = "typesetting"
}
Pack = {
  __KEY__ = "unpack"
}
Upld = {
  __KEY__ = "upload"
}
Vars = {
  __KEY__ = "variables"
}
Pack = {
  __KEY__ = "unpack"
}

-- Main utilities

-- l3build setup and functions
kpse.set_program_name("kpsewhich")
local build_kpse_path = lookup("l3build.lua"):match("(.*[/])")

Require = function (M)
  if M.___ then
    require(lookup(""..M.___..".lua", { path = build_kpse_path } ) )
  else
    return assert(#M) and M
  end
end

Provide = function (M)
  if M then
    M.___ = nil
    return M
  end
  return {}
end

function CleanGlobalFootprint ()
  CleanGlobalFootprint = nil
  Require = nil
  Provide = nil
  Args = nil
  Aux = nil
  Chk = nil
  Cln = nil
  CTAN = nil
  FS = nil
  Ins = nil
  MNSU = nil
  Mfst = nil
  OS = nil
  Main = nil
  Tag = nil
  Tpst = nil
  Pack = nil
  Upld = nil
  Vars = nil
  Pack = nil
end