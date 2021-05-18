#!/usr/bin/env texlua
--[[
  This is a test file for l3build package.
  It is only intended for development and should appear in any distribution of the l3build package.
  For help, run `texlua l3build.lua test -h`
--]]

local concat  = table.concat
local push    = table.insert

---@type pathlib_t
local pathlib = require("l3b-pathlib")
local dir_base = pathlib.dir_base

---@type modlib_t
local modlib = require("l3b-modlib")
---@type Module
local Module = modlib.Module
---@type ModEnv
local ModEnv = modlib.ModEnv

require("l3b-modenv-impl")

local expect  = _ENV.expect

local test_G = {
  setup = function (self)
    self.k_l = _ENV.random_string()
    self.k_r = "_".. self.k_l
    self.v_l = _ENV.random_number()
    -- swap l <-> r means change each sign
    self.v_r = -self.v_l
  end,
  load_file = function (self, script, mod_env, ...)
    local loader = load(script, "name", "t", mod_env)
    expect(loader).NOT(nil)
    loader(...)
  end,
  test_proxy_G = function (self)
    local dir = _ENV.create_test_module()
    local mod_env = Module({ path = dir }).env
    local script = [[
local lhs, rhs = ...
-- swap values in global proxy means change sign
_G[lhs], _G[rhs] = _G[rhs], _G[lhs]
]]
    _G[self.k_l], _G[self.k_r] = self.v_l, self.v_r
    expect(_G[self.k_l]).is(self.v_l)
    expect(_G[self.k_r]).is(self.v_r)
    expect(mod_env._G[self.k_l]).is(self.v_l)
    expect(mod_env._G[self.k_r]).is(self.v_r)
    self:load_file(script, mod_env, self.k_l, self.k_r)
    -- expected unswapped globally
    expect(_G[self.k_l]).is(self.v_l)
    expect(_G[self.k_r]).is(self.v_r)
    -- expected swapped in the proxy
    expect(mod_env._G[self.k_l]).is(-self.v_l)
    expect(mod_env._G[self.k_r]).is(-self.v_r)
  end,
  test_G = function (self)
    local mod_env = Module({ path = _ENV.create_test_module() }).env
    local script = [[
-- swap values in available real global means change sign
local lhs, rhs = ...
local _G = __detour_saved_G
_G[lhs], _G[rhs] = _G[rhs], _G[lhs]
]]
    _G[self.k_l], _G[self.k_r] = self.v_l, self.v_r
    expect(_G[self.k_l]).is(self.v_l)
    expect(_G[self.k_r]).is(self.v_r)
    --
    mod_env.__saved_G = _G
    self:load_file(script, mod_env, self.k_l, self.k_r)
    -- expected swapped globally
    expect(_G[self.k_l]).is(-self.v_l)
    expect(_G[self.k_r]).is(-self.v_r)
  end,
}

local function test_deep_load()
  -- load a file that loads a file that changes the environment
  local primary_script = [[
return ... -- just return what was given in argument
]]
local mod_env = Module({ path = _ENV.create_test_module({}) }).env
local loader = load(primary_script, "primary",  "t", mod_env)
  expect(loader).NOT(nil)
  expect(loader(421)).is(421)
  local secondary_script = [[
local primary_script_path, x = ...
-- loading is disabled
local loader = loadfile(primary_script_path, "t", _G)
if loader then
  return loader(x) -- expected x
else
  return loader -- nil actually
end
]]
  loader = load(secondary_script, "secondary",  "t", mod_env)
  expect(loader).NOT(nil)
  expect(loader(secondary_script, 421)).is.NOT(421)
end

local test_group = {
  do_test = function (self, ext, keys)
    local dir = _ENV.create_test_module()
    local module = Module({ path = dir })
    expect(module.main_module).NOT(nil)
    local mod_env = module.env
    -- load a file that loads a file that changes the environment
    local script = {}
    for _,key in ipairs(keys) do
      key = key ..ext
      push(script, ('%s = "%s"'):format(key, key))
    end
    script = concat(script, "\n")
    assert(load(script, "name", "t", mod_env))()
    for _,key in ipairs(keys) do
      key = key ..ext
      expect(mod_env[key]).is(key)
      expect(mod_env[key]).is.NOT(ModEnv[key])
      mod_env[key] = nil
      expect(mod_env[key]).type("string")
      expect(mod_env[key]).is(ModEnv[key])
    end
  end,
  test_ext = function (self)
    self:do_test("ext", {
      "bak",
      "dvi",
      "lvt",
      "tlg",
      "tpf",
      "lve",
      "log",
      "pvt",
      "pdf",
      "ps",
    })
  end,
  test_dir = function (self)
    self:do_test("dir", {
      -- "work",
      -- "docfile",
      -- "sourcefile",
      -- "support",
      -- "testfile",
      -- "testsupp",
      -- "texmf",
      -- "textfile",
      -- "build",
      -- "distrib",
      -- "local",
      -- "result",
      -- "test",
      -- "typeset",
      -- "unpack",
      -- "ctan",
      "tds",
    })
  end,

}

local test_dir = {
  test_maindir = function (self)
    local dir = _ENV.make_temporary_dir()
    local name = _ENV.random_string()
    _ENV.create_test_module({
      dir = dir,
      name = name,
    })
    local maindir = dir / name
    local module = Module({ path = maindir })
    local mod_env = module.env
    expect(mod_env.maindir).ends_with(maindir / ".")
  return
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
    local module_path = _ENV.create_test_module(maindir, "module", [[
module = "module"
]], diagnostic)
    local expected = module_path / "."
    local function test(path)
      expect(path).NOT(nil)
      local output = oslib.run_process(
        path,
        "texlua ".. l3build.script_path .. " test"
      )
      output = output:match(("%s(.-)%s"):format(b, b)) / "."
      expect(output).match(expected)
    end
    test(module_path)
    local submodule_path = _ENV.create_test_module(module_path, "submodule", [[
module = "submodule"
]], diagnostic)
    test(submodule_path)
    local subsubmodule_path = _ENV.create_test_module(submodule_path, "subsubmodule", [[
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

local Xtest_G = {
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


return {
  test_ModEnv     = test_ModEnv,
  test_dir        = test_dir,
  test_deep_load  = test_deep_load,
  test_G          = test_G,
  test_group      = test_group,
}
