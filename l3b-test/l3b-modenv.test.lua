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
---@type table<string,string>
local default_keys = modlib.default_keys

---@type Module
local Module = modlib.Module
---@type ModEnv
local ModEnv = modlib.ModEnv

local _, __ = _ENV.loadlib("l3b-modenv-impl")

local expect  = _ENV.expect

local test_POC = {
  test_explicit_ENV_or_G = function (self)
    -- When _G or _ENV is explicitly mentionned
    local k_G, v_G = _ENV.random_k_v()
    local k_E = k_G .. "X"
    local v_E = -v_G
    _G[k_G] = v_G
    _ENV[k_E] = v_E
    local function f ()
      _ENV[k_E] = v_G
      _ENV[k_G] = v_E
    end
    f()
    expect(_G[k_G]).is(v_G)
    expect(_G[k_E]).is(nil)
    expect(_ENV[k_G]).is(v_E)
    expect(_ENV[k_E]).is(v_G)
  end,
  test_implicit_ENV_or_G = function (self)
    -- When _G or _ENV is not mentionned
    _G["foo"] = "foo"
    _ENV["bar"] = "bar"
    expect(foo).is("foo")
    expect(rawget(_G, "bar")).is(nil)
    expect(bar).is("bar")
    expect(rawget(_ENV, "foo")).is(nil)
    local function f ()
      foo = foo .. foo
      bar = bar .. bar
    end
    f()
    expect(foo).is("foofoo")
    expect(bar).is("barbar")
    expect(_G["foo"]).is("foo")
    expect(_G["bar"]).is(nil)
    expect(rawget(_ENV, "foo")).is("foofoo")
    expect(rawget(_ENV, "bar")).is("barbar")
  end,
  test_which_ENV = function (self)
    -- the _ENV is what is available at runtime, not parsetime
    local k, v = _ENV.random_k_v()
    _ENV[k] = v
    local track = {}
    local function f ()
      push(track, _ENV[k])
    end
    f()
    expect(track).equals({ v })
    track = {}
    local function g()
      _ENV[k] = -v
      f()
    end
    g()
    expect(track).equals({ -v })
  end,
  test_deep_load = function (self)
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
  end,
}

local function test_other_defaults()
  -- These are collected here not to be forgotten
  -- for defaults with no unkown suffix
  -- defaults with a common suffix ("exe", "dir", "files"...) are managed below
  local dir = _ENV.create_test_module()
  local mod_env = Module({ path = dir }).env
  local n = 0
  local utlib = require("l3b-utillib")
  local sorted_pairs = utlib.sorted_pairs

  for name, _ in sorted_pairs(default_keys, {
    compare = utlib.compare_ascending,
  }) do
    if mod_env[name] == nil and not name:match("%.") then
      n = n + 1
    end
  end
  if n > 0 then
    for name, value_type in sorted_pairs(default_keys, {
      compare = utlib.compare_ascending,
    }) do
      if mod_env[name] == nil and not name:match("%.") then
        print("MISSING implementation", name, value_type)
      end
    end
  end
  -- expect(n).is(0)
  --[=====[]=====]
  local entries = utlib.entries
  local t = {}
  local max_keys = 0
  for entry in entries(__.entry_by_index, {
    compare = function (l, r) return l.name < r.name end,
  }) do
    local name = entry.name
    local value_type = entry.value_type
    if not value_type then
      if name:match("dir$")
      or name:match("files$")
      or name:match("ext$")
      then
        value_type = "string"
      elseif entry.value ~= nil then
        value_type = type(entry.value)
      elseif name:match("%.") then
        value_type = "string"
      else
        error("UNKNONW TYPE" + name)
      end
    end
    if name:match("%.") then
      name = ('["%s"]'):format(name)
    end
    push(t, {
      name = name,
      value_type = value_type,
      description = entry.description,
      value = entry.value,
      index = entry.index,
      complete = entry.complete,
    })
    if #name > max_keys then
      max_keys = #name
    end
  end
  max_keys = 2 * ( (max_keys + 1) // 2 )
  print("NEXT IS COMING")
  --[=====[]=====]
  for _, kv in ipairs(t) do
    if not kv.name:match("%.") then
      if kv.description and kv.description:match("\n") then
        local filler = (" "):rep(max_keys - #kv.name)
        print(('---@field public %s%s %s'):format(kv.name, filler, kv.value_type))
        for line in kv.description:gmatch("[^\n]+") do
          print(('---%s'):format(line))
        end
        print("")
      end
    end
  end

  --[=====[]=====]
end

local test_G = {
  setup = function (self)
    self.k_l, self.v_l = _ENV.random_k_v()
    self.k_r = "_".. self.k_l
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

local test_group = {
  do_test = function (self)
    local ext = self.ext
    local keys = self.keys
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
      print("DEBUGGG", key)
      expect(mod_env[key]).is(key)
      expect(mod_env[key]).NOT.equals(ModEnv.__.MT.__index(mod_env, key))
      mod_env[key] = nil
      expect(mod_env[key]).type(self.type)
      expect(mod_env[key]).equals(ModEnv.__.MT.__index(mod_env, key))
      print("DEBUGGG DONE", key)
    end
  end,
  test_files = function (self)
    self.ext = "files"
    self.type = "table"
    self.keys = {
      "aux",
      "bib",
      "binary",
      "bst",
      "check",
      "checksupp",
      "clean",
      "demo",
      "doc",
      "dynamic",
      "exclude",
      "install",
      "makeindex",
      "script",
      "scriptman",
      "source",
      "tag",
      "text",
      "typesetdemo",
      "typeset",
      "typesetsupp",
      "typesetsource",
      "unpack",
      "unpacksupp",
    }
    self:do_test()
  end,
  test_ext = function (self)
    self.ext = "ext"
    self.type = "string"
    self.keys = {
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
    }
    self:do_test()
  end,
  test_deps = function (self)
    self.ext = "deps"
    self.type = "table"
    self.keys = {
      "check",
      "typeset",
      "unpack",
    }
    self:do_test()
  end,
  test_exe = function (self)
    self.ext = "exe"
    self.type = "string"
    self.keys = {
      "typeset",
      "unpack",
      "zip",
      "biber",
      "bibtex",
      "makeindex",
      "curl",
    }
    self:do_test()
  end,
  test_opts = function (self)
    self.ext = "opts"
    self.type = "string"
    self.keys = {
      "check",
      "typeset",
      "unpack",
      "zip",
      "biber",
      "bibtex",
      "makeindex",
    }
    self:do_test()
  end,
  test_dir = function (self)
    self.ext = "dir"
    self.type = "string"
    self.keys = {
      "work",
      "docfile",
      "sourcefile",
      "support",
      "testfile",
      "testsupp",
      "texmf",
      "textfile",
      "build",
      "distrib",
      "local",
      "result",
      "test",
      "typeset",
      "unpack",
      "ctan",
      "tds",
    }
    self:do_test()
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
    local maindir = dir / name / "."
    local module = Module({ path = maindir })
    local mod_env = module.env
    expect(mod_env.maindir).ends_with(maindir)
  return
  end,
}

-- test("_all_typeset")
-- test("_all_pdf")

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
  test_POC            = test_POC,
  test_other_defaults = test_other_defaults,
  test_ModEnv         = test_ModEnv,
  test_dir            = test_dir,
  test_G              = test_G,
  test_group          = test_group,
}
