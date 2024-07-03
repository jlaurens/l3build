--[[
local insert = table.insert
local failures = {}
local check = function(arg, actual)
  local f = assert(io.popen("texlua ./l3build.lua custom-target "..arg, "r"))
  local output = assert(f:read("a"))
  f:close()
  if output ~= actual then
    insert()
  end
  assert(output == "target: custom-target\n", "FAILED")
end
local f = assert(io.popen("texlua ./l3build.lua custom-target","r"))
local output = assert(f:read("a"))
f:close()
assert(output == "target: custom-target\n", "FAILED")
]]

-- test names must remain simple.

test_types = {
  l3b = l3b_test_type,
}
test_order = { "l3b" }
testfiledir = "testfiles-l3b"

-- only one noop engine
stdengine = "texlua ./stdengine"
checkengines = { stdengine }
asciiengines = {}


function runtest_tasks(name,n,ext)
  -- launch 
  local cmd = "cd \""..lfs.currentdir().."\""..os_concat..
    "texlua "..arg[0].." custom-target-l3b"..
    (options["debug"] and " --debug" or "").." \""..
    escapepath(name).."\" "..
    ext
  return cmd
end
