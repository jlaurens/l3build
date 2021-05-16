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

local function test_Object()
  expect(Object).NOT(nil)
  expect(Object.__Super).is(nil)
  expect(Object.__Class).is(Object)
  expect(Object.__index()).is(nil)
  expect(Object()).NOT(nil)
  expect(Object()).NOT(nil)
end

local function test_make_subclass()
  expect(function () Object.make_subclass() end).error()
  local Foo = Object:make_subclass("Foo")
  expect(Foo.__Class).is(Foo)
  expect(Foo.__Super).is(Object)
  local Bar = Foo:make_subclass("Bar")
  expect(Bar.__Class).is(Bar)
  expect(Bar.__Super).is(Foo)
end

local function test_constructor()
  local Foo = Object:make_subclass("Foo")
  expect(Foo.__Class).is(Foo)
  expect(Foo.__TYPE).is("Foo")
  local foo = Foo()
  expect(foo.__Class).is(Foo)
  expect(foo.__TYPE).is("Foo")
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
  expect(Foo.__Super).is(Object)
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
  local Foo = Object:make_subclass("Foo", {
    __initialize = function (self, x)
      done = x
    end,
  })
  Foo({}, 421)
  expect(done).is(421)
end

local test_make_another_subclass = {
  test_computed = function (_self)
    
    local Class_1 = Object:make_subclass("Class_1", {
      __computed_index = function (self, k)
        if k == "foo_1" then
          return "bar_1"
        end
      end
    })
    expect(Class_1.__index(nil, "foo_1")).is("bar_1")
    expect(Class_1.__computed_index(nil, "foo_1")).is("bar_1")
    local instance_1 = Class_1()
    expect(instance_1.foo_1).is("bar_1")

    local Class_2a = Class_1:make_subclass("Class_2a" ,{
      __computed_index = function (self, k)
        if k == "foo_2a" then
          return "bar_2a"
        end
      end
    })
    expect(Class_2a.__index(nil, "foo_2a")).is("bar_2a")
    expect(Class_2a.__computed_index(nil, "foo_2a")).is("bar_2a")
    local instance_2a = Class_2a()
    expect(instance_2a.foo_2a).is("bar_2a")

    local Class_2b = Class_1:make_subclass("Class_2b", {
      __computed_index = function (self, k)
        if k == "foo_2b" then
          return "bar_2b"
        end
        return Class_1.__computed_index(self, k) -- inherits all computed properties
      end
    })
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
    expect(Class_1.__Super).is(Object)
    local Class_2  = Class_1:make_subclass("Class_2")
    expect(Class_2.__Super).is(Class_1)
    local Class_3  = Class_2:make_subclass("Class_3")
    expect(Class_3.__Super).is(Class_2)
    -- make instances
    local instance_1 = Class_1()
    expect(instance_1.__Class).is(Class_1)
    local instance_2 = Class_2()
    expect(instance_2.__Class).is(Class_2)
    local instance_3 = Class_3()
    expect(instance_3.__Class).is(Class_3)

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
    local Class  = Object:make_subclass("Class", {
      __initialize = function (self)
        self.foo = "bar"
      end
    })
    local instance = Class()
    expect(instance.foo).is("bar")
  end,

  test_initialize_param = function (_self)
    local Class  = Object:make_subclass("Class", {
      __initialize = function (self, x)
        self.foo = x
      end
    })
    local instance = Class({}, "bar")
    expect(instance.foo).is("bar")
  end,
}

