#!/usr/bin/env texlua
--[[
  This is a test file for l3build package.
  It is only intended for development and should appear in any distribution of the l3build package.
  For help, run `texlua l3build.lua test -h`
--]]

local push   = table.insert

local expect  = _ENV.expect

---@type corelib_t
local corelib = require("l3b-corelib")

---@type utlib_t
local utlib = require("l3b-utillib")

---@type oslib_t
local oslib = require("l3b-oslib")
local write_content = oslib.write_content
local read_content  = oslib.read_content

---@type fslib_t
local fslib

---@type __fslib_t
local __

fslib, __ = _ENV.loadlib("l3b-fslib")

local directory_exists  = fslib.directory_exists
local make_directory    = fslib.make_directory
local remove_directory  = fslib.remove_directory
local file_exists       = fslib.file_exists
local change_current_directory  = fslib.change_current_directory
local push_current_directory    = fslib.push_current_directory
local pop_current_directory     = fslib.pop_current_directory
local push_pop_current_directory  = fslib.push_pop_current_directory
local absolute_path             = fslib.absolute_path
local quoted_absolute_path      = fslib.quoted_absolute_path
-- TODO test get_current_directory
local get_current_directory     = fslib.get_current_directory
local locate                    = fslib.locate
local file_list                 = fslib.file_list
local tree                      = fslib.tree
local rename                    = fslib.rename
local copy_file                 = fslib.copy_file
local copy_tree                 = fslib.copy_tree
local remove_name               = fslib.remove_name
local remove_tree               = fslib.remove_tree
local make_clean_directory      = fslib.make_clean_directory

