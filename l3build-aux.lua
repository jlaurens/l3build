--[[

File l3build-aux.lua Copyright (C) 2018-2020 The LaTeX3 Project

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

-- local safe guards

local pairs  = pairs
local ipairs = ipairs
local print  = print
local lookup = kpse.lookup

-- global tables

local OS = Require(OS)
local Opts = Require(Opts)
local Args = Require(Args)

local Aux = Provide(Aux)

--
-- Auxiliary functions which are used by more than one main function
--

function Aux.setepoch(epoch)
  return
    OS.setenv .. " SOURCE_DATE_EPOCH=" .. epoch
      .. OS.concat ..
    OS.setenv .. " SOURCE_DATE_EPOCH_TEX_PRIMITIVES=1"
      .. OS.concat ..
    OS.setenv .. " FORCE_SOURCE_DATE=1"
      .. OS.concat
end

local function getscriptname(arg_0)
  if arg_0:match("l3build$") or arg_0:match("l3build%.lua$") then
    return lookup("l3build.lua")
  else
    return arg_0
  end
end

-- Do some subtarget for all modules in a bundle
function Aux.call(dirs, target, opts)
  -- Turn the option table into a string
  local opts = opts or Opts
  local s = ""
  for k, v in pairs(opts) do
    if k ~= "names" and k ~= "target" then -- Special cases
      local t = Args.option_list[k] or {}
      local arg = ""
      if t["type"] == "string" then
        arg = arg .. "=" .. v
      end
      if t["type"] == "table" then
        for _, a in pairs(v) do
          if arg == "" then
            arg = "=" .. a -- Add the initial "=" here
          else
            arg = arg .. "," .. a
          end
        end
      end
      s = s .. " --" .. k .. arg
    end
  end
  if opts["names"] then
    for _, v in pairs(opts["names"]) do
      s = s .. " " .. v
    end
  end
  local scriptname = getscriptname(Args.arg[0])
  for _, i in ipairs(dirs) do
    local text = " for module " .. i
    if i == "." and opts["config"] then
      text = " with configuration " .. opts["config"][1]
    end
    print("Running l3build with target \"" .. target .. "\"" .. text )
    local errorlevel = OS.run(
      i,
      "texlua " .. scriptname .. " " .. target .. s
    )
    if errorlevel ~= 0 then
      return errorlevel
    end
  end
  return 0
end

-- Unpack files needed to support testing/typesetting/unpacking
function Aux.depinstall(deps)
  local errorlevel
  for _, i in ipairs(deps) do
    print("Installing dependency: " .. i)
    errorlevel = OS.run(i, "texlua " .. getscriptname(Args.arg[0]) .. " unpack -q")
    if errorlevel ~= 0 then
      return errorlevel
    end
  end
  return 0
end
