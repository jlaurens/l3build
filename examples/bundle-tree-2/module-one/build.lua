#!/usr/bin/env texlua

sourcefiledir = "code"
docfiledir    = "doc"
typesetfiles  = { "*.dtx", "*.tex" }
packtdszip    = true -- recommended for "tree" layouts

if options.debug then
  print("DEBUG: module-one build.lua executed")
  print("- bundle: ".. bundle)
  print("- module: ".. module)
end