-- where inheritance is illutsrated
local test_computed_index = {
  test_one_level = function ()
    local A = Object:make_subclass("A")
    expect(A.p_1).is(nil)
    local a = A()
    expect(a.p_1).is(nil)
    local old = A.__computed_index
    A.__computed_index = function (self, k)
      if k == "p_1" then
        return "A/1"
      end
    end
    expect(A.p_1).is(nil)
    expect(a.p_1).is("A/1")
    A.__computed_index = old
    expect(A.p_1).is(nil)
    expect(a.p_1).is(nil)
  end,
  test_two_levels = function ()
    local A = Object:make_subclass("A")
    expect(A.p_1).is(nil)
    local a = A()
    expect(a.p_1).is(nil)
    local AA = A:make_subclass("AA")
    expect(AA.p_1).is(nil)
    local aa = AA()
    expect(aa.p_1).is(nil)
    local old = A.__computed_index
    A.__computed_index = function (self, k)
      if k == "p_1" then
        return "A/1"
      end
    end
    expect(A.p_1).is(nil)
    expect(a.p_1).is("A/1")
    expect(AA.p_1).is("A/1")
    expect(aa.p_1).is("A/1")
    AA.__computed_index = function (self, k)
      if k == "p_1" then
        return "AA/1"
      end
    end
    expect(A.p_1).is(nil)
    expect(a.p_1).is("A/1")
    expect(AA.p_1).is("A/1")
    expect(aa.p_1).is("AA/1")
    A.__computed_index = old
    expect(A.p_1).is(nil)
    expect(a.p_1).is(nil)
    expect(AA.p_1).is(nil)
    expect(aa.p_1).is("AA/1")
  end,
  test_dynamic = function ()
    local A = Object:make_subclass("A")
    local a = A()
    local AA = A:make_subclass("AA")
    local aa = AA()
    A.__computed_index = function (self, k)
      if k == "p_1" then
        return "A/1"
      end
      if k == "p_2" then
        return self.p_1 .."/A/2"
      end
    end
    expect(a.p_1).is("A/1")
    expect(a.p_2).is("A/1/A/2")
    expect(AA.p_1).is("A/1")
    expect(AA.p_2).is("A/1/A/2")
    expect(aa.p_1).is("A/1")
    expect(aa.p_2).is("A/1/A/2")
    AA.p_1 = "AA/1"
    expect(a.p_1).is("A/1")
    expect(a.p_2).is("A/1/A/2")
    expect(AA.p_1).is("AA/1")     -- Change here
    expect(AA.p_2).is("AA/1/A/2") -- Change here
    expect(aa.p_1).is("AA/1")     -- Change here
    expect(aa.p_2).is("AA/1/A/2") -- Change here
    -- Revert
    AA.p_1 = nil
    expect(a.p_1).is("A/1")
    expect(a.p_2).is("A/1/A/2")
    expect(AA.p_1).is("A/1")
    expect(AA.p_2).is("A/1/A/2")
    expect(aa.p_1).is("A/1")
    expect(aa.p_2).is("A/1/A/2")
    -- Change only the `aa` instance property
    aa.p_1 = "aa/1"
    expect(a.p_1).is("A/1")
    expect(a.p_2).is("A/1/A/2")
    expect(AA.p_1).is("A/1")
    expect(AA.p_2).is("A/1/A/2")
    expect(aa.p_1).is("aa/1")     -- Change here
    expect(aa.p_2).is("A/1/A/2") -- But not here
    -- change both the class and instance properties
    AA.p_1 = "AA/1"
    aa.p_1 = "aa/1"
    expect(AA.p_1).is("AA/1")
    expect(AA.p_2).is("AA/1/A/2") -- Change here
    expect(aa.p_1).is("aa/1")     -- Different change here
    expect(aa.p_2).is("AA/1/A/2") -- and here
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
    local old = A.__computed_index
    A.__computed_index = function (self, k)
      if k == "p_1" then
        return "A/1"
      end
    end
    expect(A.p_1).is(nil)
    expect(a.p_1).is("A/1")
    expect(AA.p_1).is("A/1")
    expect(aa.p_1).is("A/1")
    AA.__computed_index = function (self, k)
      if k == "p_1" then
        return Object.NIL -- override `p_1` to nil
      end
    end
    expect(AA.p_1).is("A/1")
    expect(aa.p_1).is(nil) -- `p_1` is overriden to nil
    A.__computed_index = old
    expect(A.p_1).is(nil)
    expect(a.p_1).is(nil)
    expect(AA.p_1).is(nil)
    expect(aa.p_1).is(nil)
  end,
}

