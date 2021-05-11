#!/usr/bin/env texlua
--[[
  This is a test file for l3build package.
  It is only intended for development and should appear in any distribution of the l3build package.
  For help, run `texlua l3build.lua test -h`
--]]

local push = table.insert

local expect  = _ENV.expect

---@type l3b_options_t
local l3b_options
---@type __l3b_options_t
local __

l3b_options, __ = _ENV.loadlib("l3b-options")

local register          = l3b_options.register
local get_info_by_name  = l3b_options.get_info_by_name
local parse             = l3b_options.parse
local function test_basic()
  expect(l3b_options).NOT(nil)
  expect(__).NOT(nil)
end

local test_options = {
  setup = function (self)
    self.old = __.reset()
    self.info_number = {
      description = "DESCRIPTION NUMBER",
      long = "number",
      short = "n",
      type  = "number",
    }
    self.info_number_array = {
      description = "DESCRIPTION NUMBER ARRAY",
      long = "numbers",
      short = "N",
      type  = "number[]",
    }
    self.info_string = {
      description = "DESCRIPTION STRING",
      long = "string",
      short = "s",
      type  = "string",
    }
    self.info_string_array = {
      description = "DESCRIPTION STRING ARRAY",
      long = "strings",
      short = "S",
      type = "string[]"
    }
    self.info_boolean = {
      description = "DESCRIPTION BOOLEAN",
      long = "boolean",
      short = "b",
      type  = "boolean",
    }
  end,
  teardown = function (self)
    __.reset()
    for _, info in pairs(self.old) do
      register(info, info.builtin)
    end
  end,
  do_test = function (self, arg, expected)
    table.insert(arg, 1, "FOO")
    local actual = parse(arg)
    expect(actual).contains(expected)
  end,
  test_number = function (self)
    local info = register(self.info_number)
    expect(info).is(get_info_by_name(self.info_number.long))
    expect(info).contains(__.OptionInfo(self.info_number))
    local n = math.random(999999)
    self:do_test({ "--number", tostring(n) }, {
      number = n,
    })
    self:do_test({ "--number", "421", "--number", tostring(n) }, {
      number = n,
    })
    expect(function () parse({ "FOO", "--number" }) end).error()
    n = math.random(999999)
    self:do_test({ "-n", tostring(n) }, {
      number = n,
    })
    self:do_test({ "-n", "421", "-n", tostring(n) }, {
      number = n,
    })
    expect(function () parse({ "FOO", "-n" }) end).error()
  end,
  test_number_array = function (self)
    local info = register(self.info_number_array)
    expect(info).is(get_info_by_name(self.info_number_array.long))
    expect(info).contains(__.OptionInfo(self.info_number_array))
    local n = math.random(999999)
    self:do_test({ "--numbers", tostring(n) }, {
      numbers = { n },
    })
    self:do_test({ "--numbers", tostring(n), "--numbers", tostring(n) }, {
      numbers = { n, n },
    })
    expect(function () parse({ "FOO", "--numbers" }) end).error()
    n = math.random(999999)
    self:do_test({ "-N", tostring(n), "-N", tostring(n) }, {
      numbers = { n, n },
    })
    self:do_test({ "-N", "421", "-N", tostring(n) }, {
      numbers = { 421, n },
    })
    expect(function () parse({ "FOO", "-N" }) end).error()
  end,
  test_string = function (self)
    local info = register(self.info_string)
    expect(info).is(get_info_by_name(self.info_string.long))
    expect(info).contains(__.OptionInfo(self.info_string))
    local s = tostring(math.random(999999))
    self:do_test({ "--string", s }, {
      string = s,
    })
    expect(function () parse({ "FOO", "--string" }) end).error()
    self:do_test({ "-s", s }, {
      string = s,
    })
    expect(function () parse({ "FOO", "-s" }) end).error()
  end,
  test_string_array = function (self)
    local info = register(self.info_string_array)
    expect(info).is(get_info_by_name(self.info_string_array.long))
    expect(info).contains(__.OptionInfo(self.info_string_array))
    local s = tostring(math.random(999999))
    self:do_test({ "--strings", s }, {
      strings = { s },
    })
    self:do_test({ "--strings", s, "--strings", s }, {
      strings = { s, s },
    })
    expect(function () parse({ "FOO", "--strings" }) end).error()
    self:do_test({ "-S", s }, {
      strings = { s },
    })
    self:do_test({ "-S", s, "-S", s }, {
      strings = { s, s },
    })
    expect(function () parse({ "FOO", "-S" }) end).error()
  end,
  test_boolean = function (self)
    local info = register(self.info_boolean)
    expect(info).is(get_info_by_name(self.info_boolean.long))
    expect(info).contains(__.OptionInfo(self.info_boolean))
    self:do_test({ "--boolean" }, {
      boolean = true,
    })
    self:do_test({ "-b" }, {
      boolean = true,
    })
    self:do_test({ "--no-boolean" }, {
      boolean = false,
    })
    self:do_test({ "--boolean", "--no-boolean" }, {
      boolean = false,
    })
    self:do_test({ "--no-boolean", "--boolean" }, {
      boolean = true,
    })
  end,
  test_all = function (self)
    for _ = 1, 20 do
      self:setup()
      local infos = {
        self.info_boolean,
        self.info_string,
        self.info_string_array,
        self.info_number,
        self.info_number_array,
      }
      while #infos > 0 do
        register(table.remove(infos, math.random(#infos)))
      end
      local t = {
        { "-b" },
        { "-n", "421" },
        { "-s", "123" },
        { "-N", "421" },
        { "-N", "123" },
        { "-S", "421" },
        { "-S", "123" },
      }
      local args = { "FOO" }
      while #t > 0 do
        local tt = table.remove(t, math.random(#t))
        table.move(
          tt,
          1,
          #tt,
          #args + 1,
          args
        )
      end
      local options = parse(args)
      expect(options).contains({
        boolean = true,
        number  = 421,
        string  = "123",
        -- numbers = { 123, 421 },
        -- strings = { "123", "421" },
      })
      expect(options.numbers).items.equals({ 123, 421 })
      expect(options.strings).items.equals({ "123", "421" })
      self:teardown()
    end
  end,
  test_action = function (self)
    expect(parse({ "ACTION" })).contains({
      target = "ACTION"
    })
    expect(parse({ "--version" })).contains({
      target = "version"
    })
    expect(parse({ "-" })).contains({
      target = "help"
    })
  end,
  test_names = function (self)
    expect(parse({ "ACTION", "A" })).contains({
      names = { "A" },
    })
    expect(parse({ "ACTION", "A", "B" })).contains({
      names = { "A", "B" },
    })
  end,
  test_unknown = function (self)
    local track = {}
    parse({ "ACTION", "-A", "a" }, function (k)
      push(track, k)
      return true
    end)
    expect(track).equals({ "A" })
    track = {}
    parse({ "ACTION", "-A", "-B", "a" }, function (k)
      push(track, k)
      return true
    end)
    expect(track).equals({ "A", "B" })
    track = {}
    local options = parse({ "ACTION", "-A", "-B", "b" }, function (k)
      if k == "A" then
        push(track, k)
        return true
      end
      return function (v, opts)
        push(track, k)
        push(track, v)
        opts[k] = v
      end
    end)
    expect(track).equals({ "A", "B", "b" })
    expect(options).contains({
      B = "b",
      target = "ACTION",
    })
  end,
}

return {
  test_basic    = test_basic,
  test_options  = test_options,
}
