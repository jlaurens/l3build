#!/usr/bin/env texlua
--[[
  This is a test file for l3build package.
  It is only intended for development and should appear in any distribution of the l3build package.
  For help, run `texlua l3build.lua test -h`
--]]
local pop   = table.remove

local expect = _ENV.expect

local lpeg = require("lpeg")
local P = lpeg.P
local V = lpeg.V

---@type pathlib_t
require("l3b-pathlib")

---@type oslib_t
local oslib = require("l3b-oslib")

---@type l3build_t
local l3build = require("l3build")

---@type l3b_globals_t
local l3b_globals
---@type __l3b_globals_t
local __

l3b_globals, __ = _ENV.loadlib("l3build-globals", _ENV)

local function test_basic()
  expect(l3b_globals).NOT(nil)
end

local test_VariableEntry = {
  setup = function (self)
    self.pre_entry_1 = {
      description = "PRE ENTRY 1",
      value = "PRE VALUE 1",
    }
    self.pre_entry_2 = {
      description = "PRE ENTRY 2",
      index = function (env, k)
        return "PRE INDEX 2(env, ".. k .. ")"
      end,
    }
    self.pre_entry_3 = {
      description = "PRE ENTRY 3",
      complete = function (env, k, result)
        return "PRE COMPLETE 3(env, ".. k .. ", ".. tostring(result) ..")"
      end,
      value = "PRE VALUE 3",
    }
    self.pre_entry_4 = {
      description = "PRE ENTRY 4",
      complete = function (env, k, result)
        return "PRE COMPLETE 4(env, ".. k .. ", ".. tostring(result) ..")"
      end,
      index = function (env, k)
        return "PRE INDEX 4(env, ".. k .. ")"
      end,
    }
    self:push_entries()
  end,
  push_entries = function (self)
    self.old_entry_by_index = {}
    table.move(__.entry_by_index, 1, #__.entry_by_index, 1, self.old_entry_by_index)
    self:clean_entries()
  end,
  clean_entries = function (self)
    while pop(__.entry_by_index) do end
    for k, _ in pairs(__.entry_by_name) do
      __.entry_by_name[k] = nil
    end
  end,
  pop_entries = function (self)
    self:clean_entries()
    local from_t = self.old_entry_by_index
    for _, v in ipairs(from_t) do
      __.entry_by_name[v.name] = v
    end
    table.move(from_t, 1, #from_t, 1, __.entry_by_index)
    self.old_entry_by_index = {}
  end,
  teardown = function (self)
    self:pop_entries()
  end,
  test = function (self)
    local entry_1 = __.VariableEntry(self.pre_entry_1, "entry_1")
    expect(entry_1.name).is("entry_1")
    expect(entry_1.description).is("PRE ENTRY 1")
    expect(entry_1.value).is("PRE VALUE 1")
  end,
  test_declare = function (self)
    __.declare({
      entry_1 = self.pre_entry_1,
      entry_2 = self.pre_entry_2,
      entry_3 = self.pre_entry_3,
      entry_4 = self.pre_entry_4,
    })
    local entry_1 = __.get_entry("entry_1")
    expect(entry_1.name).is("entry_1")
    local entry_2 = __.get_entry("entry_2")
    expect(entry_2.name).is("entry_2")
    local entry_3 = __.get_entry("entry_3")
    expect(entry_3.name).is("entry_3")
    local entry_4 = __.get_entry("entry_4")
    expect(entry_4.name).is("entry_4")
    local G = l3b_globals.G
    expect(G["entry_1"]).is("PRE VALUE 1")
    expect(G["entry_2"]).is("PRE INDEX 2(env, entry_2)")
    expect(G["entry_3"]).is("PRE COMPLETE 3(env, entry_3, PRE VALUE 3)")
    expect(G["entry_4"]).is("PRE COMPLETE 4(env, entry_4, PRE INDEX 4(env, entry_4))")
  end,
}

local test_Dir = {
  test_separator = function (self)
    local Dir = l3b_globals.Dir
    local function test(key)
      local path = Dir[key]
      expect(path:match("/$")).is("/")
      local expected = _ENV.random_string()
      _G[key .."dir"] = expected
      expect(Dir[key]).is("./"..expected.."/")
      _G[key .."dir"] = nil
    end
    test("work")
    test("main")
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
  end,
  test_main = function (self)
    local b = _ENV.random_string()
    local diagnostic = ([[
local l3b_globals = require("l3build-globals")
local Dir = l3b_globals.Dir
print(("%s%%s%s"):format(Dir.main))
]]):format(b,b)
    local maindir = _ENV.make_temporary_dir()
    local module_path = _ENV.create_test_module_ds(maindir, "module", [[
module = "module"
]], diagnostic)
    local expected = module_path / "."
    local function test(path)
      expect(path).NOT(nil)
      local output = oslib.run_process(
        path,
        "texlua ".. l3build.script_path .. " test"
      )
      print("DEBBUUGGG", path, output)
      output = output:match(("%s(.-)%s"):format(b, b)) / "."
      expect(output).match(expected)
    end
    test(module_path)
    local submodule_path = _ENV.create_test_module_ds(module_path, "submodule", [[
module = "submodule"
]], diagnostic)
    test(submodule_path)
    local subsubmodule_path = _ENV.create_test_module_ds(submodule_path, "subsubmodule", [[
module = "subsubmodule"
]], diagnostic)
    -- test(subsubmodule_path)
  end,
}

local test_Files = function ()
  local Files = l3b_globals.Files
  local function test(key)
    expect(Files[key]).type("table")
    local expected = { _ENV.random_string() }
    _G[key.."files"] = expected
    expect(Files[key]).equals(expected)
    _G[key.."files"] = nil
  end
  test("aux")
  test("bib")
  test("binary")
  test("bst")
  test("check")
  test("checksupp")
  test("clean")
  test("demo")
  test("doc")
  test("dynamic")
  test("exclude")
  test("install")
  test("makeindex")
  test("script")
  test("scriptman")
  test("source")
  test("tag")
  test("text")
  test("typesetdemo")
  test("typeset")
  test("typesetsupp")
  test("typesetsource")
  test("unpack")
  test("unpacksupp")
  test("_all_typeset")
  test("_all_pdf")
end

local test_Deps = function ()
  local Deps = l3b_globals.Deps
  local function test(key)
    expect(Deps[key]).type("table")
    local expected = { _ENV.random_string() }
    _G[key.."deps"] = expected
    expect(Deps[key]).equals(expected)
    _G[key.."deps"] = nil
  end
  test("check")
  test("typeset")
  test("unpack")
end

local test_Exe = function ()
  local Exe = l3b_globals.Exe
  local function test(key)
    expect(Exe[key]).type("string")
    local expected = "X" .. _ENV.random_string()
    _G[key.."exe"] = expected
    expect(Exe[key]).equals(expected)
    _G[key.."exe"] = nil
  end
  test("typeset")
  test("unpack")
  test("zip")
  test("biber")
  test("bibtex")
  test("makeindex")
  test("curl")
end

local test_Opts = function ()
  local Opts = l3b_globals.Opts
  local function test(key)
    expect(Opts[key]).type("string")
    local expected = "X" .. _ENV.random_string()
    _G[key.."opts"] = expected
    expect(Opts[key]).equals(expected)
    _G[key.."opts"] = nil
  end
  test("check")
  test("typeset")
  test("unpack")
  test("zip")
  test("biber")
  test("bibtex")
  test("makeindex")
end

local test_Xtn = function ()
  local Xtn = l3b_globals.Xtn
  local function test(key)
    expect(Xtn[key]).type("string")
    local expected = "X" .. _ENV.random_string()
    _G[key.."ext"] = expected
    expect(Xtn[key]).equals(expected)
    _G[key.."ext"] = nil
  end
  test("bak")
  test("dvi")
  test("lvt")
  test("tlg")
  test("tpf")
  test("lve")
  test("log")
  test("pvt")
  test("pdf")
  test("ps")
end

local test_G = {
  setup = function (self)
    self.G = l3b_globals.G
  end,
  teardown = function (self)
    _G.module = nil
  end,
  test_bundle = function (self)
    _G.module = "MY SUPER MODULE"
    expect(self.G.bundle).is("")
  end,
  test_module = function (self)
    -- normally _G.module is read from a build.lua file
    _G.module = "MY SUPER MODULE"
    expect(self.G.module).is("MY SUPER MODULE")
  end,
  test_modules = function (self)
    expect(self.G.modules).equals({})
  end,
  test_checkengines = function (self)
    expect(self.G.checkengines).equals({"pdftex", "xetex", "luatex"})
    self.G.checkengines = nil -- values have ben cached
    local expected = { _ENV.random_string() }
    expect(_G.checkengines).is(nil)
    _G.checkengines = expected
    expect(self.G.checkengines).equals(expected)
    _G.checkengines = nil
  end,
  test_typeset_list = function (self)
    expect(function () print(self.G.typeset_list) end).error()
    _G.typeset_list = { "A", "B", "C" }
    expect(self.G.typeset_list).equals({ "A", "B", "C" })
    _G.typeset_list = nil
  end,
  test_str = function (self)
    local test = function (key)
      expect(self.G[key]).type("string")
      local expected = _ENV.random_string()
      _G[key] = expected
      expect(self.G[key]).equals(expected)
      _G[key] = nil
    end
    _G.module = "MY SUPER MODULE"
    test('ctanpkg')
    test('tdsroot')
    test('ctanzip')
    test('ctanreadme')
    test('glossarystyle')
    test('indexstyle')
    test('typesetcmds')
    test('stdengine')
    test('checkformat')
    test('ps2pdfopt')
    test('manifestfile')
  end,
  test_boolean = function (self)
    local test = function (key)
      expect(self.G[key]).type("boolean")
      local expected = true
      _G[key] = expected
      expect(self.G[key]).equals(expected)
      expected = not expected
      _G[key] = expected
      expect(self.G[key]).equals(expected)
      _G[key] = nil
    end
    test('flattentds')
    test('flattenscript')
    test('ctanupload')
    test('typesetsearch')
    test('recordstatus')
    test('forcecheckepoch')
    test('checksearch')
    test('unpacksearch')
    test('flatten')
    test('packtdszip')
    test('curl_debug')
  end,
  test_number = function (self)
    local test = function (key)
      expect(self.G[key]).type("number")
      local expected = _ENV.random_number()
      _G[key] = expected
      expect(self.G[key]).equals(expected)
      _G[key] = nil
    end
    test('epoch')
    test('typesetruns')
    test('checkruns')
    test('maxprintline')
  end,
  test_function = function (self)
    local test = function (key)
      expect(self.G[key]).type("function")
      local expected = function () end
      _G[key] = expected
      expect(self.G[key]).equals(expected)
      _G[key] = nil
    end
    test("runcmd")
    test("biber")
    test("bibtex")
    test("makeindex")
    test("tex")
    test("typeset")
    test("typeset_demo_tasks")
    test("docinit_hook")
    test("runtest_tasks")
    test("checkinit_hook")
    test("bundleunpack")
    test("tag_hook")
    test("update_tag")
  end,
  test_table = function (self)
    local test = function (key)
      expect(self.G[key]).type("table")
      local expected = { _ENV.random_string() }
      _G[key] = expected
      expect(self.G[key]).equals(expected)
      _G[key] = nil
    end
    test('exclmodules')
    test('tdslocations')
    test('test_order')
    test('includetests')
    test('excludetests')
    test('asciiengines')
    test("specialtypesetting")
    test('specialformats')
    test('test_types')
    test('checkconfigs')
    test('uploadconfig')
  end,
}

local test__uploadconfig = {
  setup = function (self)
    self.G = l3b_globals.G
  end,
  test = function (self)
    local uploadconfig = self.G.uploadconfig
    expect(uploadconfig).NOT(nil)
    expect(uploadconfig).equals({})
  end,
}

local test__G = {
  setup = function (self)
    self.G = l3b_globals.G
  end,
  teardown = function (self)
    _G.module = nil
  end,
  test_texmf_home = function (self)
    expect(self.G.texmf_home:match("texmf")).is("texmf")
    require("l3build").options.texmfhome = "FOO"
    expect(self.G.texmf_home).is("FOO")
  end,
  test_is = function (self)
    _G.module = "MY SUPER MODULE"
    expect(self.G.is_embedded).type("boolean")
    expect(self.G.is_standalone).type("boolean")
    expect(self.G.at_bundle_top).type("boolean")
  end,
  test_at_top = function (self)
    expect(self.G.at_top).type("boolean")
  end,
  test_str = function (self)
    local function test(key)
      expect(self.G[key]).type("string")
      local expected = "X" .. _ENV.random_string()
      _G[key] = expected
      expect(self.G[key]).equals(expected)
      _G[key] = nil
    end
    test("config")
    _G.module = "MY SUPER MODULE"
    test("tds_module")
    test("tds_main")
  end,
}

local test_main_variable = {
  setup = function (self)
    self.anchor = __.get_main_variable_anchor
    local name = _ENV.random_string():sub(1, 10)
    local filler = ("X"):rep(10 - #name)
    self.name = filler .. name
    self.name_wrap = self:wrap("NAME",  self.name ) -- 30 bytes
    self.value = self.name .. _ENV.random_text(30)  -- 40 bytes
    self.value_wrap = self:wrap("VALUE", self.value)-- 60 bytes
    local content = ("%s%s%s%s%s"):format(
      _ENV.random_text(30),
      self.name_wrap, -- 30 bytes
      _ENV.random_text(30),
      self.value_wrap, -- 60 bytes
      _ENV.random_text(30)
    ) -- 180 bytes
    self.variable_wrap = ("%s%s%s"):format(
      _ENV.random_text(30),
      self:wrap("VARIABLE", content),
      _ENV.random_text(30)
    ) -- 240 bytes
  end,
  wrap = function (self, TAG, content)
    return ("%s%s%s"):format(
      self.anchor["B_"..TAG],
      content,
      self.anchor["E_"..TAG]
    )
  end,
  test_gmr_name = function (self)
    local gmr = __.get_main_variable_gmr(self.anchor)
    gmr[1] = V("name")
    local p = P(gmr)
    expect(p:match(self.name_wrap)).is(self.name)
    expect(p:match(self.variable_wrap)).is(nil)
    gmr[1] = V(".*name")
    p = P(gmr)
    expect(p:match(self.name_wrap)).is(self.name)
    expect(p:match(self.variable_wrap)).is(self.name)
  end,
  test_gmr_value = function (self)
    local gmr = __.get_main_variable_gmr(self.anchor)
    gmr[1] = V("value")
    local p = P(gmr)
    expect(p:match(self.value_wrap)).is(self.value)
    expect(p:match(self.variable_wrap)).is(nil)
    gmr[1] = V(".*value")
    p = P(gmr)
    expect(p:match(self.value_wrap)).is(self.value)
    expect(p:match(self.variable_wrap)).is(self.value)
  end,
  test_gmr_full = function (self)
    local gmr = __.get_main_variable_gmr(self.anchor)
    local p = P(gmr)
    local k, v = p:match(self.variable_wrap)
    expect(k).is(self.name)
    expect(v).is(self.value)
  end,
}

return {
  test_basic          = test_basic,
  test_VariableEntry  = test_VariableEntry,
  test_Dir            = test_Dir,
  test_Files          = test_Files,
  test_Deps           = test_Deps,
  test_Exe            = test_Exe,
  test_Opts           = test_Opts,
  test_Xtn            = test_Xtn,
  test__uploadconfig  = test__uploadconfig,
  test_G              = test_G,
  test__G             = test__G,
  test_main_variable  = test_main_variable
}
