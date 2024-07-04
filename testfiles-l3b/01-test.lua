l3btest:write("2+2=", 2+2)
local foo = 0
local f = function() foo = foo + 1 end
for _,type in ipairs({"windows", "msdos", "unix"}) do
  l3btest:on_os_type(type, f)
end
l3btest:write("on_os_type available", foo>0)