-- where inheritance is illutsrated
local test_instance_table = {
  test_one_level = function (_self)
    local A = Object:make_subclass("A")
    local a = A()
    expect(a.p_1).is(nil)
    A.__instance_table.p_1 = function (self)
      return "A/1"
    end
    expect(A.p_1).is(nil)
    expect(a.p_1).is("A/1")
    A.__instance_table.p_1 = function (self)
      return nil
    end
    expect(A.p_1).is(nil)
    expect(a.p_1).is(nil)
  end,
  test_two_levels = function (_self)
    local A = Object:make_subclass("A")
    local a = A()
    local AA = A:make_subclass("AA")
    local aa = AA()
    A.__instance_table.p_1 = function (self)
      return "A/1"
    end
    expect(A.p_1).is(nil)
    expect(a.p_1).is("A/1")
    expect(AA.p_1).is(nil)
    expect(aa.p_1).is("A/1")
    -- override instance property to some value
    AA.__instance_table.p_1 = function (self)
      return "AA/1"
    end
    expect(A.p_1).is(nil)
    expect(a.p_1).is("A/1")
    expect(AA.p_1).is(nil)
    expect(aa.p_1).is("AA/1")
    -- override instance property to nil
    AA.__instance_table.p_1 = function (self)
      return Object.NIL
    end
    expect(A.p_1).is(nil)
    expect(a.p_1).is("A/1")
    expect(AA.p_1).is(nil)
    expect(aa.p_1).is(nil)
    -- Revert to the initial setting
    AA.__instance_table.p_1 = nil
    expect(A.p_1).is(nil)
    expect(a.p_1).is("A/1")
    expect(AA.p_1).is(nil)
    expect(aa.p_1).is("A/1")
  end,
  test_dynamic = function (_self)
    local A = Object:make_subclass("A")
    local a = A()
    local AA = A:make_subclass("AA")
    local aa = AA()
    A.__instance_table.p_1 = function (self)
      return "A/1"
    end
    A.__instance_table.p_2 = function (self)
      return self.p_1 .."/A/2"
    end
    expect(a.p_1).is("A/1")
    expect(a.p_2).is("A/1/A/2")
    expect(AA.p_1).is(nil)
    expect(AA.p_2).is(nil)
    expect(aa.p_1).is("A/1")
    expect(aa.p_2).is("A/1/A/2")
    -- override the class property in the subclass:
    AA.__instance_table.p_1 = function (self)
      return "AA/1"
    end
    expect(AA.p_1).is(nil)
    expect(AA.p_2).is(nil)
    expect(aa.p_1).is("AA/1")
    expect(aa.p_2).is("AA/1/A/2")
    -- override the subclass instance property
    aa.p_1 = "aa/1"
    expect(aa.p_1).is("aa/1")
    expect(aa.p_2).is("aa/1/A/2") -- now the computed property refers to the instance
    -- revert to the initial state
    aa.p_1 = nil
    AA.__instance_table.p_1 = nil
    expect(aa.p_1).is("A/1")
    expect(aa.p_2).is("A/1/A/2")
  end
}

-- where inheritance is illutsrated
local test_class_table = {
  test_one_level = function (_self)
    local A = Object:make_subclass("A")
    local a = A()
    expect(a.p_1).is(nil)
    A.__class_table.p_1 = function (self)
      return "A/1"
    end
    expect(A.p_1).is(nil)
    expect(a.p_1).is("A/1")
    A.__class_table.p_1 = function (self)
      return nil
    end
    expect(A.p_1).is(nil)
    expect(a.p_1).is(nil)
  end,
  test_two_levels = function (_self)
    local A = Object:make_subclass("A")
    local a = A()
    local AA = A:make_subclass("AA")
    local aa = AA()
    A.__class_table.p_1 = function (self)
      return "A/1"
    end
    expect(A.p_1).is(nil)
    expect(a.p_1).is("A/1")
    expect(AA.p_1).is("A/1")
    expect(aa.p_1).is("A/1")
    -- override instance property to some value
    AA.__class_table.p_1 = function (self)
      return "AA/1"
    end
    expect(A.p_1).is(nil)
    expect(a.p_1).is("A/1")
    expect(AA.p_1).is("A/1")
    expect(aa.p_1).is("AA/1")
    -- override instance property to nil
    AA.__class_table.p_1 = function (self)
      return Object.NIL
    end
    expect(A.p_1).is(nil)
    expect(a.p_1).is("A/1")
    expect(AA.p_1).is("A/1")
    expect(aa.p_1).is(nil)
    -- Revert to the initial setting
    AA.__class_table.p_1 = nil
    expect(A.p_1).is(nil)
    expect(a.p_1).is("A/1")
    expect(AA.p_1).is("A/1")
    expect(aa.p_1).is("A/1")
  end,
  test_dynamic = function (_self)
    local A = Object:make_subclass("A")
    local a = A()
    local AA = A:make_subclass("AA")
    local aa = AA()
    A.__class_table.p_1 = function (self)
      return "A/1"
    end
    A.__class_table.p_2 = function (self)
      return self.p_1 .."/A/2"
    end
    expect(a.p_1).is("A/1")
    expect(a.p_2).is("A/1/A/2")
    expect(AA.p_1).is("A/1")
    expect(AA.p_2).is("A/1/A/2")
    expect(aa.p_1).is("A/1")
    expect(aa.p_2).is("A/1/A/2")
    -- override the class property in the subclass:
    AA.__class_table.p_1 = function (self)
      return "AA/1"
    end
    expect(AA.p_1).is("A/1")
    expect(AA.p_2).is("A/1/A/2")
    expect(aa.p_1).is("AA/1")
    expect(aa.p_2).is("AA/1/A/2")
    -- override the subclass instance property
    aa.p_1 = "aa/1"
    expect(aa.p_1).is("aa/1")
    expect(aa.p_2).is("aa/1/A/2") -- now the computed property refers to the instance
    -- revert to the initial state
    aa.p_1 = nil
    AA.__class_table.p_1 = nil
    expect(AA.p_1).is("A/1")
    expect(AA.p_2).is("A/1/A/2")
    expect(aa.p_1).is("A/1")
    expect(aa.p_2).is("A/1/A/2")
  end
}

