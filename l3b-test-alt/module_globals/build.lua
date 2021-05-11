#!/usr/bin/env texlua

module = "module_for_globals"

function _G.feed_build_string_for_testing(key)
  return '/foo/bar/'.. key ..'/'
end

local function test(key)
  _G[key .. "dir"] = _G.feed_build_string_for_testing(key)
end
-- test("work")
-- test("main")
test("docfile")
test("sourcefile")
test("support")
test("testfile")
test("testsupp")
test("texmf")
test("textfile")
test("build")
test("distrib")
test("local")
test("result")
test("test")
test("typeset")
test("unpack")
test("ctan")
test("tds")
