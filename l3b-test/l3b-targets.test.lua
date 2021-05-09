#!/usr/bin/env texlua
--[[
  This is a test file for l3build package.
  It is only intending for development and should appear in any distribution of the l3build package.
  For help, run `texlua ../l3build.lua test -h`
--]]

local push   = table.insert

local expect  = _ENV.expect

---@type l3b_targets_t
local targets

---@type __l3b_targets_t
local __

targets, __ = _ENV.loadlib("l3b-targets")

local register_info = targets.register_info
local get_info      = targets.get_info
local get_all_infos = targets.get_all_infos
local process       = targets.process

local function test_base()
  expect(targets).NOT(nil)
end

local test_info = {
  setup = function (self)
    self.info_1 = {
      description = "DESCRIPTION_1",
      package = "PACKAGE".. tostring(math.random(999999)),
      name    = "NAME_1",
      alias   = "ALIAS_1",
    }
    self.module_info_1 = {
      description = "DESCRIPTION_1(MODULE)",
      package = "module_PACKAGE".. tostring(math.random(999999)),
      name    = "module_NAME_1",
      alias   = "module_ALIAS_1",
    }
    self.info_2 = {
      description = "DESCRIPTION_2",
      package = "PACKAGE".. tostring(math.random(999999)),
      name    = "NAME_2",
      alias   = "ALIAS_2",
    }
  end,
  teardown = function (self)
    for k, _ in pairs(__.DB) do
      __.DB[k] = nil
    end
    package.loaded[self.info_1.package] = nil
    package.loaded[self.module_info_1.package] = nil
    package.loaded[self.info_2.package] = nil
  end,
  test_register_info = function (self)
    register_info(self.info_1)
    ---@type TargetInfo
    local info_1 = get_info(self.info_1.name)
    expect(info_1).equals(__.TargetInfo(nil, {
      description = "DESCRIPTION_1",
      package = self.info_1.package,
      name    = "NAME_1",
      alias   = "ALIAS_1",
      builtin = false,
    }))
    expect(function () register_info(self.info_1) end).error()
  end,
  test_get_all_infos = function (self)
    register_info(self.info_1)
    register_info(self.info_2)
    local result = {}
    for info in get_all_infos() do
      push(result, info)
    end
    expect(result).items.map(function (x) return x.name end).equals({
      "NAME_1",
      "NAME_2",
    })
  end,
  test_process_failure = function (self)
    register_info(self.info_1)
    local options = {
      names = { "foo", "bar" }
    }
    expect(function () process(options) end).error()
    options.target = "NAME_1"
    expect(function () process(options) end).error()
    local pkg = {}
    package.loaded[self.info_1.package] = pkg
    local track = {}
    local kvargs = {
      -- required preflight method
      preflight = function ()
        push(track, "preflight")
        return 0
      end,
    }
    expect(function () process(options, kvargs) end).error()
  end,
  test_process = function (self)
    register_info(self.info_1)
    local options = {
      names = { "foo", "bar" }
    }
    options.target = "NAME_1"
    local track = {}
    local kvargs = {
      -- required preflight method
      preflight = function ()
        push(track, "preflight")
        return 0
      end,
    }
    track = {}
    local run_return = math.random(999999)
    local run = function (names)
      push(track, "run")
      for _, name in ipairs(names) do
        push(track, name)
      end
      return run_return
    end
    local pkg = {
      NAME_1 = run,
    }
    package.loaded[self.info_1.package] = pkg
    expect(process(options, kvargs)).is(run_return)
    expect(track).equals({
      "preflight",
      "run",
      "foo",
      "bar",
    })
    pkg = {
      NAME_1_impl = {
        run = run,
      }
    }
    package.loaded[self.info_1.package] = pkg
    track = {}
    expect(process(options, kvargs)).is(run_return)
    expect(track).equals({
      "preflight",
      "run",
      "foo",
      "bar",
    })
    local preflight_return = math.random(999999)
    kvargs = {
      -- required preflight method
      preflight = function (opts)
        push(track, "preflight")
        return preflight_return
      end,
    }
    track = {}
    expect(process(options, kvargs)).is(preflight_return)
    expect(track).equals({
      "preflight",
    })
  end,
  test_high_bundle_module_run = function (self)
    register_info(self.info_1)
    local options = {
      names = { "foo" },
      target = "NAME_1",
    }
    local track = {}
    local module_callback_return = math.random(999999)
    local kvargs = {
      -- required preflight method
      preflight = function ()
        push(track, "preflight")
        return 0
      end,
      at_bundle_top = true,
      module_callback = function (module_target)
        push(track, "module_callback")
        push(track, module_target)
        return module_callback_return
      end,
    }
    track = {}
    local run_return = module_callback_return + math.random(999999)
    local run = function (names)
      push(track, "run")
      for _, name in ipairs(names) do
        push(track, name)
      end
      return run_return
    end
    local run_high_return = run_return + math.random(999999)
    local run_high = function (opts)
      push(track, "run_high")
      for _, name in ipairs(opts.names) do
        push(track, name)
      end
      return run_high_return
    end
    local configure_return = run_high_return + math.random(999999)
    local configure = function (opts)
      push(track, "configure")
      for _, name in ipairs(opts.names) do
        push(track, name)
      end
      return configure_return
    end
    local run_bundle_return = configure_return + math.random(999999)
    local run_bundle = function (names)
      push(track, "run_bundle")
      for _, name in ipairs(names) do
        push(track, name)
      end
      return run_bundle_return
    end
    local pkg = {
      NAME_1_impl = {
        run_high    = run_high,
        configure   = configure,
        run_bundle  = run_bundle,
        run         = run,
      }
    }
    package.loaded[self.info_1.package] = pkg

    expect(process(options, kvargs)).is(run_high_return)
    expect(track).equals({
      "preflight",
      "run_high",
      "foo",
    })
    pkg.NAME_1_impl.run_high  = nil
    track = {}
    expect(process(options, kvargs)).is(configure_return)
    expect(track).equals({
      "configure",
      "foo",
    })
    configure_return  = 0
    track = {}
    expect(process(options, kvargs)).is(run_bundle_return)
    expect(track).equals({
      "configure",
      "foo",
      "run_bundle",
      "foo"
    })
    pkg.NAME_1_impl.run_bundle  = nil
    track = {}
    expect(process(options, kvargs)).is(module_callback_return)
    expect(track).equals({
      "configure",
      "foo",
      "module_callback",
      "NAME_1"
    })
    kvargs.at_bundle_top = false
    track = {}
    expect(process(options, kvargs)).is(run_return)
    expect(track).equals({
      "configure",
      "foo",
      "preflight",
      "run",
      "foo"
    })
    kvargs.at_bundle_top = true
    register_info(self.module_info_1)
    track = {}
    expect(process(options, kvargs)).is(module_callback_return)
    expect(track).equals({
      "configure",
      "foo",
      "module_callback",
      "module_NAME_1"
    })
  end,
}

return {
  test_base = test_base,
  test_info = test_info,
}