local function test_key ()
  local A = Object:make_subclass("A", {
    __computed_index = function (self, k)
      if k == "key" then
        return self.__TYPE
      end
    end
  })
  local a = A()
  expect(a.key).is("A")
  local a_1 = setmetatable({}, A)
  expect(a_1.key).is("A")
  expect(A.key).is(nil)
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
    test(Object, { "O1", "O2" })
    test(o, { "O1", "O2", "o1", "o2" })
    test(A, { "O1", "O2", "A1", "A2" })
    test(a, { "O1", "O2", "A1", "A2", "a1", "a2" })
    test(AA, { "O1", "O2", "A1", "A2", "AA:1", "AA:2" })
    test(aa, { "O1", "O2", "A1", "A2", "AA:1", "AA:2", "aa:1", "aa:2" })
    A:register_handler("foo", handler(A, "A3"))
    test(aa, { "O1", "O2", "A1", "A2", "A3", "AA:1", "AA:2", "aa:1", "aa:2" })
  end,
}
local test_private = {
  setup = function (self)
    self.key = _ENV.random_string()
    self.value = _ENV.random_number()
  end,
  test_Object = function (self)
    expect(Object:get_private_property(self.key)).is(nil)
    expect(Object:set_private_property(self.key, self.value)).is(Object)
    expect(Object:get_private_property(self.key)).is(self.value)
    expect(Object:set_private_property(self.key)).is(Object)
    expect(Object:get_private_property(self.key)).is(nil)
  end,
  test_o = function (self)
    local o = Object()
    expect(o:get_private_property(self.key)).is(nil)
    expect(o:set_private_property(self.key, self.value)).is(o)
    expect(o:get_private_property(self.key)).is(self.value)
    expect(o:set_private_property(self.key)).is(o)
    expect(o:get_private_property(self.key)).is(nil)
  end,
  test_OO = function (self)
    local OO = Object:make_subclass("Subclass")
    expect(OO:get_private_property(self.key)).is(nil)
    expect(OO:set_private_property(self.key, self.value)).is(OO)
    expect(OO:get_private_property(self.key)).is(self.value)
    expect(OO:set_private_property(self.key)).is(OO)
    expect(OO:get_private_property(self.key)).is(nil)
  end,
  test_oo = function (self)
    local OO = Object:make_subclass("OO")
    local oo = OO()
    expect(oo:get_private_property(self.key)).is(nil)
    expect(oo:set_private_property(self.key, self.value)).is(oo)
    expect(oo:get_private_property(self.key)).is(self.value)
    expect(oo:set_private_property(self.key)).is(oo)
    expect(oo:get_private_property(self.key)).is(nil)
  end,
}

local function test_do_not_inherit()
  -- add a new property to `Object`
  -- create a hierarchy
  -- inherit or not this key
  local key = _ENV.random_string()
  local value = _ENV.random_string()
  local O = Object:make_subclass("O")
  local OO = O:make_subclass("OO")
  local oo = OO()
  Object[key] = value
  expect(O[key]).is(value)
  expect(OO[key]).is(value)
  expect(oo[key]).is(value)
  function O.__do_not_inherit(k)
    return k == key
  end
  expect(O[key]).is(nil)
  expect(OO[key]).is(nil)
  expect(oo[key]).is(nil)
  O.__do_not_inherit = Object.__do_not_inherit
  function OO.__do_not_inherit(k)
    return k == key
  end
  expect(O[key]).is(value)
  expect(OO[key]).is(nil)
  expect(oo[key]).is(nil)
  OO.__do_not_inherit = Object.__do_not_inherit
  O.__do_not_inherit = Object.__do_not_inherit
  function oo.__do_not_inherit(k)
    return k == key
  end
  expect(O[key]).is(value)
  expect(OO[key]).is(value)
  expect(oo[key]).is(nil)
  Object[key] = nil
end

return {
  test_Object                 = test_Object,
  test_make_subclass          = test_make_subclass,
  test_constructor            = test_constructor,
  test_is_instance            = test_is_instance,
  test_is_instance_of         = test_is_instance_of,
  test_is_descendant_of       = test_is_descendant_of,
  test_finalize               = test_finalize,
  test_initialize             = test_initialize,
  test_make_another_subclass  = test_make_another_subclass,
  test_computed_index         = test_computed_index,
  test_do_not_inherit         = test_do_not_inherit,
  test_instance_table         = test_instance_table,
  test_class_table            = test_class_table,
  test_key                    = test_key,
  test_init_data              = test_init_data,
  test_cache                  = test_cache,
  test_hook                   = test_hook,
  test_private                = test_private,
}