l3btest:export()

write("2+2==4")
write("2+2==3")

local foo = 0
local f = function() foo = foo + 1 end
on_os_type("windows", f)
on_os_type("msdos",   f)
on_os_type("unix",    f)
write("on_os_type available", foo>0)

local os_type = os.type
local g = function() write("os.type==\""..os_type.."\"") end
for _,type in ipairs{"windows", "msdos", "unix"} do
  on_os_type(type, g)
end
