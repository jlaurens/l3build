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

--[===[
  This module implements some object oriented paradigm.
  It does not require any other module.
  It is based on pure `lua`.

  A class is a table that will be used as metatable of another table.

  An instance of a class is a table which metatable is built after the class.
  
  We will make the difference between properties and methods,
  either static or computed.

# The `Object` table

The module return a unique table considered as both the root class
and a namespace for static utilities.

For example, with `Object.private_get` and `Object.private_set`
we can assign private properties to lua objects,
which is extremely handy to hide some implementation details.
With lua, completely hiding everything is not possible,
but hiding some part makes life a bit easier.

# Instances

  Creating instances follows a simple syntax, the class also
playing the role of a constructor. Classes are callable such that
creating an instance of class `Foo` is made with `Foo(...)`.

The constructor accepts only one parameter which is a table.
It is the standard way of using named arguments.
Named arguments make sense here to avoid some extra management while subclassing.

# The classes

The `Object` class is the common ancestor of all classes.
The classes are used as metatable for their instances
and implement special '__' prefixed methods.

There is some need to other special methods and properties,
in particular for computed properties.
All these are collected in a table associated to the field `__`.
For example, this table points to the parent class from the field `Super`.

## the instances

# The class hierarchy

## The hierarchy chain

There are 2 fields dedicated to the class hierarchy.
Each instance's `__.Class` field points to its class.
The class object also has a `__.Class` field that points to itself.
The `is_instance` computed property allows to make the difference
between a class and an instance.

For each class, the `__.Super` field points to the parent class,
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
For static methods or properties, inheritance is ensured once each class
is the metatable of its derived class.
It works well as long as self is not needed along the whole chain.
For computed properties and methods, an accessor is collected like
other static methods, but it is must be run against the original self.

The most efficient manner to understand how things fit together
is by reading the tests in `l3b-object.test.lua`.

Basically, `__.get` is for class computed properties
whereas `__getter` is for instance computed properties.

--]===]
---@module object

local insert  = table.insert
local push    = insert
local remove  = table.remove

--[=[ Package implementation ]=]

local Object  = {}

-- hidden private properties
-- stored in an association table

local privacy = setmetatable({}, {
  __mode = "k",
})

---Get the named private property, if any
---@param key any
---@return any
function Object.private_get(object, key)
  local properties = privacy[object]
  return properties and properties[key]
end

---Set the private property for the given key
---@generic T: Object
---@param object T
---@param key any
---@param value any
---@return T @ the receiver
function Object.private_set(object, key, value)
  local properties = privacy[object]
  if not properties then
    properties = {}
    privacy[object] = properties
  end
  properties[key] = value
  return object
end

local cache_by_object = setmetatable({}, {
  __mode = "k",
})

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

-- hook mechanism

local handlers_by_object = setmetatable({}, {
  __mode = "k",
})

---@alias handler_f fun(self: Object,...):any,...

---@alias handler_registration_t any @ private structure

function Object:_handlers_for_name(name)
  local hooks_by_name = handlers_by_object[self]
  if not hooks_by_name then
    hooks_by_name = {}
    handlers_by_object[self] = hooks_by_name
  end
  local named_handlers = hooks_by_name[name]
  if not named_handlers then
    named_handlers = {
      ordered = {},
      by_key = {},
    }
    hooks_by_name[name] = named_handlers
  end
  return named_handlers
end

---Insert a hook handler for a given name
---When `pos` is not provided it defaults to the end of the list
---This is similar to lua's `table.insert`.
---@param name string
---@param pos? integer
---@param handler handler_f
---@return handler_registration_t
function Object:register_handler(name, pos, handler)
  local named_handlers = self:_handlers_for_name(name)
  if handler == nil then
    pos, handler = #named_handlers + 1, pos
  end
  local key = { name }
  insert(named_handlers, pos, {
    handler = handler,
    key = key,
  })
  return key
end

