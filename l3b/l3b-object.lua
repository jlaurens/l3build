--[[

File l3b-object.lua Copyright (C) 2018-2020 The LaTeX Project

It may be distributed and/or modified under the conditions of the
LaTeX Project Public License (LPPL), either version 1.3c of this
license or (at your option) any later version.  The latest version
of this license is in the file

   http://www.latex-project.org/lppl.txt

This file is part of the "l3build bundle" (The Work in LPPL)
and all files in that bundle must be distributed together.

-----------------------------------------------------------------------

The development version of the bundle can be found at

   https://github.com/latex3/l3build

for those people who are interested.

--]]

---@module object
--[===[
  This module implements some object oriented paradigm.
  It does not require any other module.

  A class is a table that will be used as metatable of another table.

  An instance of a class is a table which metatable is the class.
  Some indirection may be required but that is not the case here.

  We will make the difference between properties and methods,
  either static or computed.

# Instances

  Creating instances follows a simple syntax, the class also
playing the role of a constructor. Classes are callable such that
creating an instance of class `Foo` is made with `Foo(...)`
with appropriate parameters.

# The class hierarchy

## The hierarchy chain

There are 2 fields dedicated to the class hierarchy.
Each instance's `__Class` field points to its class.
The class object also has a `__Class` field that points to itself.
The `is_instance` computed property allows to make the difference
between a class and an instance.

For each class, the `__Super` field points to the parent class,
if any. The `is_descendant_of` property tells if an object or a class
is a descendant of another class.

The class named `Object` is the root class. It has no superclass
and all other classes are descendants of it, whether directly or not.
Each class, starting from `Object`, has a `make_subclass` method to create subclasses.

## Inheritance

An instance will inherit properties and methods from its class
and all the classes above in the class hierarchy.
A class will inherit properties and methods from all the classes above.

There are two inheritance mechanisms: one for static properties and methods,
and one for computed properties and methods.
In fact the distinction between both is not as clear
because of the versatility of the language.

The most efficient manner to understand how things fit together
is by reading the tests in `l3b-object.test.lua`.
Basically, `__computed_index` is for class computed properties
whereas `__instance_table` is for instance computed properties.

--]===]

---@class Object @ Root class, metatable of other tables
---@field public  make_subclass     fun(type: string, t: table): Object
---@field public  is_instance       boolean
---@field private __computed_index  fun(self: Object, key: string): any
---@field private __instance_table  table<string,fun(self: Object): any>

Object = {
  __TYPE      = "Object",
  is_instance = false,
}
Object.__Class = Object

---comment
---@param self Object
---@param k any
function Object.__index(self, k) end

Object.__class_table = {
  is_instance = function (self)
    return self.__Class ~= self
  end
}

---For computed properties
---The default implementation does nothing.
---Used by subclassers.
---@param self Object
---@param k string
---@return any
---@see #make_subclass
function Object.__computed_index(self, k)
end

---@see __computed_index
Object.NIL = setmetatable({}, {
  __tostring = function (self)
    return "Object.NIL"
  end
})

function Object:Constructor(d, ...)
  return d or {}
end

setmetatable(Object, {
  __call = Object.Constructor,
})

---Finalize the class object
---Used when subclassing.
---The default implementation does nothing.
---@param self Object
function Object:__finalize()
end

---Initialize instances
---Used by the constructor.
---The default implementation does nothing.
---@param self Object
---@vararg any
function Object:__initialize(...)
  self:lock()
end

local function make_class__index(class)
  return function (self, k)
    if k == "__Class" then
      return class
    end
    if k == "cache_get" then
      return class == self and class.__Super[k] or class[k]
    end
    -- first cached properties
    local result = self and self:cache_get(k)
    if result ~= nil then
      if result == Object.NIL then
        return nil
      end
      return result
    end
    -- second: dynamic instance properties
    local computed_k
    if self and self ~= self.__Class then
      computed_k = class.__instance_table[k]
      if computed_k ~= nil then
        result = computed_k(self, k)
        if result ~= nil then
          if result == Object.NIL then
            return nil
          end
          return result
        end
      end
    end
    computed_k = class.__class_table[k]
    if computed_k ~= nil then
      result = computed_k(self, k)
      if result ~= nil then
        if result == Object.NIL then
          return nil
        end
        return result
      end
    end
    result = class.__computed_index(self, k)
    if result ~= nil then
      if result == Object.NIL then
        return nil
      end
      return result
    end
    return class[k]
  end
