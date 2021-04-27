#!/usr/bin/env texlua

local append = table.insert

local expect  = require("l3b-test/expect").expect

local DocManager  = require("l3b-doc-manager")

function _G.test_initialize()
  expect(DocManager).NOT(nil)
  local dm = DocManager("THE PATH")
  expect(dm.work_path).is("THE PATH")
end

function _G.test_modules ()
  local dm = DocManager()
  dm.__modules = { "a", "b", "c" }
  local t = {}
  for m in dm.all_modules do
    append(t, m)
  end
  expect(t).equals(dm.__modules)
end