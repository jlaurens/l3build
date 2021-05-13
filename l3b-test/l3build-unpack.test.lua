#!/usr/bin/env texlua
--[[
  This is a test file for l3build package.
  It is only intended for development and should appear in any distribution of the l3build package.
  For help, run `texlua l3build.lua test -h`
--]]

local push = table.insert

---@type fslib_t
local fslib           = require("l3b-fslib")
local make_directory  = fslib.make_directory
local quoted_absolute_path = fslib.quoted_absolute_path

---@type oslib_t
local oslib         = require("l3b-oslib")
local write_content = oslib.write_content
local read_content  = oslib.read_content

---@type l3b_globals_t
local l3b_globals = require("l3build-globals")
local Dir         = l3b_globals.Dir

local expect = _ENV.expect

---@type l3b_unpk_t
local l3b_unpk

---@type __l3b_unpk_t
local __

l3b_unpk, __ = _ENV.loadlib("l3build-unpack")

local function test_basic()
  expect(l3b_unpk).NOT(nil)
end

local test_bundle_unpack = {
  populate_source = function (self)
    -- populating source files
    _G.unpackfiles = { "**/*.foo" }
    local source_dir = self.maindir / "source_dir"
    self.source_dir = source_dir
    make_directory(source_dir / "A" / "AA")
    write_content(source_dir / "A" / "a.foo", "a")
    write_content(source_dir / "A" / "AA" / "aa.foo", "aa")
    make_directory(source_dir / "A" / "AB")
    write_content(source_dir / "A" / "AB" / "ab.foo", "ab")
    make_directory(source_dir / "B" / "BB")
    write_content(source_dir / "B" / "b.foo", "b")
    write_content(source_dir / "B" / "BB" / "bb.foo", "bb")
    make_directory(source_dir / "B" / "BA")
    write_content(source_dir / "B" / "BA" / "ba.foo", "ba")
    self.source_dir = source_dir
    self.expected_source = {
      ".",
      "./A",
      "./A/a.foo",
      "./A/AA",
      "./A/AA/aa.foo",
      "./A/AB",
      "./A/AB/ab.foo",
      "./B",
      "./B/b.foo",
      "./B/BA",
      "./B/BA/ba.foo",
      "./B/BB",
      "./B/BB/bb.foo",
    }
    self.expected_sub_source = {
      ".",
      "./a.foo",
      "./AA",
      "./AA/aa.foo",
      "./AB",
      "./AB/ab.foo",
      "./b.foo",
      "./BA",
      "./BA/ba.foo",
      "./BB",
      "./BB/bb.foo",
    }
  end,
  populate_support = function (self)
    -- populating support files
    make_directory(Dir.support / "A" / "AA")
    write_content(Dir.support / "A" / "a.bar", "a")
    write_content(Dir.support / "A" / "AA" / "aa.bar", "aa")
    make_directory(Dir.support / "A" / "AB")
    write_content(Dir.support / "A" / "AB" / "ab.bar", "ab")
    make_directory(Dir.support / "B" / "BB")
    write_content(Dir.support / "B" / "b.bar", "b")
    write_content(Dir.support / "B" / "BB" / "bb.bar", "bb")
    make_directory(Dir.support / "B" / "BA")
    write_content(Dir.support / "B" / "BA" / "ba.bar", "ba")
    _G.unpacksuppfiles = { "**/*.bar" }
    self.expected_support = {
      ".",
      "./A",
      "./A/AA",
      "./A/AA/aa.bar",
      "./A/AB",
      "./A/AB/ab.bar",
      "./A/a.bar",
      "./B",
      "./B/BA",
      "./B/BA/ba.bar",
      "./B/BB",
      "./B/BB/bb.bar",
      "./B/b.bar",
    }
  end,
  setup = function (self)
    self.maindir = _ENV.make_temporary_dir()
    expect(self.maindir).NOT(nil)
    fslib.set_working_directory(self.maindir)
    _G.maindir = self.maindir
  end,
  teardown = function (self)
  end,
  do_test_support = function (self)
    local actual = {}
    for p in fslib.tree(Dir[l3b_globals.LOCAL], "**") do
      push(actual, p.src)
    end
    expect(actual).items.equals(self.expected_support)
  end,
  do_test_source = function (self)
    local actual = {}
    for p in fslib.tree(self.source_dir, "**") do
      push(actual, p.src)
    end
    expect(actual).items.equals(self.expected_source)
  end,
  test_prepare_support = function (self)
    self:populate_support()
    __.prepare_support()
    self:do_test_support()
  end,
  test_prepare_source = function (self)
    self:populate_source()
    __.prepare_source({ self.source_dir / "A", self.source_dir / "B"}, { "**/*.foo" })
    self:do_test_source()
  end,
  test_bundleunpack = function(self)
    self:populate_support()
    self:populate_source()
    local script_path = self.maindir / "unpack.lua"
    _G.unpackexe = "texlua ".. quoted_absolute_path(script_path)
    write_content(script_path, [[
#!/usr/bin/env texlua
local unpacked = arg[1].. ".unpacked"
os.rename(arg[1], unpacked)
]])
    l3b_unpk.bundleunpack({ self.source_dir / "A", self.source_dir / "B"}, { "**/*.foo" })
    self:do_test_support()
    local actual = {}
    for p in fslib.tree(Dir.unpack, "**") do
      push(actual, p.src)
    end
    local expected = {}
    for _, k in ipairs(self.expected_sub_source) do
      k = k:gsub(".foo", ".foo.unpacked")
      push(expected, k)
    end
    expect(actual).items.equals(expected)
  end,
  test_bundleunpackcmd = function(self)
    self:populate_support()
    self:populate_source()
    local script_path = self.maindir / "unpack.lua"
    local cmd = "texlua ".. quoted_absolute_path(script_path) .. " "
    function _G.bundleunpackcmd(name)
      return cmd .. quoted_absolute_path(Dir.unpack / name)
    end
    write_content(script_path, [[
#!/usr/bin/env texlua
local unpacked = arg[1].. ".unpacked"
os.rename(arg[1], unpacked)
]])
    l3b_unpk.bundleunpack({ self.source_dir / "A", self.source_dir / "B"}, { "**/*.foo" })
    self:do_test_support()
    local actual = {}
    for p in fslib.tree(Dir.unpack, "**") do
      push(actual, p.src)
    end
    local expected = {}
    for _, k in ipairs(self.expected_sub_source) do
      k = k:gsub(".foo", ".foo.unpacked")
      push(expected, k)
    end
    expect(actual).items.equals(expected)
  end,
}

