#!/usr/bin/env texlua
--[[
  This is a test file for l3build package.
  It is only intended for development and should appear in any distribution of the l3build package.
  For help, run `texlua l3build.lua test -h`
--]]

local concat  = table.concat
local push    = table.insert

---@type pathlib_t
local pathlib   = require("l3b-pathlib")
local job_name  = pathlib.job_name

---@type oslib_t
local oslib         = require("l3b-oslib")
local write_content = oslib.write_content

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
    -- Illustrate what happens when _G or _ENV is not mentionned
    -- during testin _ENV and _G are different
    expect(_G).NOT(_ENV)
    _G["foo"] = "foo"
    _ENV["bar"] = "bar"
    expect(foo).is("foo")
    expect(rawget(_G, "bar")).is(nil)
    expect(bar).is("bar")
    expect(rawget(_ENV, "foo")).is(nil)
    local function f ()
      foo = foo .. foo -- assigned to _ENV, not _G
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
    -- load a script that loads a script that changes the environment
    -- the deeper load is a noop
    local repeat_script = [[
return ... -- just return what was given in argument
]]
    local loader = load(repeat_script)
    expect(loader).NOT(nil)
    expect(loader(421)).is(421)
    local load_repeat_script = [[
local repeat_script, x = ...
-- loading is disabled
return load(repeat_script)(x)
]]
    loader = load(load_repeat_script)
    expect(loader).NOT(nil)
    expect(loader(repeat_script, 421)).is(421)
  end,
  test_deep_dofile = function (self)
    -- load a file that loads a file that changes the environment
    -- the deeper load is a noop
    local dir = _ENV.make_temporary_dir()
    local secondary_path = dir / "secondary.lua"
    local k = _ENV.random_string()
    local v = _ENV.random_number()
    write_content(secondary_path, ([[
%s = %s
]]):format(k, v))
    dofile(secondary_path)
    expect(_G[k]).is(v)
    _G[k] = nil
    local primary_path = dir / "primary.lua"
    write_content(primary_path, ([[
dofile("%s")
]]):format(secondary_path))
    dofile(primary_path)
    expect(_G[k]).is(v)
  end,
}

local function test_other_defaults()
  -- These are collected here not to be forgotten
  -- for defaults with no unkown suffix
  -- defaults with a common suffix ("exe", "dir", "files"...) are managed below
  local dir = _ENV.create_test_module_ds()
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
  --[=====[]====]
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
  load  = function (self, script, mod_env, ...)
    local loader = load(script, "name", "t", mod_env)
    expect(loader).NOT(nil)
    loader(...)
  end,
  test_proxy_G = function (self)
    local dir = _ENV.create_test_module_ds()
    local mod_env = Module({ path = dir }).env
    local script = [[
local lhs, rhs = ...
-- swap values in global proxy means change sign
_G[lhs], _G[rhs] = _G[rhs], _G[lhs]
]]
    -- assign values globally
    _G[self.k_l], _G[self.k_r] = self.v_l, self.v_r
    -- end verify
    expect(_G[self.k_l]).is(self.v_l)
    expect(_G[self.k_r]).is(self.v_r)
    expect(mod_env._G[self.k_l]).is(self.v_l)
    expect(mod_env._G[self.k_r]).is(self.v_r)
    -- run the script
    self:load(script, mod_env, self.k_l, self.k_r)
    -- expected unswapped globally
    expect(_G[self.k_l]).is(self.v_l)
    expect(_G[self.k_r]).is(self.v_r)
    -- expected swapped in the proxy
    expect(mod_env._G[self.k_l]).is(-self.v_l)
    expect(mod_env._G[self.k_r]).is(-self.v_r)
  end,
  test_G = function (self)
    local mod_env = Module({ path = _ENV.create_test_module_ds() }).env
    local script = [[
-- swap values in available real global means change sign
local lhs, rhs = ...
local _G = __detour_saved_G
_G[lhs], _G[rhs] = _G[rhs], _G[lhs]
]]
    _G[self.k_l], _G[self.k_r] = self.v_l, self.v_r
    expect(_G[self.k_l]).is(self.v_l)
    expect(_G[self.k_r]).is(self.v_r)
    -- record the global environment
    mod_env.__saved_G = _G
    self:load(script, mod_env, self.k_l, self.k_r)
    -- expected swapped globally
    expect(_G[self.k_l]).is(-self.v_l)
    expect(_G[self.k_r]).is(-self.v_r)
  end,
}

