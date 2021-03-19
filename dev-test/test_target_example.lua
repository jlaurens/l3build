#!/usr/bin/env texlua

local lfs = require("lfs")

local main_dir = lfs.currentdir()
local examples_dir

local function execute(cmd)
  local f = assert(io.popen(cmd, "r"))
  local s = assert(f:read("a"))
  f:close()
  return s
end

while true do
  examples_dir = main_dir .."/examples"
  if lfs.attributes(examples_dir, "mode") then
    break
  end
  main_dir = main_dir:match("(.*)/[^/]+")
  if not main_dir then
    error("No examples folder available")
  end
end

lfs.chdir(examples_dir)
for example in lfs.dir(examples_dir) do
  local exemple_dir = examples_dir .."/".. example
  local build = exemple_dir .."/build.lua"
  if  example ~= "."
  and example ~= ".."
  and lfs.attributes(build, "mode")
  then
    print("Testing example ".. example)
    lfs.chdir(example)
    for _, target in ipairs({
      "help",
      "status --debug", --    Display status informations
      "doc    --debug", --       Typesets all documentation files
      "save   --debug *", --      Saves test validation log
      "check  --debug", --     Run all automated tests
      "clean  --debug", --     Clean out directory tree
      "unpack --debug", --    Unpacks the source files into the build tree
      "manifest --debug", --  Creates a manifest file
      "install  --debug", --   Installs files into the local texmf tree
      "uninstall --debug", -- Uninstalls files from the local texmf tree
      "tag  --debug", --       Updates release tags in files
      "ctan --debug", --      Create CTAN-ready archive
      -- "upload", --    Send archive to CTAN for public release
    }) do
      local cmd = "texlua ../../l3build.lua ".. target
      local s = execute(cmd)
      print("Executing ".. cmd)
      print(s)
      local msg = s:match("attempt to index a nil value")
      if msg then
        error(msg)
      end
      msg = s:match("attempt to call a nil value")
      if msg then
        error(msg)
      end
      msg = s:match("attempt to concatenate a nil value")
      if msg then
        error(msg)
      end
      msg = s:match("%(local '%S+'%)")
      if msg then
        error(msg)
      end
      
      print("Done")
    end
    lfs.chdir("..")
  end
end