end

local function make_constructor(class)
  -- Define the constructor with a direct call syntax
  -- @param class any
  -- @param d?    any @ initial data of the construction, will be the instance result
  -- @vararg any      @ parameters to the `initialize` function
  return function (self, d, ...)
    -- call Super constructor
    -- `first` recors if the `d` param was given
    local first = type(d) ~= "table" and d or nil
    if first then
      d = class.__Super(nil, first, ...)
    else
      d = class.__Super(d, ...)
    end
    setmetatable(d, class)   -- d is an instance of self
    d.__TYPE = class.__TYPE
    -- initialize without inheritance, it was made in the Super contructor
    local initialize = rawget(class, "__initialize")
    if initialize then
      if first then
        initialize(d, first, ...)
      else
        initialize(d, ...)
      end
    end
    return d
  end
end

---Class making method
--[===[
  All classes are descendants of `Object`
@ Usage
```
Foo = Object:make_subclass()
Bar = Foo:make_subclass({...})
```
--]===]
---@generic T: Object
---@param Super Object
---@param TYPE string @ unique identifier, used with `type`
---The "static" data of the class
---@param static? T @ Will become the newly created class table
---@return T
function Object.make_subclass(Super, TYPE, static)
  ---@type Object
  local class = static or {}
  assert(not getmetatable(class))
  assert(not class.__Class)
  assert(Super ~= nil)
  class.__TYPE = TYPE
  class.__Super = Super -- class hierarchy
  class.__Class = class -- more readable than __index

  -- computed properties are inherited by default
  -- either defined directly or by key
  class.__instance_table = rawget(class, "__instance_table")
      or {}
  setmetatable(class.__instance_table, {
      __index = Super.__instance_table
  })
  class.__class_table = rawget(class, "__class_table")
      or {}
  setmetatable(class.__class_table, {
      __index = Super.__class_table
  })

  class.__computed_index
    =  class.__computed_index
    or Super.__computed_index
  ---comment
  ---@param self Object
  ---@param k any
  ---@return any
  class.__index = make_class__index(class)
  class.Constructor = make_constructor(class)
  setmetatable(class, {
    __index = function (self, k)
      local result = rawget(Super, k)
      if result ~= nil then
        return result
      end
      return Super.__index(self, k)
    end,
    __call  = class.Constructor,
  })
  local finalize = rawget(class, "__finalize")
  if finalize then
    finalize(class)
  end
  return class
end

---Whether the receiver is an instance of the given class
---@param Class table | nil
---@return boolean
function Object:is_instance_of(Class)
  return Class and self.__Class == Class and self.__Class ~= self or false
end

---Whether the receiver inherits the given class
---Returns true iff Class is in the class hierarchy
---@param Class any
---@return boolean
function Object:is_descendant_of(Class)
  if Class then
    local what = self
    if what:is_instance_of(Class) then
      return true
    end
    what = what.__Class
    repeat
      if what == Class then
        return true
      end
      what = what.__Super
    until not what
  end
  return false
end

local cache_by_object = setmetatable({}, {
  __mode = "k",
})
local function cache_clean(self)
  local result = {}
  cache_by_object[self] = {}
  return result
end

local function get_cache_for_object(self)
  return cache_by_object[self] or cache_clean(self)
end

---Get the cache value for the given key
---@param key any
---@return any
function Object:cache_get(key)
  local cache = cache_by_object[self]
  if cache then
    local result = cache[key]
    if result ~= nil then
      return result
    end
  end
end

---Set the cache value for the given key.
---@param key any
---@param value any
---@return boolean @ true when cached, false otherwise
function Object:cache_set(key, value)
  local cache = cache_by_object[self]
  if cache then
    cache[key] = value
    return true
  end
  return false
end

---Locked object can have a cache
function Object:lock()
  if not cache_by_object[self] then
    cache_by_object[self] = {}
  end
end

---Delete the cache as side effect
function Object:unlock()
  cache_by_object[self] = nil
end

return Object
