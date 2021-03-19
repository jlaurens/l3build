#!/usr/bin/env texlua

sourcefiledir = "code"
docfiledir    = "doc"
typesetfiles  = { "*.dtx", "*.tex" }
packtdszip    = true -- recommended for "tree" layouts

if options.debug then
  print("build.lua, module-one")
end
