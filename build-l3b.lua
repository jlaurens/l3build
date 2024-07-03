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

if options["target"] == "custom-target-l3b" then
  -- only declare this target when needed.
  -- It will not appear in the help because it is purey internal
  -- hence the leading "_"
  declaretarget("custom-target-l3b", {
    func = function(names)
      if options["debug"] then
        print("target: custom-target-l3b")
      end
      local name = names[1]
      local ext = names[2]
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
      local generated = {}
      do
        local _ENV = setmetatable({}, {
          __index = _ENV
        })
        local function ordered_keys(t)
          local keys = {}
          for k,_ in pairs(x) do
            insert(keys,k)
          end
          sort(keys)
          return keys
        end
        testname = testname..ext
        if fileexists(testname) then
          _ENV.list = {}
          _ENV.generate = function(x, check) -- write the argument, including tables
            if type(x)=="table" then
              local stack = {}
              local keys = ordered_keys(x)
              local prefix = ""
              while true do
                if keys.next() then
                  local k = remove(keys, 0)
                  local v = x[k]
                  if type(v) == "table" then
                    insert(_ENV.list, prefix..tostring(k))
                    insert(stack,{
                      x = x,
                      keys = keys,
                      prefix = prefix,
                    })
                    x = v
                    keys = ordered_keys(x)
                    prefix = prefix.."  "
                  else
                    insert(_ENV.list, prefix..tostring(x))
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
            else
              insert(_ENV.list, tostring(x))
            end
          end
          local f, msg = loadfile(testname, "t", _ENV)
          assert(f, msg)
          f()
          generated = _ENV.list
        else
          print("NO "..testname)
        end
      end
      if saved_input then input(saved_input) end
      local f = assert(io.open(name_generated, "w"))
      f:write(concat(generated, "\n"))
      f:close()
      if options["debug"] then
        print("Generated: "..name_generated.." "..tostring(fileexists(name_generated)))
        print(concat(generated, "\n"))
      end
    end
  })
end
