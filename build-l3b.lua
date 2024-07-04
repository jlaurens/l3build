-- Build script for LaTeX "l3build" files
-- imported by `build.lua`

local concat = table.concat
local insert = table.insert
local remove = table.remove
local sort   = table.sort

local input  = io.input

---@type L3BTestType
---@diagnostic disable-next-line: lowercase-global
l3b_test_type = {
  test = "-test.lua",
  reference = "-reference.txt",
  generated = "-generated.txt",
  expectation = "-expectation.lua",
  rewrite = function(source, normalized, engine, errorcode)
    assert(fileexists(source))
      -- raw copy
    assert(source~=normalized)
    local cmd = ("cp \"%s\" \"%s\""):format(source, normalized)
    if options["debug"] then
      print("l3b.rewrite: source: "..source.." "..tostring(fileexists(source)))
      print("l3b.rewrite: normalized: "..normalized)
      print("cmd: "..cmd)
    end
    return os.execute(cmd)
  end,
  naming = function(name, engine)
    return name..".l3b"
  end
}

---@class L3BTestGenerator
---@field PASS true convenient alias
---@field FAIL false convenient alias
---@field generated string[]
---@field new fun(): L3BTestGenerator 
L3BTestGenerator = {
  PASS = true,
  FAIL = false
}

---Designated creator
---@return L3BTestGenerator
function L3BTestGenerator.new()
  return setmetatable({
    generated = {}
  }, {
    __index = L3BTestGenerator
  })
end

local function ordered_keys(t)
  local keys = {}
  for k,_ in pairs(t) do
    insert(keys,k)
  end
  sort(keys)
  return keys
end

---Generate output for testing
---@param self L3BTestGenerator
---@param label string
---@param x any
function L3BTestGenerator:write(label, x) -- write the argument, including tables
  insert(self.generated, "Test: "..label)
  if type(x)=="table" then
    local stack = {}
    local keys = ordered_keys(x)
    local prefix = ""
    while true do
      if keys.next() then
        local k = remove(keys, 0)
        local v = x[k]
        if type(v) == "table" then
          insert(self.generated, prefix..tostring(k))
          insert(stack,{
            x = x,
            keys = keys,
            prefix = prefix,
          })
          x = v
          keys = ordered_keys(x)
          prefix = prefix.."  "
        else
          insert(self.generated, prefix..tostring(x))
        end
      else
        local top = remove(stack)
        if top then
          x = top.x
          keys = top.keys
          prefix = top.prefix
        else
          break
        end
      end
    end
  elseif type(x) == "boolean" then
    insert(self.generated, (x and "PASS" or "FAIL"))
  elseif x then
    insert(self.generated, x)
  else
    local f = load("return "..label)
    if f then
      insert(self.generated, (f() and "PASS" or "FAIL"))
    end
  end
end

local os_type = os.type

---comment
---@param type "windows"|"msdos"|"unix"
---@param f fun(...):...
---@param ... unknown
function L3BTestGenerator:on_os_type(type, f, ...)
  if type == os_type then
    f(...)
  end
end

---Disable `on_os_type`
---@param message string error message
function L3BTestGenerator:disable_on_os_type(message)
  self.on_os_type = function(type, f, ...)
    error(message)
  end
end

---Save to file the written strings
---@param self L3BTestGenerator
---@param path string
---@return boolean? status true on success, false on failure
---@return string? message error message on failure, nil otherwise
function L3BTestGenerator:save(path)
  local f, msg = io.open(path, "w")
  if not f then
    return f, msg
  end
  insert(self.generated,"")
  f:write(concat(self.generated, "\n"))
  f:close()
  if options["debug"] then
    print("L3BTestGenerator.save: "..path.." "..tostring(fileexists(path)))
    print(concat(self.generated, "\n"))
  end
  return true
end

---@class L3BTestGenerator
---@field import fun(self: L3BTestGenerator, env: table) Import symbols to the given environment

---Import symbols to the given environment
---@param env table
function L3BTestGenerator:export_symbols(env)
  env.PASS = self.PASS
  env.FAIL = self.FAIL
  env.write = function(...) self:write(...) end
  env.on_os_type = function(...) self:on_os_type(...) end
end

---Export the symbols to the current environment
---The default implementation does nothing
function L3BTestGenerator:export()
end

local custom_target = "custom-target-l3b"
if options["target"] == custom_target then
  -- only declare this target when needed.
  -- It will not appear in the help because it is purey internal
  -- hence the leading "_"
  declaretarget(custom_target, {
    func = function(names)
      if options["debug"] then
        print("target: "..custom_target)
      end
      local target = names[1]
      local name = names[2]
      local ext = names[3]
      local savedtestfiledir = testfiledir
      dofile("./config-l3b.lua")
      testdir = testdir .. "-config-l3b"
      -- Reset testsuppdir if required
      -- this is what `l3build.lua` does, expose this part?
      if savedtestfiledir ~= testfiledir and
        testsuppdir == savedtestfiledir .. "/support" then
        testsuppdir = testfiledir .. "/support"
      end
      ---@type string
      local testname = testdir.."/"..name -- relative to root directory.
      local name_generated = testname..l3b_test_type.generated
      if not fileexists(testname..l3b_test_type.test) then
        cp(name..l3b_test_type.test, testfiledir, testdir)
      end
      local in_expectation = fileexists(testfiledir.."/"..name..l3b_test_type.expectation)
      ---@type file*?
      local saved_input = nil -- saved output
      local input_name = testname.."-input.txt"
      if fileexists(input_name) then -- comes from the support directory
        saved_input = input()
        input(input_name)
      end
      if options["debug"] then
        print("Generating: "..name_generated)
      end
      do
        testname = testname..ext
        if fileexists(testname) then
          local l3btest = L3BTestGenerator.new()
          if target == "save" or not in_expectation then
            l3btest:disable_on_os_type("on_os_type is only available in expectations."..testname)
          end
          local _ENV = setmetatable(
            {l3btest = l3btest},
            {__index = _ENV}
          )
          -- allow to import symbols
          function l3btest:export()
            l3btest:export_symbols(_ENV)
          end
          local f = assert(loadfile(testname,"t",_ENV))
          f()
          if saved_input then input(saved_input) end
          l3btest:save(name_generated)
        else
          print("NO "..testname)
        end
      end
    end
  })
end

-- This target is used to retrieve information
custom_target = "l3b-check-load"
if options["target"] == custom_target then
  declaretarget(custom_target, {
    func = function(names)
      if options["debug"] then
        print("target: "..custom_target)
      end
      local chunk = assert("return "..names[1])
      local f = assert(load(chunk))
      print("<l3b-check-load>"..f().."</l3b-check-load>")
      return 0
    end
  })
end
