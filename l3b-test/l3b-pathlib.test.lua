--[[

File l3b-pathlib.lua Copyright (C) 2018-2020 The LaTeX Project

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

--[=[ Presentation
Basic path utilities.
--]=]
---@module pathlib

-- local safety guards and shortcuts

local append = table.insert

local standard_print = print
local current_print = standard_print -- can be changed
_G.print = function (...)
  current_print(...)
end

---@type pathlib_t
local pathlib = require("l3b-pathlib")

-- Next is an _ENV that will allow a module to export
-- more symbols than usually done in order to finegrain testing
local __ = setmetatable({
  during_unit_testing = true,
}, {
  __index = _G
})

local l3build = require("l3build")

local PATHLIB_NAME = "l3b-pathlib"
local PATHLIB_PATH = l3build.work_dir .."l3b/".. PATHLIB_NAME ..".lua"
local pathlib = loadfile(
  PATHLIB_PATH,
  "t",
  __
)()

local expect  = require("l3b-test/expect").expect

local Path = __.Path
expect(Path).NOT(nil)

local lpeg = require("lpeg")
local C   = lpeg.C
local Ct  = lpeg.Ct
local Cmt = lpeg.Cmt
local P   = lpeg.P

function _G.test_Path()
  local p = Path("")
  expect(p).equals(Path())
  expect(p).equals(Path({
    is_absolute = false,
    down        = {},
    up          = {},
  }))
  expect(p.as_string).is("")
  local function test(str, down, normalized)
    local p = Path(str)
    expect(p).equals(Path({
      down        = down,
    }))
    expect(p.as_string).is(normalized or str)
    return
  end
  test("a", { "a" })
  test("a/", { "a", "" })
  test("a/b", { "a", "b" })
  test("a///b", { "a", "b" }, "a/b")
  test("a/./b", { "a", "b" }, "a/b")
  test("a//./b", { "a", "b" }, "a/b")
  test("a/.//b", { "a", "b" }, "a/b")
  test("a//.//b", { "a", "b" }, "a/b")
  test("a//././b", { "a", "b" }, "a/b")
  test("a/././/b", { "a", "b" }, "a/b")
  test("a/./././b", { "a", "b" }, "a/b")

  p = Path("/")
  expect(p).equals(Path({
    is_absolute = true,
  }))
  expect(p.as_string).is("/")
  p = Path("/a")
  expect(p).equals(Path({
    is_absolute = true,
    down = { "a" },
  }))
  expect(p.as_string).is("/a")
  p = Path("/a/b")
  expect(p).equals(Path({
    is_absolute = true,
    down = { "a", "b" },
  }))
  expect(p.as_string).is("/a/b")
  expect(function ()
    Path("/..")
  end).error()
  p = Path("..")
  expect(p).equals(Path({
    up = { ".." },
  }))
  expect(p.as_string).is("..")
  p = Path("../..")
  expect(p).equals(Path({
    up = { "..", ".." },
  }))
  expect(p.as_string).is("../..")
  p = Path("a/..")
  expect(p).equals(Path())
  expect(p.as_string).is("")
  p = Path("a/b/..")
  expect(p).equals(Path({
    down = { "a" },
  }))
  expect(p.as_string).is("a")
end

function _G.test_Path_forward_slash()
  local function test(l, r, lr)
    local actual = Path(l) / Path(r)
    local expected = Path(lr)
    expect(actual).equals(expected)
  end
  test("", "", "/")
  test("a", "", "a/")
  test("", "a", "/a")
  test("a", "b", "a/b")
end

_G.test_POC_parts = function ()
  local p = ( P("/.")^0 * P("/") )^1
  expect(p:match("/")).is(2)
  expect(p:match("//")).is(3)
  expect(p:match("/./")).is(4)
  expect(p:match("/.//")).is(5)
  expect(p:match("//./")).is(5)
  expect(p:match("//.//")).is(6)
  expect(p:match("/././/")).is(7)
  expect(p:match("/.//./")).is(7)
  expect(p:match("//././")).is(7)
  expect(p:match("/./././")).is(8)
end

_G.test_string_forward_slash = function ()
  expect("" / "").is("/")
  expect("a" / "").is("a/")
  expect("a" / "b").is("a/b")
  expect("a/" / "b").is("a/b")
  expect(function () print("a" / "/b") end).error()
  expect("/" / "").is("/")
  expect("" / "/").is("/")
  expect("/" / "/").is("/")
  expect("a" / "..").is("")
  expect("a" / "../").is("")
  expect("/a" / "..").is("/")
  expect("/a" / "../").is("/")
  expect(function () print("/a" / "../..") end).error()
end

function _G.test_dir_name()
  local dir_name = pathlib.dir_name
  expect(dir_name("")).is(".")
  expect(dir_name("abc")).is(".")
  expect(dir_name("a/c")).is("a")
  expect(dir_name("/a/c")).is("/a")
  expect(dir_name("..")).is(".")
  expect(dir_name("../..")).is("..")
end

function _G.test_base_name()
  local base_name = pathlib.base_name
  expect(base_name("")).is("")
  expect(base_name("abc")).is("abc")
  expect(base_name("a/c")).is("c")
  expect(base_name("..")).is("..")
  expect(base_name("../..")).is("..")
end

function _G.test_core_name()
  local core_name = pathlib.core_name
  expect(core_name("")).is("")
  expect(core_name("abc.d")).is("abc")
  expect(core_name("a/c.d")).is("c")
  expect(core_name("a/.d")).is("")
  expect(core_name("..")).is(".")
  expect(core_name("../..")).is(".")
end

function _G.test_extension()
  local extension = pathlib.extension
  expect(extension("")).is(nil)
  expect(extension("abc.d")).is("d")
  expect(extension("a/c.d")).is("d")
  expect(extension("a/.d")).is("d")
  expect(extension("..")).is(nil)
end


