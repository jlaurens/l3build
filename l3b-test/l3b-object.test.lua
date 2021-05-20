#!/usr/bin/env texlua
--[[
  This is a test file for l3build package.
  It is only intended for development and should appear in any distribution of the l3build package.
  For help, run `texlua l3build.lua test -h`
--]]

local push = table.insert

---@type Object
local Object
---@type __object_t
local __

Object, __ = _ENV.loadlib("l3b-object")

local expect  = _ENV.expect

local test_POC = {
  test_metatable_metatable = function (self)
    -- can we define a metatable by a metatable?
    -- No because the __... methods in the metatable
    -- are accessed via rawget()
    local MT = {
      __len = function ()
                return 666
              end
    }
    local a = setmetatable({}, MT)
    expect(#a).is(666)
    local unm = function ()
      return 421
    end
    MT.__unm = unm
    expect(MT.__unm).is(unm)
    expect(-a).is(421)
    -- new if we define the property indirectly
    MT.__unm = nil
    setmetatable(MT, {
      __index = {
        __unm = unm,
      }
    })
    -- we still have
    expect(MT.__unm).is(unm)
    -- but no unm for a
    expect(function () print(-a) end).error()
  end,
  test_when_newindex = function (self)
    local track = {}
    local a = setmetatable({}, {
      __index = function(this, k)
        if k == "bar" then
          return 666
        end
      end,
      __newindex = function (this, k, v)
        push(track, k)
        push(track, v)
      end,
    })
    a.foo = 421
    expect(a.foo).is(nil)
    expect(track).equals({ "foo", 421 })
    track = {}
    a.foo = 421
    expect(a.foo).is(nil)
    expect(track).equals({ "foo", 421 })
    track = {}
    expect(a.bar).is(666)
    a.bar = 123
    expect(track).equals({ "bar", 123 })
    expect(a.bar).is(666)
  end,

}

local function test_Object()
  expect(Object).NOT(nil)
  expect(Object.__.Super).is(Object)
  expect(Object.__.Class).is(Object)
  local o = Object()
  expect(o).NOT(nil)
  local k, v = _ENV.random_k_v()
  o[k] = v
  expect(o[k]).is(v)
end

local function test_make_subclass()
  expect(function () Object.make_subclass() end).error()
  local A = Object:make_subclass("A")
  expect(A.__.Class).is(A)
  expect(A.__.Super).is(Object)
  local AA = A:make_subclass("AA")
  expect(AA.__.Class).is(AA)
  expect(AA.__.Super).is(A)
  expect(A.__.get).is(rawget)
  expect(A.__.set).is(rawset)
  expect(AA.__.get).is(rawget)
  expect(AA.__.set).is(rawset)
end

local function test_constructor()
  local Foo = Object:make_subclass("Foo")
  expect(Foo.__TYPE).is("Foo")
  expect(Foo.__.Class).is(Foo)
  local foo = Foo()
  expect(foo.__TYPE).is("Foo")
  expect(foo.__.Class).is(Foo)
end

local function test_is_instance()
  expect(Object.is_instance).is(false)
  local Foo = Object:make_subclass("Foo")
  expect(Foo.is_instance).is(false)
  local foo = Foo()
  expect(foo.is_instance).is(true)
end

local function test_is_instance_of()
  expect(Object.is_instance_of).type("function")
  local Foo = Object:make_subclass("Foo")
  expect(Foo.is_instance_of).type("function")
  local foo = Foo()
  expect(Foo.is_instance_of(foo, Foo)).is(true)
  expect(foo.is_instance_of).type("function")
  expect(foo:is_instance_of(Foo)).is(true)
  expect(foo:is_instance_of(Object)).is(false)
  expect(Foo.__.Super).is(Object)
  local Bar = Foo:make_subclass("Bar")
  local bar = Bar()
  expect(bar:is_instance_of(Bar)).is(true)
  expect(bar:is_instance_of(Foo)).is(false)
  expect(bar:is_instance_of(Object)).is(false)
  expect(foo:is_instance_of(Bar)).is(false)
  expect(foo:is_instance_of(nil)).is(false)
  expect(Object.is_instance_of(nil, nil)).is(false)
end

local function test_is_descendant_of()
  local Foo = Object:make_subclass("Foo")
  local Bar = Foo:make_subclass("Bar")
  local foo = Foo()
  local bar= Bar()
  expect(foo:is_descendant_of(Foo)).is(true)
  expect(foo:is_descendant_of(Object)).is(true)
  expect(bar:is_descendant_of(Bar)).is(true)
  expect(bar:is_descendant_of(Foo)).is(true)
  expect(bar:is_descendant_of(Object)).is(true)
  expect(foo:is_descendant_of(Bar)).is(false)
end

local function test_finalize()
  local done
  local Foo = Object:make_subclass("Foo", {
    __finalize = function (class)
      done = class.__TYPE
    end,
  })
  expect(done).is("Foo")
end

local function test_initialize()
  local done
  local A = Object:make_subclass("Foo")
  function A.__.initialize(self, kv)
    done = kv.x
  end
  A({ x = 421})
  expect(done).is(421)
end

local test_make_another_subclass = {
  test_computed = function (_self)
    local Class_1 = Object:make_subclass("Class_1")
    function Class_1.__:get(k)
      if k == "foo_1" then
        return "bar_1"
      end
    end
    local o = Object()
    expect(Class_1.__.MT.__index(o, "foo_1")).is("bar_1")
    expect(Class_1.__.get(o, "foo_1")).is("bar_1")
    local instance_1 = Class_1()
    expect(instance_1.foo_1).is("bar_1")

    local Class_2a = Class_1:make_subclass("Class_2a")
    function Class_2a.__:get(k)
      if k == "foo_2a" then
        return "bar_2a"
      end
    end
    expect(Class_2a.__.MT.__index(o, "foo_2a")).is("bar_2a")
    expect(Class_2a.__.get(o, "foo_2a")).is("bar_2a")
    local instance_2a = Class_2a()
    expect(instance_2a.foo_2a).is("bar_2a")

    local Class_2b = Class_1:make_subclass("Class_2b")
    function Class_2b.__:get(k)
      if k == "foo_2b" then
        return "bar_2b"
      end
      return Class_1.__.get(self, k) -- inherits all computed properties
    end
    local instance_2b = Class_2b()
    expect(instance_2b.foo_2b).is("bar_2b")

    expect(instance_2b.foo_1).is("bar_1")

    local Class_2c = Class_1:make_subclass("Class_2c")
    local instance_2c = Class_2c()
    expect(instance_2c.foo_1).is("bar_1")

  end,

  test_base = function (self)
    -- make a class hierarchy
    local Class_1  = Object:make_subclass("Class_1")
    expect(Class_1.__.Super).is(Object)
    local Class_2  = Class_1:make_subclass("Class_2")
    expect(Class_2.__.Super).is(Class_1)
    local Class_3  = Class_2:make_subclass("Class_3")
    expect(Class_3.__.Super).is(Class_2)
    -- make instances
    local instance_1 = Class_1()
    expect(instance_1.__.Class).is(Class_1)
    local instance_2 = Class_2()
    expect(instance_2.__.Class).is(Class_2)
    local instance_3 = Class_3()
    expect(instance_3.__.Class).is(Class_3)

    expect(Class_1.foo).is(nil)
    expect(instance_1.foo).is(nil)
    expect(Class_2.foo).is(nil)
    expect(instance_2.foo).is(nil)
    expect(Class_3.foo).is(nil)
    expect(instance_3.foo).is(nil)

    Class_1.foo = "bar"

    expect(Class_1.foo).is("bar")
    expect(instance_1.foo).is("bar")
    expect(Class_2.foo).is("bar")
    expect(instance_2.foo).is("bar")
    expect(Class_3.foo).is("bar")
    expect(instance_3.foo).is("bar")

    Class_1.foo = nil

    expect(Class_1.foo    ).is(nil)
    expect(instance_1.foo ).is(nil)
    expect(Class_2.foo    ).is(nil)
    expect(instance_2.foo ).is(nil)
    expect(Class_3.foo    ).is(nil)
    expect(instance_3.foo ).is(nil)

    Class_2.foo = "bar"

    expect(Class_1.foo    ).is(nil)
    expect(instance_1.foo ).is(nil)
    expect(Class_2.foo    ).is("bar")
    expect(instance_2.foo ).is("bar")
    expect(Class_3.foo    ).is("bar")
    expect(instance_3.foo ).is("bar")

    Class_2.foo = nil

    expect(Class_1.foo    ).is(nil)
    expect(instance_1.foo ).is(nil)
    expect(Class_2.foo    ).is(nil)
    expect(instance_2.foo ).is(nil)
    expect(Class_3.foo    ).is(nil)
    expect(instance_3.foo ).is(nil)

    Class_3.foo = "bar"

    expect(Class_1.foo    ).is(nil)
    expect(instance_1.foo ).is(nil)
    expect(Class_2.foo    ).is(nil)
    expect(instance_2.foo ).is(nil)
    expect(Class_3.foo    ).is("bar")
    expect(instance_3.foo ).is("bar")

    Class_3.foo = nil

    expect(Class_1.foo    ).is(nil)
    expect(instance_1.foo ).is(nil)
    expect(Class_2.foo    ).is(nil)
    expect(instance_2.foo ).is(nil)
    expect(Class_3.foo    ).is(nil)
    expect(instance_3.foo ).is(nil)

  end,

  test_data = function (_self)
    local Class  = Object:make_subclass("Class", {
      foo = "bar",
    })
    local instance = Class()
    expect(instance.foo).is("bar")
  end,

  test_initialize = function (_self)
    local A  = Object:make_subclass("A")
    function A.__:initialize()
      self.foo = "bar"
    end
    local a = A()
    expect(a.foo).is("bar")
  end,

  test_initialize_param = function (_self)
    local A  = Object:make_subclass("A")
    function A.__:initialize(kv)
      self.foo = kv.foo
    end
    local a = A({ foo = "bar" })
    expect(a.foo).is("bar")
  end,
}

-- where inheritance is illutsrated
local test_computed = {
  test_one_level = function ()
    ---@class test_computed_A: Object
    ---@field public p_1 any
    ---@field public p_2 any
    local A = Object:make_subclass("A")
    expect(A.p_1).is(nil)
    local a = A()
    expect(a.p_1).is(nil)
    local old = A.__.get
    A.__.get = function (self, k)
      if k == "p_1" then
        return "A.p_1"
      end
    end
    expect(A.p_1).is(A.p_1)
    expect(a.p_1).is("A.p_1")
    A.__.get = old
    expect(A.p_1).is(nil)
    expect(a.p_1).is(nil)
  end,
  test_two_levels = function ()
    ---@type test_computed_A
    local A = Object:make_subclass("A")
    expect(A.p_1).is(nil)
    ---@type test_computed_A
    local a = A()
    expect(a.p_1).is(nil)
    ---@type test_computed_A
    local AA = A:make_subclass("AA")
    expect(AA.p_1).is(nil)
    local aa = AA()
    expect(aa.p_1).is(nil)
    local old = A.__.get
    A.__.get = function (self, k)
      if k == "p_1" then
        return "A.p_1"
      end
    end
    expect(A.p_1).is("A.p_1")
    expect(a.p_1).is("A.p_1")
    expect(AA.p_1).is("A.p_1")
    expect(aa.p_1).is("A.p_1")
    AA.__.get = function (self, k)
      if k == "p_1" then
        return "AA.p_1"
      end
    end
    expect(A.p_1).is("A.p_1")
    expect(a.p_1).is("A.p_1")
    expect(AA.p_1).is("AA.p_1")
    expect(aa.p_1).is("AA.p_1")
    AA.__.get = function (self, k)
      if k == "p_2" then
        return "AA.p_2"
      end
    end
    expect(A.p_1).is("A.p_1")
    expect(a.p_1).is("A.p_1")
    expect(AA.p_1).is("A.p_1")
    expect(aa.p_1).is("A.p_1")
    expect(A.p_2).is(nil)
    expect(a.p_2).is(nil)
    expect(AA.p_2).is("AA.p_2")
    expect(aa.p_2).is("AA.p_2")
    A.__.get = old
    expect(A.p_1).is(nil)
    expect(a.p_1).is(nil)
    expect(AA.p_1).is(nil)
    expect(aa.p_1).is(nil)
    expect(A.p_2).is(nil)
    expect(a.p_2).is(nil)
    expect(AA.p_2).is("AA.p_2")
    expect(aa.p_2).is("AA.p_2")
  end,
  test_dynamic = function ()
    ---@type test_computed_A
    local A = Object:make_subclass("A")
    ---@type test_computed_A
    local a = A()
    ---@type test_computed_A
    local AA = A:make_subclass("AA")
    ---@type test_computed_A
    local aa = AA()
    A.__.get = function (self --[[test_computed_A]], k)
      if k == "p_1" then
        return "A.p_1"
      end
      if k == "p_2" then
        return self.p_1 .."/A.p_2"
      end
    end
    expect(a.p_1).is("A.p_1")
    expect(a.p_2).is("A.p_1/A.p_2")
    expect(AA.p_1).is("A.p_1")
    expect(AA.p_2).is("A.p_1/A.p_2")
    expect(aa.p_1).is("A.p_1")
    expect(aa.p_2).is("A.p_1/A.p_2")
    AA.p_1 = "AA.p_1"
    expect(a.p_1).is("A.p_1")
    expect(a.p_2).is("A.p_1/A.p_2")
    expect(AA.p_1).is("AA.p_1")     -- Change here
    expect(AA.p_2).is("A.p_1/A.p_2") -- Change here
    expect(aa.p_1).is("AA.p_1")     -- Change here
    expect(aa.p_2).is("A.p_1/A.p_2") -- Change here
    -- Revert
    AA.p_1 = nil
    expect(a.p_1).is("A.p_1")
    expect(a.p_2).is("A.p_1/A.p_2")
    expect(AA.p_1).is("A.p_1")
    expect(AA.p_2).is("A.p_1/A.p_2")
    expect(aa.p_1).is("A.p_1")
    expect(aa.p_2).is("A.p_1/A.p_2")
    -- Change only the `aa` instance property
    aa.p_1 = "aa.p_1"
    expect(a.p_1).is("A.p_1")
    expect(a.p_2).is("A.p_1/A.p_2")
    expect(AA.p_1).is("A.p_1")
    expect(AA.p_2).is("A.p_1/A.p_2")
    expect(aa.p_1).is("aa.p_1")     -- Change here
    expect(aa.p_2).is("A.p_1/A.p_2") -- But not here
    -- change both the class and instance properties
    AA.p_1 = "AA.p_1"
    aa.p_1 = "aa.p_1"
    expect(AA.p_1).is("AA.p_1")
    expect(AA.p_2).is("A.p_1/A.p_2") -- Change here
    expect(aa.p_1).is("aa.p_1")     -- Different change here
    expect(aa.p_2).is("A.p_1/A.p_2") -- and here
  end,
  test_object_nil = function ()
    local A = Object:make_subclass("A")
    expect(A.p_1).is(nil)
    local a = A()
    expect(a.p_1).is(nil)
    local AA = A:make_subclass("AA")
    expect(AA.p_1).is(nil)
    local aa = AA()
    expect(aa.p_1).is(nil)
    local old = A.__.get
    A.__.get = function (self, k)
      if k == "p_1" then
        return "A.p_1"
      end
    end
    expect(A.p_1).is("A.p_1")
    expect(a.p_1).is("A.p_1")
    expect(AA.p_1).is("A.p_1")
    expect(aa.p_1).is("A.p_1")
    AA.__.get = function (self, k)
      if k == "p_1" then
        return Object.NIL -- override `p_1` to nil
      end
    end
    expect(A.p_1).is("A.p_1")
    expect(a.p_1).is("A.p_1")
    expect(AA.p_1).is(nil)
    expect(aa.p_1).is(nil) -- `p_1` is overriden to nil
    A.__.get = old
    expect(A.p_1).is(nil)
    expect(a.p_1).is(nil)
    expect(AA.p_1).is(nil)
    expect(aa.p_1).is(nil)
  end,
}

-- where inheritance is also illustrated
local test_getter = {
  test_one_level = function (_self)
    ---@type test_computed_A
    local A = Object:make_subclass("A")
    ---@type test_computed_A
    local a = A()
    expect(a.p_1).is(nil)
    -- create a class level computed property
    A.__.getter.p_1 = function (self)
      return "A.p_1"
    end
    expect(A.p_1).is("A.p_1")
    expect(a.p_1).is("A.p_1")
    A.__.getter.p_1 = function (self)
      return nil
    end
    expect(A.p_1).is(nil)
    expect(a.p_1).is(nil)
    A.p_1 = "A.p_1"
    expect(A.p_1).is("A.p_1")
    expect(a.p_1).is("A.p_1")
  end,
  test_two_levels = function (_self)
    local A = Object:make_subclass("A")
    local a = A()
    local AA = A:make_subclass("AA")
    local aa = AA()
    A.__.getter.p_1 = function (self)
      return "A.p_1"
    end
    expect(A.p_1).is("A.p_1")
    expect(a.p_1).is("A.p_1")
    expect(AA.p_1).is("A.p_1")
    expect(aa.p_1).is("A.p_1")
    -- override instance property to some value
    AA.__.getter.p_1 = function (self)
      return "AA.p_1"
    end
    expect(A.p_1).is("A.p_1")
    expect(a.p_1).is("A.p_1")
    expect(AA.p_1).is("AA.p_1")
    expect(aa.p_1).is("AA.p_1")
    -- override instance property to nil
    AA.__.getter.p_1 = function (self)
      return Object.NIL
    end
    expect(A.p_1).is("A.p_1")
    expect(a.p_1).is("A.p_1")
    expect(AA.p_1).is(nil)
    expect(aa.p_1).is(nil)
    -- Revert to the initial setting
    AA.__.getter.p_1 = nil
    expect(A.p_1).is("A.p_1")
    expect(a.p_1).is("A.p_1")
    expect(AA.p_1).is("A.p_1")
    expect(aa.p_1).is("A.p_1")
  end,
  test_dynamic = function (_self)
    ---@class test_getter_A: Object
    ---@field public p_1 any
    ---@field public p_2 any
    local A = Object:make_subclass("A")
    local a = A()
    ---@class test_getter_AA: test_getter_A
    local AA = A:make_subclass("AA")
    local aa = AA()
    function A.__.getter:p_1()
      return "A.p_1"
    end
    function A.__.getter:p_2()
      return self.p_1 .."/A.p_2"
    end
    expect(A.p_1).is("A.p_1")
    expect(A.p_2).is("A.p_1/A.p_2")
    expect(a.p_1).is("A.p_1")
    expect(a.p_2).is("A.p_1/A.p_2")
    expect(AA.p_1).is("A.p_1")
    expect(AA.p_2).is("A.p_1/A.p_2")
    expect(aa.p_1).is("A.p_1")
    expect(aa.p_2).is("A.p_1/A.p_2")
    -- override the class property in the subclass:
    AA.__.getter.p_1 = function (self)
      return "AA.p_1"
    end
    expect(AA.__.getter).NOT(A.__.getter)
    expect(AA.p_1).is("AA.p_1")
    expect(AA.p_2).is("AA.p_1/A.p_2")
    expect(aa.p_1).is("AA.p_1")
    expect(aa.p_2).is("AA.p_1/A.p_2")
    -- override the subclass instance property
    aa.p_1 = "aa.p_1"
    expect(aa.p_1).is("aa.p_1")
    expect(aa.p_2).is("aa.p_1/A.p_2") -- now the computed property refers to the instance
    -- revert to the initial state
    aa.p_1 = nil
    AA.__.getter.p_1 = nil
    expect(AA.p_1).is("A.p_1")
    expect(AA.p_2).is("A.p_1/A.p_2")
    expect(aa.p_1).is("A.p_1")
    expect(aa.p_2).is("A.p_1/A.p_2")
  end
}

local function test_key ()
  local A = Object:make_subclass("A")
  function A.__:get(k)
    if k == "key" then
      return self.__TYPE
    end
  end
  expect(A.key).is("A")
  local a = A()
  expect(a.key).is("A")
  local AA = A:make_subclass("AA")
  expect(AA.key).is("AA")
end

local test_init_data = {
  test = function (self)
    -- static class properties,
    -- interesting for methods
    local A = Object:make_subclass("A")
    A.p_1 = "A/1"
    expect(A.p_1).is("A/1")
    local a = A()
    expect(rawget(a, "p_1")).is(nil)
    expect(a.p_1).is("A/1") --
    local AA = A:make_subclass("AA")
    local aa = AA()
    AA.p_2 = "AA/2"
    expect(rawget(aa, "p_1")).is(nil)
    expect(aa.p_1).is("A/1")
    expect(rawget(aa, "p_2")).is(nil)
    expect(aa.p_2).is("AA/2")
  end,
}

local test_cache = {
  do_test = function (self, o)
    expect(o).NOT(nil)
    expect(o:cache_get("foo")).is(nil)
    expect(o:cache_set("foo", 421)).is(true)
    expect(o:cache_get("foo")).is(421)
    o:unlock()
    expect(o:cache_get("foo")).is(nil)
    expect(o:cache_set("foo", 421)).is(false)
    expect(o:cache_get("foo")).is(nil)
    o:lock()
    expect(o:cache_get("foo")).is(nil)
    expect(o:cache_set("foo", 421)).is(true)
    expect(o:cache_get("foo")).is(421)
  end,
  test_basic = function (self)
    self:do_test(Object())
  end,
  test_subclass = function (self)
    local Subclass = Object:make_subclass("Subclass")
    self:do_test(Subclass)
    self:do_test(Subclass())
  end,
}

local test_hook = {
  test_basic = function (self)
    local o = Object()
    local track = {}
    local handler_1 = function (this, x)
      push(track, "handler_1")
      push(track, x)
    end
    local handler_2 = function (this, x)
      push(track, "handler_2")
      push(track, x)
    end
    local registration_1 = o:register_handler("foo", handler_1)
    o:call_handlers_for_name("foo", 1)
    expect(track).equals({ "handler_1", 1 })
    track = {}
    local registration_2 = o:register_handler("foo", handler_2)
    o:call_handlers_for_name("foo", 2)
    expect(track).equals({ "handler_1", 2, "handler_2", 2 })
    track = {}
    expect(o:unregister_handler(registration_2)).is(handler_2)
    o:call_handlers_for_name("foo", 3)
    expect(track).equals({ "handler_1", 3 })
    track = {}
    expect(o:unregister_handler(registration_1)).is(handler_1)
    o:call_handlers_for_name("foo", 4)
    expect(track).equals({})
    track = {}
    registration_2 = o:register_handler("foo", 1, handler_2)
    o:call_handlers_for_name("foo", 5)
    expect(track).equals({ "handler_2", 5 })
    track = {}
    registration_1 = o:register_handler("foo", 1, handler_1)
    o:call_handlers_for_name("foo", 6)
    expect(track).equals({ "handler_1", 6, "handler_2", 6 })
  end,
  test_no_handlers = function (self)
    Object:call_handlers_for_name("foo", 1, 2, 3)
  end,
  test_hierarchy = function (self)
    local track = {}
    local handler = function (x, tracker)
      x[tracker] = tracker
      return function (this)
        push(track, this[tracker])
      end
    end
    Object:register_handler("foo", handler(Object, "O1"))
    Object:register_handler("foo", handler(Object, "O2"))
    local A = Object:make_subclass("A")
    A:register_handler("foo", handler(A, "A1"))
    A:register_handler("foo", handler(A, "A2"))
    local AA = A:make_subclass("AA")
    AA:register_handler("foo", handler(AA, "AA:1"))
    AA:register_handler("foo", handler(AA, "AA:2"))
    local o = Object()
    o:register_handler("foo", handler(o, "o1"))
    o:register_handler("foo", handler(o, "o2"))
    local a = A()
    a:register_handler("foo", handler(a, "a1"))
    a:register_handler("foo", handler(a, "a2"))
    local aa = AA()
    aa:register_handler("foo", handler(aa, "aa:1"))
    aa:register_handler("foo", handler(aa, "aa:2"))
    local function test(x, expected)
      track = {}
      x:call_handlers_for_name("foo")
      expect(track).equals(expected)
    end
    -- test(Object, { "O1", "O2" })
    test(o, { "O1", "O2", "o1", "o2" })
    test(A, { "O1", "O2", "A1", "A2" })
    test(a, { "O1", "O2", "A1", "A2", "a1", "a2" })
    test(AA, { "O1", "O2", "A1", "A2", "AA:1", "AA:2" })
    test(aa, { "O1", "O2", "A1", "A2", "AA:1", "AA:2", "aa:1", "aa:2" })
    A:register_handler("foo", handler(A, "A3"))
    test(aa, { "O1", "O2", "A1", "A2", "A3", "AA:1", "AA:2", "aa:1", "aa:2" })
    Object.O1 = nil
    Object.O2 = nil
  end,
}
local test_private = {
  setup = function (self)
    self.key = _ENV.random_string()
    self.value = _ENV.random_number()
  end,
  test_Object = function (self)
    expect(Object:private_get(self.key)).is(nil)
    expect(Object:private_set(self.key, self.value)).is(Object)
    expect(Object:private_get(self.key)).is(self.value)
    expect(Object:private_set(self.key)).is(Object)
    expect(Object:private_get(self.key)).is(nil)
  end,
  test_o = function (self)
    local o = Object()
    expect(o:private_get(self.key)).is(nil)
    expect(o:private_set(self.key, self.value)).is(o)
    expect(o:private_get(self.key)).is(self.value)
    expect(o:private_set(self.key)).is(o)
    expect(o:private_get(self.key)).is(nil)
  end,
  test_OO = function (self)
    local OO = Object:make_subclass("Subclass")
    expect(OO:private_get(self.key)).is(nil)
    expect(OO:private_set(self.key, self.value)).is(OO)
    expect(OO:private_get(self.key)).is(self.value)
    expect(OO:private_set(self.key)).is(OO)
    expect(OO:private_get(self.key)).is(nil)
  end,
  test_oo = function (self)
    local OO = Object:make_subclass("OO")
    local oo = OO()
    expect(oo:private_get(self.key)).is(nil)
    expect(oo:private_set(self.key, self.value)).is(oo)
    expect(oo:private_get(self.key)).is(self.value)
    expect(oo:private_set(self.key)).is(oo)
    expect(oo:private_get(self.key)).is(nil)
  end,
}

local test_unique = {
  setup = function (self)
    -- NB: next type is declared but used only for testing purposes
    -- as type names are managed globally, we must take care of unique names
    ---@class test_unique_object_A: Object
    ---@field public foo string
    local A = Object:make_subclass("A")
    local unique = {}
    function A.__:initialize(kv)
      self.foo = kv.foo
    end
    function A.__.unique_get(kv)
      return unique[kv.foo]
    end
    function A.__:unique_set()
      unique[assert(self.foo, "Missing foo property")] = self
    end
    self.A = A
    local AA = A:make_subclass("AA")
    self.AA = AA
  end,
  test_instance = function (self)
    local a_1 = self.A({ foo = "bar" })
    local a_2 = self.A({ foo = "bar" })
    expect(a_1).is(a_2)
  end,
  test_subclass = function (self)
    local aa_1 = self.AA({ foo = "bar" })
    local aa_2 = self.AA({ foo = "bar" })
    expect(aa_1).is(aa_2)
  end
}
local test_newindex = {
  setup = function (self)
    self.A = 1
  end,
  test_standard = function (_self)
    ---@class test_newindex_A: Object
    ---@field public foo any
    local A = Object:make_subclass("A")
    local track = {}
    function A.__.getter:foo(k)
      return Object.private_get(self, k)
    end
    function A.__.setter:foo(k, v)
      local old = self[k]
      push(track, "old")
      push(track, old)
      push(track, "new")
      push(track, v or Object.NIL)
      Object.private_set(self, k, v)
      if v then
        expect(Object.private_get(self, k)).is(v)
      end
    end
    A.foo = _ENV.random_number()
    local a = A()
    local function test(x)
      track = {}
      local old_v = A.foo
      expect(x.foo).is(old_v) -- inherits the property from A
      local new_v = _ENV.random_number()
      x.foo = new_v
      expect(x.foo).is(new_v)
      expect(track).equals({ "old", A.foo, "new", x.foo})
      expect(x.foo).NOT(A.foo)
      track = {}
      x.foo = nil
      expect(track).equals({ "old", new_v, "new", Object.NIL})
      expect(x.foo).is(A.foo)
    end
    test(a)
    -- What about inheritance?
    ---@class test_newindex_AA: test_newindex_A
    local AA = A:make_subclass("AA")
    local aa = AA()
    do
      track = {}
      local old_v = A.foo
      expect(aa.foo).is(old_v) -- inherits the property from A
      local new_v = A.foo * 2 + 1
      aa.foo = new_v
      expect(aa.foo).is(new_v)
      expect(track).equals({ "old", A.foo, "new", aa.foo})
      expect(aa.foo).NOT(A.foo)
      track = {}
      aa.foo = nil
      expect(track).equals({ "old", new_v, "new", Object.NIL})
      expect(aa.foo).is(A.foo)
    end
    -- test(aa)
  end,
  test_computed = function (_self)
    ---@class test_newindex_A_2: Object
    ---@field public foo any
    ---@field public bar any
    local A = Object:make_subclass("A")
    function A.__.getter:foo(k)
      return self:private_get(k)
    end
    local track = {}
    function A.__.setter:foo(k, v)
      push(track, "A")
      push(track, self.__TYPE)
      push(track, k)
      self:private_set(k, v)
    end
    function A.__.setter:bar(k, v)
      push(track, "A")
      push(track, self.__TYPE)
      push(track, k)
      self:private_set(k, v)
    end
    local a = A()
    expect(a.foo).is(nil)
    a.foo = _ENV.random_string()
    expect(a.foo).type("string")
    expect(track).equals({ "A", "A", "foo", })
    track = {}
    a.foo = nil
    expect(a.foo).is(nil)
    expect(track).equals({ "A", "A", "foo", })
    local AA = A:make_subclass("AA")
    function AA.__.setter:foo(k, v)
      push(track, "AA")
      push(track, self.__TYPE)
      push(track, k)
      A.__.setter.foo(self, k, v)
    end
    function AA.__.setter:bar(k, v)
      push(track, "AA")
      push(track, self.__TYPE)
      push(track, k)
      self:private_set(k, v)
    end
    expect(A.__.setter.foo).NOT(AA.__.setter.foo)
    track = {}
    local aa = AA()
    aa.foo = _ENV.random_string()
    expect(track).equals({ "AA", "AA", "foo", "A", "AA", "foo", })
    track = {}
    aa.bar = _ENV.random_string()
    expect(track).equals({ "AA", "AA", "bar",})
  end,
}

return {
  test_POC                    = test_POC,
  test_Object                 = test_Object,
  test_cache                  = test_cache,
  test_getter                 = test_getter,
  test_constructor            = test_constructor,
  test_computed               = test_computed,
  test_finalize               = test_finalize,
  test_hook                   = test_hook,
  test_initialize             = test_initialize,
  test_init_data              = test_init_data,
  test_is_instance            = test_is_instance,
  test_is_instance_of         = test_is_instance_of,
  test_is_descendant_of       = test_is_descendant_of,
  test_key                    = test_key,
  test_make_another_subclass  = test_make_another_subclass,
  test_make_subclass          = test_make_subclass,
  test_newindex               = test_newindex,
  test_private                = test_private,
  test_unique                 = test_unique,
}
