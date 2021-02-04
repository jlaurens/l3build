local _NAME = "l3build-boot"

local boot = require(_NAME)

function test_boot ()
  af.assert_is_table(boot)
  af.assert_equals(boot._NAME, _NAME)
end

function test_delay_require()
  af.assert_is_nil(boot.search_path("fooxxx"))
  af.assert_error(function ()
    boot.delay_require("fooxxx")
  end)
  af.flag.reset()
  af.assert_is_string(boot.search_path("bar"))
  af.assert_is_string(boot.search_path("foo"))
  local foo = boot.delay_require("foo")
  af.assert_not_is_nil(foo)
  af.flag.expect()
  af.assert_equals(foo._TYPE, "module")
  af.flag.expect("foo/bar")
end

function test_searcher()
  local mod_name = "chi-foo-mee-421"
  boot.uninstall_searcher()
  af.assert_is_string(boot.search_path(mod_name))
  af.assert_error(function ()
    require(mod_name)
  end)
  boot.install_searcher()
  local m = require(mod_name)
  af.assert_not_is_nil(m)
  af.assert_equals(m._TYPE, "module")
end

function test_shift_left()
  local ra = { 1, 2, 3, 4, 5, 6 }
  boot.shift_left(ra, 2)
  af.assert_equals(ra, { 3, 4, 5, 6 })
end

