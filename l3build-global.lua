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

local pairs   = pairs
local exit    = os.exit
local execute = os.execute
local stderr  = io.stderr
local lookup  = kpse.lookup

-- l3build setup and functions

kpse.set_program_name("kpsewhich")
local root_path = lookup("l3build.lua"):match("(.*[/])")

-- the unique global

L3B = {
  _TYPE = 'module', 
  _NAME = 'L3B',
  _VERSION = '2021-01-17',
  -- known submodules, uppercase first letter.
  OS   = { key__ = "os" }, -- used to load the module when required
  FS   = { key__ = "file_functions" },
  Args = { key__ = "arguments" },
  Vars = { key__ = "variables" },
  Aux  = { key__ = "aux" },
  Chk  = { key__ = "check" },
  Cln  = { key__ = "clean" },
  CTAN = { key__ = "ctan" },
  Ins  = { key__ = "install" },
  MNSU = { key__ = "manifest-setup" },
  Mfst = { key__ = "manifest" },
  Tag  = { key__ = "tagging" },
  Tpst = { key__ = "typesetting" },
  Upck = { key__ = "unpack" },
  Upld = { key__ = "upload" },
  Main = { key__ = "stdmain" },
  ---Require a module, loads it when necessary
  ---@param key string One of the known module keys.
  ---@return table
  require = function (key)
    local M = L3B[key]
    assert(M, 'Unknown module key')
    assert(not M.locked__, 'Circular references')
    key = M.key__
    if key then
      M.lock__ = true -- reentrant
      require(lookup("" .. key .. ".lua", { path = root_path } ) )
      M.lock__ = nil
    end
    return assert(#M) and M
  end,
  ---Provides a module
  ---@param key string One of the known module keys.
  ---@return table
  provide = function (key)
    local M = L3B[key]
    assert(M, 'Unknown module key')
    M.key__ = nil
    return M
  end,
  ---Expose `t` into `env`: merge `t.exposition` into `env`.
  ---@param t table
  ---@param env table
  expose = function (t, env)
    for k, v in t.exposition or {} do
      env[k] = v
    end
  end,
  ---Set global variables to nil.
  ---Record the symbols before.
  unexpose = function ()
    _ENV.L3B = nil
  end,
  ---Get the module keys.
  ---@return table
  get_module_keys = function ()
    local ans = {}
    for _, v in pairs(L3B) do
      if v[1] == v[1]:uppercase() then
        ans[#ans+1] = v
      end
    end
    return ans
  end,
  ---Display the message.
  ---@param msg string Formatted message
  ---@param nil ...
  info = function (msg, ...)
    stderr:write('Info: ', msg:format(...), '\n')
  end,
  ---Display the message.
  ---@param msg string Formatted message
  ---@param nil ...
  warning = function (msg, ...)
    stderr:write('Info: ', msg:format(...), '\n')
  end,
  ---Display the message and exit with the given code when not 0.
  ---@param code number Optional, defaults to 0.
  ---@param msg string Formatted message
  ---@param nil ...
  error = function (code, msg, ...)
    if type(code) == "string" then
      stderr:write('Error: ', code:format(msg, ...), '\n')
    else
      stderr:write('Error: ', msg:format(...), '\n')
      if code then
        exit(code) -- also print code to the console ?
      end
    end
  end,
  execute = function (cmd, ...)
    local n = execute(cmd.format(...))
    return n ~= 0 and n or nil
  end,
}

Opts = {}
