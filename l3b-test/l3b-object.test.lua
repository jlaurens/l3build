local Object = require("l3b-object")

local expect  = require("l3b-test/expect").expect

function _G.test_Object()
  expect(Object).NOT(nil)
  expect(Object.__Super).is(nil)
  expect(Object.__Class).is(Object)
  expect(Object.__index).is(Object)
  expect(Object()).NOT(nil)
  expect(Object()).NOT(nil)
end

function _G.test_make_subclass()
  expect(function () Object.make_subclass() end).error()
  local Foo = Object:make_subclass("Foo")
  expect(Foo.__Class).is(Foo)
  expect(Foo.__Super).is(Object)
  local Bar = Foo:make_subclass("Bar")
  expect(Bar.__Class).is(Bar)
  expect(Bar.__Super).is(Foo)
end

function _G.test_constructor()
  local Foo = Object:make_subclass("Foo")
  expect(Foo.__Class).is(Foo)
  expect(Foo.__TYPE).is("Foo")
  local foo = Foo()
  expect(foo.__Class).is(Foo)
  expect(foo.__TYPE).is("Foo")
end

function _G.test_is_instance_of()
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

function _G.test_is_descendant_of()
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

function _G.test_finalize()
  local done
  local Foo = Object:make_subclass("Foo", {
    __finalize = function (class)
      done = class.__TYPE
    end,
  })
  expect(done).is("Foo")
end

function _G.test_initialize()
  local done
  local Foo = Object:make_subclass("Foo", {
    __initialize = function (self, x)
      done = x
    end,
  })
  Foo({}, 421)
  expect(done).is(421)
end

_G.test_make_another_subclass = {
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