expect(#__.cwd_list).is(0)

local function test_base()
  expect(fslib).NOT(nil)
end

local function test_to_host()
  local old_os = os
  local primary_os = {}
  _G.os = corelib.bridge({
    primary = primary_os,
    secondary = os,
  })
  primary_os.type = "UNKNOWN"
  expect(os["type"]).is("UNKNOWN")
  local to_host = _ENV.loadlib("l3b-fslib").to_host
  expect(function () to_host() end).error()
  expect(to_host("")).is("")
  expect(to_host("abcd")).is("abcd")
  expect(to_host("a/cd")).is("a/cd")
  primary_os.type = "windows"
  expect(os["type"]).is("windows")
  to_host = _ENV.loadlib("l3b-fslib").to_host
  expect(function () to_host() end).error()
  expect(to_host("")).is("")
  expect(to_host("abcd")).is("abcd")
  expect(to_host("a/cd")).is("a\\cd")
  _G.os = old_os
end

local test_directory = {
  setup = function (self)
    self.name = _ENV.make_temporary_dir("TEST".._ENV.random_string())
    self.base_name = self.name:match("[^/]+$")
    self.dir_name = self.name:sub(1, #self.name - #self.base_name - 1)
    self.to_remove = {
      self.name,
      self.dir_name,
    }
  end,
  teardown = function (self)
    for i = #self.to_remove, 1, -1 do
      os.remove(self.to_remove[i])
    end
    expect(#__.cwd_list).is(0)
  end,
  add_to_remove = function (self, path)
    push(self.to_remove, path)
  end,
  test_directory = function (self)
    local name = "TEST".. _ENV.random_string()
    local path = self.dir_name .."/" .. name
    expect(directory_exists(path)).is(false)
    expect(make_directory(path)).is(0)
    expect(directory_exists(path)).is(true)
    expect(remove_directory(path)).is(0)
    expect(directory_exists(path)).is(false)
    local path_deep = path .. "/A/B/C"
    expect(directory_exists(path_deep)).is(false)
    expect(make_directory(path_deep)).is(0)
    expect(directory_exists(path_deep)).is(true)
    expect(remove_directory(path_deep)).is(0)
    expect(directory_exists(path_deep)).is(false)
    path_deep = path .. "/A/B"
    expect(directory_exists(path_deep)).is(true)
    expect(remove_directory(path_deep)).is(0)
    expect(directory_exists(path_deep)).is(false)
    path_deep = path .. "/A"
    expect(directory_exists(path_deep)).is(true)
    expect(remove_directory(path_deep)).is(0)
    expect(directory_exists(path_deep)).is(false)
    path_deep = path
    expect(directory_exists(path_deep)).is(true)
    expect(remove_directory(path_deep)).is(0)
    expect(directory_exists(path_deep)).is(false)
  end,
  test_file_exists = function (self)
    expect(file_exists(self.name)).is(false)
    expect(directory_exists(self.name)).is(true)
    local path = self.name .."/".. _ENV.random_string()
    expect(file_exists(path)).is(false)
    write_content(path, "something")
    expect(file_exists(path)).is(true)
    expect(file_exists(self.name.."???")).is(false)
  end,
  make_random_directory = function (self)
    local name = "TEST".._ENV.random_string()
    expect(change_current_directory(self.dir_name)).is(true)
    expect(make_directory(name)).is(0)
    self:add_to_remove(name)
    expect(change_current_directory(name)).is(true)
    self.random_name = name
  end,
  test_change_directory = function (self)
    self:make_random_directory()
    expect(make_directory("A")).is(0)
    expect(directory_exists("A")).is(true)
    expect(push_current_directory("A")).is(true)
    expect(make_directory("B")).is(0)
    expect(directory_exists("B")).is(true)
    expect(push_current_directory("B")).is(true)
    expect(directory_exists("B")).is(false)
    expect(pop_current_directory()).type.is("string")
    expect(directory_exists("B")).is(true)
    expect(pop_current_directory()).type.is("string")
    expect(directory_exists("A")).is(true)
    expect(function () pop_current_directory() end).error()
    local done = false
    local function f(name)
      done = directory_exists(name)
      return 1, 2, 3
    end
    local succ, packed = push_pop_current_directory("A", f, "B")
    local a, b, c = table.unpack(packed)
    expect(done).is(true)
    expect(succ).is(true)
    expect(a).is(1)
    expect(b).is(2)
    expect(c).is(3)
    function f(name)
      error(name)
    end
    b = _ENV.random_string()
    succ, a = push_pop_current_directory("A", f, b)
    expect(succ).is(false)
    expect(a:match(b)).NOT(nil)
  end,
  test_quoted_absolute_path = function (self)
    self:make_random_directory()
    fslib.set_working_directory(
      self.dir_name / self.random_name
    )
    if os["type"] == "windows" then
      expect(quoted_absolute_path("A B C"):match('A B C')).NOT(nil)
    else
      expect(quoted_absolute_path("A B C"):match('A\\ B\\ C')).NOT(nil)
    end
  end,
  test_absolute_path = function (self)
    self:make_random_directory()
    fslib.set_working_directory(
      self.dir_name / self.random_name
    )
    expect(#__.cwd_list).is(0)
    -- on OSX the absolute path may have a "/private" prefix
    -- fslib.Vars.debug.absolute_path = true
    expect(absolute_path("A"):match(self.dir_name / self.random_name / "A")).NOT(nil)
    expect(#__.cwd_list).is(0)
    expect(function () absolute_path("" / self.random_name / "A" / "B") end).error()
  end,
  test_locate = function (self)
    self:make_random_directory()
    make_directory("A")
    make_directory("A/AA")
    make_directory("A/AB")
    make_directory("A/AC")
    make_directory("B")
    make_directory("B/BA")
    make_directory("B/BB")
    make_directory("B/BC")
    write_content("A/AA/aa", "")
    write_content("A/AB/aa", "")
    write_content("B/BB/aa", "")
    write_content("A/AA/aa", "")
    write_content("A/AB/ab", "")
    write_content("B/BB/aa", "")
    expect(file_exists("A/AA/aa")).is(true)
    expect(file_exists("A/AB/aa")).is(true)
    expect(file_exists("B/BB/aa")).is(true)
    expect(locate({ "A/AA" }, { "aa" })).is("./A/AA/aa")
    expect(locate({ "A/AB", "A/AA" }, { "aa" })).is("./A/AB/aa")
    expect(locate({ "A/AB", "A/AA" }, { "ab", "aa" })).is("./A/AB/ab")
    expect(locate({ "A/AA", "A/AB" }, { "ab", "aa" })).is("./A/AA/aa")
    expect(locate({ "A/AA", "A/AB" }, { "aa", "ab" })).is("./A/AA/aa")
    expect(locate({ "A/AB", "A/AA" }, { "aa", "ab" })).is("./A/AB/aa")
  end,
  make_tree = function (self, prefix)
    self:make_random_directory()
    for x in utlib.items("A", "B") do
      make_directory(x)
      for t in utlib.items("a", "b", "c") do
        local p = x / ( prefix .. t )
        write_content(p, p)
      end
      for y in utlib.items("A", "B") do
        y = x .. y
        make_directory(x / y )
        for t in utlib.items("a", "b", "c") do
          local p = x / y / ( prefix .. t )
          write_content(p, p)
        end
        for z in utlib.items("A", "B") do
          z = y .. z
          make_directory(x / y / z )
          for t in utlib.items("a", "b", "c") do
            local p = x / y / z / (prefix .. t)
            write_content(p, p)
          end
        end
      end
    end
  end,
  test_file_list = function (self)
    self:make_random_directory()
    write_content(".tex", "foo")
    expect(file_list(".")).items.equals({ ".tex" })
  end,
  test_file_list_2 = function (self)
    self:make_tree("x-")
    expect(function () file_list() end).error()
    expect(file_list(".")).items.equals({ "A", "B" })
    expect(file_list("A")).items.equals({ "AA", "AB", "x-a", "x-b", "x-c" })
    expect(file_list("B", "*")).items.equals({ ".", "BA", "BB", "x-a", "x-b", "x-c" })
    expect(file_list("A/AA", "x*")).items.equals({ "x-a", "x-b", "x-c" })
    expect(file_list("A/AB", "x-*")).items.equals({ "x-a", "x-b", "x-c" })
    expect(file_list("B/BA", "x-a")).items.equals({ "x-a" })
    expect(file_list("B/BB", "x-[ab]")).items.equals({ "x-a", "x-b" })
    expect(file_list("A", "x-[b-c]")).items.equals({ "x-b", "x-c" })
  end,
  iterate = function (self, dir, glob)
    ---@type tree_entry_t[]
    local result = {}
    for leaf in tree(dir, glob) do
      push(result, leaf)
    end
    return result
  end,
  test_tree = function (self)
    -- fslib.Vars.debug.tree = true
    self:make_tree("x-")
    expect(function () tree() end).error()
    expect(self:iterate(".", "*"))
      .items
      .map(function (x) return x.src end)
      .equals({ "./A", "./B" })
    expect(self:iterate("A", "*"))
      .items
      .map(function (x) return x.src end)
      .equals({ "./AA", "./AB", "./x-a", "./x-b", "./x-c" })
    expect(self:iterate("A", "x*"))
      .items
      .map(function (x) return x.src end)
      .equals({ "./x-a", "./x-b", "./x-c" })
    expect(self:iterate("A", "**"))
      .items
      .map(function (x) return x.src end)
      .equals({
        ".",
        "./x-a",
        "./x-b",
        "./x-c",
        "./AA",
        "./AA/x-a",
        "./AA/x-b",
        "./AA/x-c",
        "./AA/AAA",
        "./AA/AAA/x-a",
        "./AA/AAA/x-b",
        "./AA/AAA/x-c",
        "./AA/AAB",
        "./AA/AAB/x-a",
        "./AA/AAB/x-b",
        "./AA/AAB/x-c",
        "./AB",
        "./AB/x-a",
        "./AB/x-b",
        "./AB/x-c",
        "./AB/ABA",
        "./AB/ABA/x-a",
        "./AB/ABA/x-b",
        "./AB/ABA/x-c",
        "./AB/ABB",
        "./AB/ABB/x-a",
        "./AB/ABB/x-b",
        "./AB/ABB/x-c",
    })
    expect(self:iterate("A", "**/x*"))
      .items
      .map(function (x) return x.src end)
      .equals({
        "./x-a",
        "./x-b",
        "./x-c",
        "./AA/x-a",
        "./AA/x-b",
        "./AA/x-c",
        "./AB/x-a",
        "./AB/x-b",
        "./AB/x-c",
        "./AA/x-a",
        "./AA/x-b",
        "./AA/x-c",
        "./AA/AAA/x-a",
        "./AA/AAA/x-b",
        "./AA/AAA/x-c",
        "./AA/AAB/x-a",
        "./AA/AAB/x-b",
        "./AA/AAB/x-c",
        "./AB/x-a",
        "./AB/x-b",
        "./AB/x-c",
        "./AB/ABA/x-a",
        "./AB/ABA/x-b",
        "./AB/ABA/x-c",
        "./AB/ABB/x-a",
        "./AB/ABB/x-b",
        "./AB/ABB/x-c",
    })
  end,
  test_rename = function (self)
    self:make_random_directory()
    write_content("a", "")
    expect(file_exists("a")).is(true)
    expect(file_exists("b")).is(false)
    expect(rename(".", "a", "b")).is(0)
    expect(file_exists("a")).is(false)
    expect(file_exists("b")).is(true)
    expect(rename(".", "b", "b")).is(0)
    expect(file_exists("a")).is(false)
    expect(file_exists("b")).is(true)
    local track
    _ENV.push_print(function (x)
      track = x
    end)
    expect(rename("..", "."..self.random_name, "a")).NOT(0)
    _ENV.pop_print()
    expect(track:match(self.random_name)).NOT(nil)
  end,
  test_poor_man_rename = function (self)
    self:make_random_directory()
    fslib.Vars.poor_man_rename = true
    write_content("a", "")
    expect(file_exists("a")).is(true)
    expect(file_exists("b")).is(false)
    expect(rename(".", "a", "b")).is(0)
    expect(file_exists("a")).is(false)
    expect(file_exists("b")).is(true)
    expect(rename(".", "b", "b")).is(0)
    expect(file_exists("a")).is(false)
    expect(file_exists("b")).is(true)
    print("Next error is expected")
    expect(rename("..", "."..self.random_name, "a")).NOT(0)
    fslib.Vars.poor_man_rename = false
  end,
  test___copy_core = function (self)
    self:make_random_directory()
    local dir = "A/B/C"
    make_directory(dir)
    local p_wrk = dir / "a"
    local s = _ENV.random_string()
    write_content(p_wrk, s)
    local p_src = "C/a"
    local dest = "A/D"
    expect(file_exists(p_wrk)).is(true)
    local copied_to = dest / p_src
    expect(file_exists(copied_to)).is(false)
    expect(__.copy_core(dest, p_src, p_wrk)).is(0)
    expect(file_exists(copied_to)).is(true)
    expect(read_content(copied_to)).is(s)
  end,
  test_copy_file = function (self)
    self:make_random_directory()
    -- copy_file(name, source, dest)
    local name = "a"
    local source = "A/B"
    local dest = "C/D"
    make_directory(source)
    local s = _ENV.random_string()
    write_content(source / name, s)
    expect(file_exists(source / name)).is(true)
    expect(file_exists(dest / name)).is(false)
    copy_file(name, source, dest)
    expect(file_exists(dest / name)).is(true)
    expect(read_content(dest / name)).is(s)
  end,
  test_copy_tree = function (self)
    -- local function copy_tree(glob, source, dest)
    self:make_tree("x-")
    local glob = "*[ab]*"
    local source = "A"
    local dest = "A2"
    expect(copy_tree(glob, source, dest)).is(0)
    -- fslib.Vars.debug.tree = true
    expect(self:iterate("A", "*"))
      .items
      .map(function (x) return x.wrk end)
      .equals({
        "./A/x-a",
        "./A/x-b",
        "./A/x-c",
        "./A/AA",
        "./A/AB",
    })
    expect(self:iterate("A", "*x*"))
      .items
      .map(function (x) return x.wrk end)
      .equals({
        "./A/x-a",
        "./A/x-b",
        "./A/x-c",
    })
    expect(self:iterate("A2", "**"))
      .items
      .map(function (x) return x.wrk end)
      .equals({
        "./A2",
        "./A2/x-a",
        "./A2/x-b",
      })
    dest = "A3"
    glob = utlib.items( "x-a", "x-c" )
    expect(copy_tree(glob, source, dest)).is(0)
    expect(self:iterate("A3", "**"))
      .items
      .map(function (x) return x.wrk end)
      .equals({
        "./A3",
        "./A3/x-a",
        "./A3/x-c",
      })
    dest = "A4"
    glob = { "x-b", "x-c" }
    expect(copy_tree(glob, source, dest)).is(0)
    expect(self:iterate("A4", "**"))
      .items
      .map(function (x) return x.wrk end)
      .equals({
        "./A4",
        "./A4/x-b",
        "./A4/x-c",
      })
  end,
  test_remove_name = function (self)
    self:make_tree("")
    local dir_path, name
    dir_path = "A"
    name = "a"
    expect(file_exists(dir_path / name)).is(true)
    expect(remove_name(dir_path, name)).is(0)
    expect(file_exists(dir_path / name)).is(false)
    dir_path = "A/AB"
    name = "b"
    expect(file_exists(dir_path / name)).is(true)
    expect(remove_name(dir_path, name)).is(0)
    expect(file_exists(dir_path / name)).is(false)
  end,
  test_remove_tree = function (self)
    self:make_tree("")
    local source = "A"
    local glob = "**"
    remove_tree(source, glob)
    expect(self:iterate("A", "**"))
      .items
      .map(function (x) return x.wrk end)
      .equals({
        "./A",
        "./A/AA",
        "./A/AB",
        "./A/AA/AAA",
        "./A/AA/AAB",
        "./A/AB/ABA",
        "./A/AB/ABB",
      })
  end,
  test_make_clean_directory = function (self)
    self:make_tree("")
    make_clean_directory("A")
    expect(self:iterate("A", "**"))
      .items
      .map(function (x) return x.wrk end)
      .equals({
        "./A",
        "./A/AA",
        "./A/AB",
        "./A/AA/AAA",
        "./A/AA/AAB",
        "./A/AB/ABA",
        "./A/AB/ABB",
      })
    make_clean_directory("C")
    expect(self:iterate("C", "**"))
      .items
      .map(function (x) return x.wrk end)
      .equals({
        "./C",
      })
  end,
}

return {
  test_base       = test_base,
  test_to_host    = test_to_host,
  test_directory  = test_directory,
}