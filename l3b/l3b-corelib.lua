--[[

File l3b-corelib.lua Copyright (C) 2018-2020 The LaTeX Project

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

-- Autodoc lpeg patterns

---@module l3b-peg

-- Safeguard and shortcuts

local unpack  = table.unpack
local append  = table.insert
local concat  = table.concat
local max     = math.max

local lpeg    = require("lpeg")
local locale  = lpeg.locale()
local P       = lpeg.P
local R       = lpeg.R
local S       = lpeg.S
local C       = lpeg.C
local V       = lpeg.V
local B       = lpeg.B
local Cb      = lpeg.Cb
local Cc      = lpeg.Cc
local Cg      = lpeg.Cg
local Cmt     = lpeg.Cmt
local Cp      = lpeg.Cp
local Ct      = lpeg.Ct
local Cf      = lpeg.Cf

--[[ lpeg patterns
All forthcoming variables with suffix "_p" are
lpeg patterns or functions that return a lpeg pattern.
--]]

---Get the line number for the given string
---Should cache intermediate results.
---@param str   string
---@param index integer
---@return integer
local function get_line_number(str, index)
  local result = 1
  for j = 1, index do
    if str:sub(j, j) == "\n" then
      result = result + 1
    end
  end
  return result
end

---Make a shallow copy of the given object,
---taking the metatable into account.
---@generic T
---@param original T
---@return T
local function shallow_copy(original)
  local res = {}
  for k, v in next, original do
    res[k] = v
  end
  return setmetatable(res, getmetatable(original))
end

--https://gist.github.com/tylerneylon/81333721109155b2d244#gistcomment-3262222
---Make a deep copy of the given object
---@generic T
---@param original T
---@return T
local function deep_copy(original)
  local seen = {}
  local function f(obj)
    if type(obj) ~= 'table' then  -- return as is
      return obj
    end
    if seen[obj] then             -- return already seen if any
      return seen[obj]
    end
    local res = {}                                -- make a new table
    seen[obj] = res                               -- mark it as seen
    for k, v in next, obj do res[f(k)] = f(v) end -- copy recursively
    return setmetatable(res, getmetatable(obj))
  end
  return f(original)
end

--[==[ Bridge business
Some proxy of both primary and secondary tables,
with supplemental computed properties given by index.
--]==]

---@class bridge_kv_t
---@field public prefix    string
---@field public suffix    string
---@field public index     fun(t: table, k: any): any
---@field public newindex  fun(t: table, k: any, result: any): boolean
---@field public complete  fun(t: table, k: any, result: any): any
---@field public map       table<string,string>
---@field public primary   table @the main object, defaults to _G
---@field public secondary table @the secondary object

---Return a bridge to "global" variables
---@param kv bridge_kv_t
---@return table
local function bridge(kv)
  local MT = {}
  if kv then
    kv = shallow_copy(kv)
    MT.__index = function (self --[[: table]], k --[[: string]])
      if type(k) == "string" then
        if kv.map then
          k = kv.map[k]
          if not k then
            return
          end
        end
        local k_G = (kv.prefix or "") .. k .. (kv.suffix or "")
        local primary = kv.primary or _G
        local result  = primary[k_G]
        if result == nil and kv.index then
          result = kv.index(self, k)
        end
        if kv.complete then
          result = kv.complete(self, k, result)
        end
        if kv.secondary then
          local result_2 = kv.secondary[k_G]
          if  result ~= result_2 then
            if  type(result)   == "table"
            and type(result_2) == "table"
            then
              result = bridge({
                primary   = result,
                secondary = result_2
              })
            elseif result == nil then
              result = result_2
            end
          end
        end
        return result
      end
    end
    if kv.newindex then
      MT.__newindex = kv.newindex
    else
      MT.__newindex = function (self, k, v)
        assert(kv.newindex(self, k, v), "Readonly bridge ".. tostring(k) .." ".. tostring(v))
      end
    end
  else
    MT.__index = _G
    MT.__newindex = function (self, k, v)
      error("Readonly bridge".. tostring(k) .." ".. tostring(v))
    end
  end
  return setmetatable({}, MT)
end

---@class corelib_t
---@field public get_line_number    fun(s: string, i: integer): integer
---@field public bridge             fun(kv: bridge_kv_t): table
---@field public shallow_copy       fun(original: any): any

return {
  get_line_number     = get_line_number,
  bridge              = bridge,
  shallow_copy        = shallow_copy,
  deep_copy           = deep_copy,
}
