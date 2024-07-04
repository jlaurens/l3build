local status, message = pcall(normalise_epoch)
l3btest:write("`normalise_epoch()` -> error", not status)
---@diagnostic disable-next-line: undefined-field
l3btest:write("normalize_epoch error message contains `nil`", message:match("nil") ~= nil)

l3btest:write("normalise_epoch(\"2024-07-03\")==1719961200")
l3btest:write("normalise_epoch(1719961201)==1719961201")
