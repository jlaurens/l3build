--[[

File l3b-autodoc.lua Copyright (C) 2018-2020 The LaTeX Project

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

---@class Object @ Root class
---@field private __computed_table  table<string,fun(self: Object): any>

Object = {}

---For computed properties
---The default implementation does nothing.
---Used by subclassers.
---@param self Object
---@param k string
---@return any
---@see #make_subclass
function Object.__computed_index(self, k)
end

Object.__computed_table = {}
Object.__index = Object
Object.__Class = Object
Object.__TYPE  = "Object"

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
---@param class? T @ Will become the newly created class table
---@return T
function Object.make_subclass(Super, TYPE, class)
  assert(Super ~= nil)
  assert(Super ~= class)
  ---@type Object
  class = class or {}
  assert(not class.__Class)
  class.__TYPE = TYPE
  class.__Super = Super -- class hierarchy
  setmetatable(class, Super)
  class.__Class = class -- more readable than __index

  -- computed properties are inherited by default
  -- either defined directly or by key
  class.__computed_table = rawget(class, "__computed_table")
      or {}
  setmetatable(class.__computed_table, {
      __index = Super.__computed_table
  })
  class.__computed_index
    =  class.__computed_index
    or Super.__computed_index
  class.__index = function (self, k)
    local result = class.__computed_index(self, k)
    if result == nil then
      local computed_k = class.__computed_table[k]
      result = computed_k and computed_k(self)
      if result == nil then
        result = rawget(class, k)
        if result == nil then
          result = Super[k]
        end
      end
    end
    return result
  end
  -- Define the constructor with a direct call syntax
  -- @param class any
  -- @param d?    any @ iniatail data of the construction, will be the instance result
  -- @vararg any      @ parameters to the `initialize` function
  function class:Constructor(d, ...)
    d = Super(d, ...) -- call Super constructor first
    setmetatable(d, class)   -- d is an instance of self
    d.__TYPE = class[TYPE]
    -- initialize without inheritance, it was made in the Super contructor
    local initialize = rawget(class, "__initialize")
    if initialize then
      initialize(d, ...)
    end
    return d
  end
  setmetatable(class, {
    __index = Super,
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
  return Class and self.__Class == Class or false
end

---Whether the receiver inherits the given class
---Returns true iff Class is in the class hierarchy
---@param Class any
---@return boolean
function Object:is_descendant_of(Class)
  if Class then
    local what = self
    repeat
      if what:is_instance_of(Class) then
        return true
      end
      what = what.__Super
    until not what
  end
  return false
end

return Object