local f = assert(io.popen("ls"))
print(f:read("a"))
generate(2+2)