local test_group = {
  do_test = function (self)
    local dir = _ENV.create_test_module_ds()
    local module = Module({ path = dir })
    local mod_env = module.env
    local ext = self.ext
    local keys = self.keys
    -- create a script that changes the environment
    -- and loads it
    local script = {}
    for _,key in ipairs(keys) do
      key = key ..ext
      push(script, ('%s = "%s"'):format(key, key)) -- environment change here
    end
    script = concat(script, "\n")
    assert(load(script, "name", "t", mod_env))() -- load and execute the script
    for _,key in ipairs(keys) do
      key = key ..ext
      expect(mod_env[key]).is(key)
      expect(mod_env[key]).NOT.equals(ModEnv.__.MT.__index(mod_env, key))
      mod_env[key] = nil
      expect(mod_env[key]).type(self.type)
      expect(mod_env[key]).equals(ModEnv.__.MT.__index(mod_env, key))
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
    _ENV.create_test_module_ds({
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

local test_array = {
  -- we make the tests on the auxfiles computed property
  setup = function (self)
    local path_A = _ENV.create_test_module_ds()
    local module_A = Module({ path = path_A })
    self.mod_env_A = module_A.env
    local path_B = _ENV.create_test_module_ds()
    local module_B = Module({ path = path_B })
    self.mod_env_B = module_B.env
  end,
  test_edit = function (self)
    expect(self.mod_env_A.auxfiles).equals(self.mod_env_B.auxfiles)
    expect(self.mod_env_A.auxfiles).NOT(self.mod_env_B.auxfiles)
    local key = _ENV.random_string()
    push(self.mod_env_A.auxfiles, key)
    expect(self.mod_env_A.auxfiles).includes(key)
    expect(self.mod_env_B.auxfiles).NOT.includes(key)
  end,
  test_replace = function (self)
    expect(self.mod_env_A.auxfiles).equals(self.mod_env_B.auxfiles)
    expect(self.mod_env_A.auxfiles).NOT(self.mod_env_B.auxfiles)
    local key = _ENV.random_string()
    self.mod_env_A.auxfiles = { key }
    expect(self.mod_env_A.auxfiles).equals({ key })
    expect(self.mod_env_B.auxfiles).NOT.includes(key)
  end,
}

local test_types = {
  setup = function (self)
    local path_A    = _ENV.create_test_module_ds()
    local module_A  = Module({ path = path_A })
    self.mod_env_A  = module_A.env
  end,
  test_constructors = function (self)
    local mod_env = self.mod_env_A
    expect(mod_env.lvtext).type("string")
    local tts = __.TestTypes({
      mod_env = mod_env,
    })
    expect(tts).NOT(nil)
    local tt = __.TestType({
      test_types = tts,
    })
    expect(tt).NOT(nil)
    local data = {
      test        = mod_env.lvtext,
      generated   = mod_env.logext,
      reference   = mod_env.tlgext,
      expectation = mod_env.lveext,
      compare     = modlib.compare_tlg,
      rewrite     = modlib.rewrite_log,
    }
    tt = __.TestType({
      test_types = tts,
      name = "log_name",
      data = data,
    })
    expect(tt).NOT(nil)
    expect(tt["test_types"]).NOT(nil)
    expect(tt).keys.contains({
      "test_types",
      "name",
      "compare",
      "rewrite",
      "test",
      "generated",
      "reference",
      "expectation",
    })
    data = {
      test      = mod_env.pvtext,
      generated = mod_env.pdfext,
      reference = mod_env.tpfext,
      rewrite   = modlib.rewrite_pdf,
    }
    tt = __.TestType({
      test_types = tts,
      name = "pdf_name",
      data = data,
    })
    expect(tt).NOT(nil)
    expect(tt["test_types"]).NOT(nil)
    expect(tt).keys.contains({
      "test_types",
      "name",
      "rewrite",
      "test",
      "generated",
      "reference",
    })
  end,
  test_edit = function (self)
    local test_types = self.mod_env_A.test_types
    expect(test_types).keys.contains({ "pdf", "log" })
  end,
  test_affectation = function (self)
    local mod_env = self.mod_env_A
    local test_types = mod_env.test_types
    expect(function () test_types.mod_env = 4 end).error()
    expect(test_types).keys.includes("pdf")
    test_types.pdf = nil
    expect(test_types).keys.NOT.includes("pdf")
    test_types.alt_pdf = {
      test      = mod_env.pvtext,
      reference = mod_env.tpfext,
      rewrite   = modlib.rewrite_pdf,
    }
    expect(test_types).keys.includes("alt_pdf")
    expect(test_types.alt_pdf).instance_of(__.TestType)
  end,
  test_missing_field = function (self)
    local mod_env = self.mod_env_A
    local test_types = mod_env.test_types
    local key = _ENV.random_string()
    test_types[key] = {}
    expect(function () print(test_types[key].generated) end).error()
  end,
}

-- test("_all_typeset")
-- test("_all_pdf")

local test_other = {
  setup = function (self)
    self.path_A = _ENV.create_test_module_ds({
      name = "A",
    })
    self.module_A = Module({ path = self.path_A })
    self.mod_env_A  = self.module_A.env
    self.path_AA = _ENV.create_test_module_ds({
      dir = self.path_A,
      name = "AA",
    })
    self.module_AA = Module({ path = self.path_AA })
    self.mod_env_AA  = self.module_AA.env
  end,
  load  = function (self, script, mod_env, ...)
    local loader = load(script, "name", "t", mod_env)
    expect(loader).NOT(nil)
    return loader(...)
  end,
  test_bundle = function (self)
    local bundle = _ENV.random_string()
    local mod_env = self.mod_env_A
    expect(mod_env.bundle).is("")
    self.module_A.bundle = bundle
    expect(mod_env.bundle).is(bundle)
    bundle = bundle .."X"
    expect(mod_env.bundle).NOT(bundle)
    self:load([[
      bundle = ...
    ]], mod_env, bundle)
    expect(mod_env.bundle).is(bundle)
  end,
  test_module_main = function (self)
    expect(self.module_A.is_main).is(true)
    expect(function () print(self.mod_env_A.module) end).error()
    local module = _ENV.random_string()
    self:load([[
      module = ...
    ]], self.mod_env_A, module)
    expect(self.mod_env_A.module).is(module)
  end,
  test_module_embedded = function (self)
    expect(self.module_AA.is_main).is(false)
    local module = job_name(self.path_AA)
    expect(self.mod_env_AA.module).is(module)
    module = 'X'.. module
    expect(self.mod_env_AA.module).NOT(module)
    self:load([[
      module = ...
    ]], self.mod_env_AA, module)
    expect(self.mod_env_AA.module).is(module)
  end,
  test_modules = function (self)

    expect(self.G.modules).equals({})
  end,
  -- test_checkengines = function (self)
  --   expect(self.G.checkengines).equals({"pdftex", "xetex", "luatex"})
  --   self.G.checkengines = nil -- values have ben cached
  --   local expected = { _ENV.random_string() }
  --   expect(_G.checkengines).is(nil)
  --   _G.checkengines = expected
  --   expect(self.G.checkengines).equals(expected)
  --   _G.checkengines = nil
  -- end,
  -- test_typeset_list = function (self)
  --   expect(function () print(self.G.typeset_list) end).error()
  --   _G.typeset_list = { "A", "B", "C" }
  --   expect(self.G.typeset_list).equals({ "A", "B", "C" })
  --   _G.typeset_list = nil
  -- end,
  -- test_str = function (self)
  --   local test = function (key)
  --     expect(self.G[key]).type("string")
  --     local expected = _ENV.random_string()
  --     _G[key] = expected
  --     expect(self.G[key]).equals(expected)
  --     _G[key] = nil
  --   end
  --   _G.module = "MY SUPER MODULE"
  --   test('ctanpkg')
  --   test('tdsroot')
  --   test('ctanzip')
  --   test('ctanreadme')
  --   test('glossarystyle')
  --   test('indexstyle')
  --   test('typesetcmds')
  --   test('stdengine')
  --   test('checkformat')
  --   test('ps2pdfopt')
  --   test('manifestfile')
  -- end,
  -- test_boolean = function (self)
  --   local test = function (key)
  --     expect(self.G[key]).type("boolean")
  --     local expected = true
  --     _G[key] = expected
  --     expect(self.G[key]).equals(expected)
  --     expected = not expected
  --     _G[key] = expected
  --     expect(self.G[key]).equals(expected)
  --     _G[key] = nil
  --   end
  --   test('flattentds')
  --   test('flattenscript')
  --   test('ctanupload')
  --   test('typesetsearch')
  --   test('recordstatus')
  --   test('forcecheckepoch')
  --   test('checksearch')
  --   test('unpacksearch')
  --   test('flatten')
  --   test('packtdszip')
  --   test('curl_debug')
  -- end,
  -- test_number = function (self)
  --   local test = function (key)
  --     expect(self.G[key]).type("number")
  --     local expected = _ENV.random_number()
  --     _G[key] = expected
  --     expect(self.G[key]).equals(expected)
  --     _G[key] = nil
  --   end
  --   test('epoch')
  --   test('typesetruns')
  --   test('checkruns')
  --   test('maxprintline')
  -- end,
  -- test_function = function (self)
  --   local test = function (key)
  --     expect(self.G[key]).type("function")
  --     local expected = function () end
  --     _G[key] = expected
  --     expect(self.G[key]).equals(expected)
  --     _G[key] = nil
  --   end
  --   test("runcmd")
  --   test("biber")
  --   test("bibtex")
  --   test("makeindex")
  --   test("tex")
  --   test("typeset")
  --   test("typeset_demo_tasks")
  --   test("docinit_hook")
  --   test("runtest_tasks")
  --   test("checkinit_hook")
  --   test("bundleunpack")
  --   test("tag_hook")
  --   test("update_tag")
  -- end,
  -- test_table = function (self)
  --   local test = function (key)
  --     expect(self.G[key]).type("table")
  --     local expected = { _ENV.random_string() }
  --     _G[key] = expected
  --     expect(self.G[key]).equals(expected)
  --     _G[key] = nil
  --   end
  --   test('exclmodules')
  --   test('tdslocations')
  --   test('test_order')
  --   test('includetests')
  --   test('excludetests')
  --   test('asciiengines')
  --   test("specialtypesetting")
  --   test('specialformats')
  --   test('test_types')
  --   test('checkconfigs')
  --   test('uploadconfig')
  -- end,
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
  test_texmfhome = function (self)
    expect(self.G.texmfhome:match("texmf")).is("texmf")
    require("l3build").options.texmfhome = "FOO"
    expect(self.G.texmfhome).is("FOO")
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
  test_array          = test_array,
  test_types          = test_types,
  test_other          = test_other,
}
