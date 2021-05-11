#!/usr/bin/env texlua
--[[
  This is a test file for l3build package.
  It is only intended for development and should appear in any distribution of the l3build package.
  For help, run `texlua l3build.lua test -h`
--]]

local push = table.insert

---@type corelib_t
local corelib = _ENV.loadlib("l3b-corelib")
local GET_MAIN_VARIABLE = corelib.GET_MAIN_VARIABLE

---@type oslib_t
local oslib = require("l3b-oslib")
local write_content = oslib.write_content

local expect  = _ENV.expect

---@type l3b_main_t
local l3b_main = _ENV.loadlib("l3build-main")
local Main = l3b_main.Main

local function test_basic()
  expect(l3b_main).NOT(nil)
end

local test_declared_options = {
  setup = function (self)
    self.manager = Main()
  end,
  test_options = function (self)
    self.manager:register_builtin_options()
    local longs = {}
    for info in self.manager:get_all_option_infos() do
      push(longs, info.long)
    end
    expect(longs).items.equals({
      "config",
      "date",
      "debug",
      "dirty",
      "dry-run",
      "email",
      "engine",
      "epoch",
      "file",
      "first",
      "force",
      "full",
      "halt-on-error",
      "help",
      "last",
      "message",
      "quiet",
      "rerun",
      "show-log-on-error",
      "shuffle",
      "texmfhome",
      "version",
      GET_MAIN_VARIABLE
    })
  end,
  test_custom_options = function (self)
    -- create a "options.lua" file in the temp domain
    local dir = _ENV.make_temporary_dir(_ENV.random_string())
    expect(dir).NOT(nil)
    local content = [[
register_option({
  name = "my_option",
  long = "my-option",
  short = "o",
  type = "number",
  description = "DESCRIPTION",
})
]]
    local config_path = dir / 'options.lua'
    write_content(config_path, content)
    self.manager:register_custom_options(dir)
    local info = self.manager:option_info_with_key('my-option')
    expect(info).NOT(nil)
    expect(os.remove(config_path)).is(true)
    expect(os.remove(dir)).is(true)
  end,
  test_targets = function (self)
    self.manager:register_targets()
    local names = {}
    for info in self.manager:get_all_target_infos() do
      push(names, info.name)
    end
    expect(names).items.equals({
        -- Some hidden targets
      "check",
      "clean",
      "ctan",
      "doc",
      "install",
      "manifest",
      "save",
      "status",
      "tag",
      "uninstall",
      "unpack",
      "upload",
    })
    names = {}
    for info in self.manager:get_all_target_infos(true) do
      push(names, info.name)
    end
    expect(names).items.equals({
        -- Some hidden targets
      "module_check",
      "module_ctan",
      "module_unpack" ,
      "module_tag",
      "check",
      "clean",
      "ctan",
      "doc",
      "install",
      "manifest",
      "save",
      "status",
      "tag",
      "uninstall",
      "unpack",
      "upload",
    })
  end,
  test_custom_target = function (self)
    -- create a "options.lua" file in the temp domain
    local dir = _ENV.make_temporary_dir(_ENV.random_string())
    expect(dir).NOT(nil)
    local content = [[
register_target({
  name = "foo",
  description = "FOO DESCRIPTION",
  impl = {
    run = function (names)
      print(table.unpack(names))
    end,
  },
})
]]
    local config_path = dir / 'build.lua'
    write_content(config_path, content)
    local main = Main()
    main:load_build(dir)
    local info = main:target_info_with_name('foo')
    expect(info).NOT(nil)
    local expected = _ENV.random_string()
    local options = {
      target = 'foo',
      names = { expected },
    }
    local kvargs = {
      preflight = function () end
    }
    local done
    _ENV.push_print(function (x)
      done = x
    end)
    main:process(options, kvargs)
    _ENV.pop_print()
    expect(done).is(expected)
    expect(os.remove(config_path)).is(true)
    expect(os.remove(dir)).is(true)
  end,
}

return {
  test_basic            = test_basic,
  test_declared_options = test_declared_options,
}
--[[
  local option_list = {
  config = {
    description = "Sets the config(s) used for running tests",
    short = "c",
    type  = "table"
  },
  date = {
    description = "Sets the date to insert into sources",
    type  = "string"
  },
  debug = {
    description = "Runs target in debug mode (not supported by all targets)",
    type = "boolean"
  },
  dirty = {
    description = "Skip cleaning up the test area",
    type = "boolean"
  },
  ["dry-run"] = {
    description = "Dry run for install",
    type = "boolean"
  },
  email = {
    description = "Email address of CTAN uploader",
    type = "string"
  },
  engine = {
    description = "Sets the engine(s) to use for running test",
    short = "e",
    type  = "table"
  },
  epoch = {
    description = "Sets the epoch for tests and typesetting",
    type  = "string"
  },
  file = {
    description = "Take the upload announcement from the given file",
    short = "F",
    type  = "string"
  },
  first = {
    description = "Name of first test to run",
    type  = "string"
  },
  force = {
    description = "Force tests to run if engine is not set up",
    short = "f",
    type  = "boolean"
  },
  full = {
    description = "Install all files",
    type = "boolean"
  },
  ["halt-on-error"] = {
    description = "Stops running tests after the first failure",
    short = "H",
    type  = "boolean"
  },
  help = {
    description = "Print a helping message and exit",
    short = "h",
    type  = "boolean"
  },
  last = {
    description = "Name of last test to run",
    type  = "string"
  },
  message = {
    description = "Text for upload announcement message",
    short = "m",
    type  = "string"
  },
  quiet = {
    description = "Suppresses TeX output when unpacking",
    short = "q",
    type  = "boolean"
  },
  rerun = {
    description = "Skip setup: simply rerun tests",
    type  = "boolean"
  },
  ["show-log-on-error"] = {
    description = "If 'halt-on-error' stops, show the full log of the failure",
    type  = "boolean"
  },
  shuffle = {
    description = "Shuffle order of tests",
    type  = "boolean"
  },
  texmfhome = {
    description = "Location of user texmf tree",
    type = "string"
  },
  version = {
    description = "Print version information and exit",
    type = "boolean"
  },
  [GET_MAIN_VARIABLE] = {
    description = "Status returns the value of the main variable given its name",
    type = "string"
  }
}
]]