#!/usr/bin/env texlua
--[[
  This is a test file for l3build package.
  It is only intending for development and should appear in any distribution of the l3build package.
  For help, run `texlua ../l3build.lua test -h`
--]]

local Object = require("l3b-object")

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

return {
  test_Object                = test_Object,
  test_make_subclass         = test_make_subclass,
  test_constructor           = test_constructor,
  test_is_instance           = test_is_instance,
  test_is_instance_of        = test_is_instance_of,
  test_is_descendant_of      = test_is_descendant_of,
  test_finalize              = test_finalize,
  test_initialize            = test_initialize,
  test_make_another_subclass = test_make_another_subclass,
  test_computed_index        = test_computed_index,
  test_instance_table        = test_instance_table,
  test_class_table           = test_class_table,
  test_key                   = test_key,
  test_init_data             = test_init_data,
  
}