l3btest:export()

write("2+2==4", PASS)
write("2+2==3", FAIL)
write("on_os_type available", PASS)

for _,type in ipairs{"windows", "msdos", "unix"} do
  on_os_type(type, function()
    write("os.type==\""..type.."\"")
  end)
end