---Remove a previously inserted hook handler
---@param registration handler_registration_t
---@return handler_f|nil
function Object:unregister_handler(registration)
  local named_handlers = self:_handlers_for_name(registration[1])
  for i = 1, #named_handlers do
    local t = named_handlers[i]
    if t.key == registration then
      remove(named_handlers, i)
      return t.handler
    end
  end
end

---Iterator over all the handlers for the given name
---It takes care of inheritance
---@param name string
---@vararg any
function Object:call_handlers_for_name(name, ...)
  ---@type Object
  local o = self
  local hierarchy
  if o == o.__.Class then
    hierarchy = { }
  else
    hierarchy = { o }
    o = o.__.Class
  end
  while o do
    push(hierarchy, o)
    local super = o.__.Super
    if o ~= super then
      o = super
    else
      break
    end
  end
  for i = #hierarchy, 1, -1 do
    o = hierarchy[i]
    local named_handlers = o:_handlers_for_name(name)
    for j = 1, #named_handlers do
      named_handlers[j].handler(self, ...)
    end
  end
end

-- Object__ gathers the information that makes a class
-- It is the type of the `__`. field.
-- 
---@class Object__
---@field public Class          Object
---@field public Super          Object
---@field public initialize     fun(self: Object, kv: any)
---@field public getter         table<string,fun(self: Object, key: string): any>
---@field public setter         table<string,fun(self: Object, key: string, value: string): error_level_n, error_message_s>
---@field public complete       table<string,fun(self: Object, key: string, value: any): any>
---@field public get            fun(self: Object, key: string): any
---@field public set            fun(self: Object, key: string, value: string): error_level_n, error_message_s
---@field public index_will_return fun(self: Object, key: string, value: string)
---@field public MT             table

local Object__ = {
  getter    = {},
  setter    = {},
  complete  = {},
  get       = rawget,
  set       = rawset,
}

---@class Object @ Root class, metatable of other tables
---@field public  __TYPE            string
---@field public  make_subclass     fun(type: string, t: table): Object
---@field public  is_object         boolean @ always true, other tables will answer false
---@field public  is_instance       boolean
---@field public  is_class          boolean
---@field private __                Object__ @ collect here methods similar to __index, __newindex...

Object__.Class = Object
Object__.Super = Object

Object.__TYPE   = "Object"
Object.__ = Object__
Object.is_object    = true
Object.is_class     = true
Object.is_instance  = false

Object.__.getter = {
  is_object = function (self)
    return true
  end,
  is_instance = function (self)
    return rawget(self, "__") == nil
  end,
  is_class = function (self)
    return rawget(self, "__") ~= nil
  end,
}

---Last filter before return
---Default implementation returns false.
---@generic T: any
---@param k any
---@param v T
---@return T
function Object.__.index_will_return(self, k, v)
  return v
end

---@see __.get
Object.NIL = setmetatable({}, {
  __tostring = function (self)
    return "Object.NIL"
  end
})

---@class object_kv
---@field public data table|nil @ starting table

---Get the unique instance for the given parameters.
---The default implementation returns `nil`.
---@param kv object_kv
function Object.__.unique_get(kv)
end

---Make the receiver a unique instance for the given parameters.
---The default implementation does nothing.
function Object.__:unique_set()
end

---Finalize the class object
---Used when subclassing.
---The default implementation does nothing.
---@param self Object
function Object.__:finalize()
end

---Initialize instances
---Used by the constructor.
---The default implementation does nothing.
---@param self Object
---@param kv object_kv
function Object.__:initialize(kv)
  self:lock()
end

local function __index(class, self, k)
  local __ = class.__
  if k == "__" then
    return __
  end
  if k == "cache_get" then
    return (self == class and __.Super or class)[k]
  end
  local result = self:cache_get(k)
  if result == nil then
    local get = __.getter[k] or __.get
    result = get(self, k)
    if result == nil then
      result = (self == class and __.Super or class)[k]
    end
  end
  if result == Object.NIL then
    result = nil
  end
  local complete = __.complete[k]
  if complete then
    result = complete(self, k, result)
  end
  return __.index_will_return(class, k, result)
end

