#!/usr/bin/env texlua

bundle = "bundle-tree-2"

packtdszip = true

if options.debug then
  print("DEBUG: top build.lua executed")
  print("- bundle: ".. bundle)
  print("- module: ".. module)
end