local function test_deps_install()
  -- create 2 fake modules
  local maindir = _ENV.make_temporary_dir()
  _G.maindir = maindir
  expect(make_directory(Dir.unpack)).is(0)
  fslib.set_working_directory(maindir)
  fslib.change_current_directory(maindir)
  local script_path = "unpack.lua"
  write_content(script_path, [[
#!/usr/bin/env texlua
print("unpacking", arg[1])
]])
  local script_fmt = [[
#!/usr/bin/env texlua
module = "module_%d"
maindir = ".."
function bundleunpackcmd(name)
  local result = "texlua ".. [=[%s]=] .." ".. name
  print("Unpacking module_%d: will run ", result)
  return result
end
local oslib = require("l3b-oslib")
local l3b_unpk = require("l3build-unpack")
function l3b_unpk.unpack_impl.run()
  oslib.write_content(maindir / module .. ".unpacked", module)
end
]]
  local dir_1 = "module_1"
  make_directory(dir_1)
  local content = script_fmt:format(1, quoted_absolute_path(script_path), 1)
  write_content(dir_1 / "build.lua", content)
  local dir_2 = "module_2"
  make_directory(dir_2)
  content = script_fmt:format(2, quoted_absolute_path(script_path), 2)
  write_content(dir_2 / "build.lua", content)
  _ENV.push_print(function () end)
  require("l3build").options.quiet = true
  l3b_unpk.deps_install({ "module_1", "module_2" })
  _ENV.pop_print()
  expect(read_content("module_1" .. ".unpacked")).is("module_1")
  expect(read_content("module_2" .. ".unpacked")).is("module_2")
end

local function test_deps_install_2()
  -- create 2 fake modules
  local maindir = _ENV.make_temporary_dir()
  _G.maindir = maindir
  print("DEBBBBBBUG", Dir.sourcefile, Dir.docfile)
  expect(make_directory(Dir.unpack)).is(0)
  fslib.set_working_directory(maindir)
  fslib.change_current_directory(maindir)
  local script_path = "unpack.lua"
  write_content(script_path, [[
#!/usr/bin/env texlua
  print("os.rename:", arg[1], arg[1] ..".unpacked"))
  os.rename(arg[1], arg[1] ..".unpacked")
]])
  local script_fmt = [[
#!/usr/bin/env texlua
module = "module_%d"
maindir = ".."
local cmd = "texlua ".. [=[%s]=] .." "
print(("Unpacking %%s: will run %%s ..."):format(module, cmd))
function bundleunpackcmd(name)
  print("DEBUUUUG", name)
  return cmd .. name
end
options.debug = true
sourcefiles = { "**/*.foo" }
]]
  local dir_1 = "module_1"
  make_directory(dir_1)
  local content = script_fmt:format(1, quoted_absolute_path(script_path), 1)
  write_content(dir_1 / "build.lua", content)
  write_content(dir_1 / "source_1.foo", "source_1")
  local dir_2 = "module_2"
  make_directory(dir_2)
  content = script_fmt:format(2, quoted_absolute_path(script_path), 2)
  write_content(dir_2 / "build.lua", content)
  write_content(dir_2 / "source_2.foo", "source_2")
  --_ENV.push_print(function () end)
  require("l3build").options.quiet = false
  require("l3build").options.debug = true
  l3b_unpk.deps_install({ "module_1", "module_2" })
  --_ENV.pop_print()
end

return {
  test_basic          = test_basic,
  test_bundle_unpack  = test_bundle_unpack,
  test_deps_install   = test_deps_install,
  test_deps_install_2 = test_deps_install_2,
}