---Make the __newindex function for the given class
---Setters for computed properties.
---You have instance level setters versus class level setters
---The formers only apply to instances and are not inherited by subclassers.
---The latters apply to instances when there is no instance setter
---and are inherited by subclassers.
---@param class Object
local function __newindex(class, self, k, v)
  local set = class.__.setter[k]
  if set then
    -- named setter
    return set(self, k, v)
  end
  -- unnamed setter
  set = class.__.set
  return set and set(self, k, v) or rawset(self, k, v)
end

Object.__.MT = {
  __index     = function (this, k)
                  return __index(Object, this, k)
                end,
  __newindex  = function (this, k, v)
                  __newindex(Object, this, k, v)
                end,
}
---Constructor
--[===[
  All the constructors have a unique key/value argument.
Here `kv.data` is used as a template to build the instance.
The return value is the newly created instance or nil and
a message on error.

Each derived constructor key/value argument table is
also derived from the ancestor's constructor key/value argument table.
]===]
---@param kv object_kv|nil
---@return Object|nil
---@return nil|string
function Object:Constructor(kv)
  local instance = kv and kv.data or {}
  instance = setmetatable(instance, self.__.MT)
  instance:lock()
  return instance
end

setmetatable(Object, {
  __call = Object.Constructor,
})

local function constructor (self, kv)
  local __ = self.__
  -- call Super constructor
  local instance = __.unique_get(kv)
  if instance then
    return instance
  end
  instance = __.Super(kv)
  setmetatable(instance, __.MT)
  instance.__TYPE = self.__TYPE
  -- initialize without inheritance, it was made in the Super contructor
  local initialize = rawget(__, "initialize")
  if initialize then
    local msg = initialize(instance, kv)
    if msg then
      return nil, msg
    end
  end
  __.unique_set(instance)
  instance:lock()
  return instance
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
  assert(Super ~= nil)
  ---@type Object
  local class = static or {}
  assert(not getmetatable(class))
  assert(not class.__)
  class.__TYPE = TYPE
  class.__  = setmetatable({
    Super = Super, -- class hierarchy
    Class = class, -- class.__.Class == class
    -- metatable for instances
    MT = {
      __index = function(me, k)
                  return __index(class, me, k)
                end,
      __newindex =  function (me, k, v)
                      return __newindex(class, me, k, v)
                    end,
    }
  }, {
    -- other fields are static and created on the fly
    __index = function (self, k)
      local result
      if k == "getter" or k == "setter" then
        -- Query: Class.__.getter
        result = static and rawget(static, "__".. k) or {}
        result = setmetatable(result, {
          __index = Super.__[k],
        })
      else
        result = Super.__[k]
        if type(result) == "table" then
          -- Query Class.__.<other>_table
          local base = static and rawget(static, "__".. k) or {}
          base = setmetatable(base, {
            __index = result,
          })
        end
      end
      rawset(self, k, result)
      return result
    end
  })
  class.Constructor = constructor
  setmetatable(class, {
    __index = class.__.MT.__index,
    __newindex = class.__.MT.__newindex,
    __call  = constructor,
  })
  local finalize = rawget(class, "__finalize")
  if finalize then
    finalize(class)
  end
  class:lock()
  return class
end

---Whether the receiver is an instance of the given class
---false when no Class is given
---@param x any
---@return boolean
function Object.is_table(x)
  return type(x) == "table"
end

---Whether the receiver is an instance of the given class
---false when no Class is given
---@param Class table|nil
---@return boolean
function Object:is_instance_of(Class)
  if Class and self.is_instance then
    return self.__.Class == Class
  end
  return false
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
    what = what.__.Class
    repeat -- forever
      if what == Class then
        return true
      end
      if not what or what.__.Super == what then
        break
      end
      what = what.__.Super
    until false
  end
  return false
end

return Object
---@class __object_t
---@field private cache_by_object table
---@field private handlers_by_object table
, _ENV.during_unit_testing and {
  cache_by_object = cache_by_object,
  handlers_by_object = handlers_by_object,
}
