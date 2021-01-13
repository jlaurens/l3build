--[[

File l3build-tagging.lua Copyright (C) 2018-2020 The LaTeX3 Project

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

local FF = L3.require('file-functions')

local open    = io.open
local FF.os_date = os.date
local match   = string.match
local gsub    = string.gsub

update_tag = update_tag or function(filename,content,tagname,tagdate)
  return content
end

function tag_hook(tagname,tagdate)
  return 0
end

local function update_file_tag(file,tagname,tagdate)
  local filename = FF.basename(file)
  print("Tagging  ".. filename)
  local f = assert(open(file,"rb"))
  local content = f:read("*all")
  f:close()
  -- Deal with Unix/Windows line endings
  content = (content .. (content:match("\n$") and "" or "\n"))
    :gsub("\r\n", "\n")
  local updated_content = update_tag(filename,content,tagname,tagdate)
  if content == updated_content then
    return 0
  else
    local path = FF.dirname(file)
    FF.ren(path,filename,filename .. ".bak")
    local f = assert(open(file,"w"))
    -- Convert line ends back if required during write
    -- Watch for the second return value!
    f:write((updated_content:gsub("\n",FF.os_newline)))
    f:close()
    FF.rm(path,filename .. ".bak")
  end
  return 0
end

function tag(tagnames)
  local tagdate = L3.options.date or FF.os_date("%Y-%m-%d")
  local tagname = nil
  if tagnames then
    tagname = tagnames[1]
  end
  local dirs = FF.remove_duplicates({currentdir, sourcefiledir, docfiledir})
  local errorlevel = 0
  for _,dir in pairs(dirs) do
    for _,filetype in pairs(tagfiles) do
      for file,_ in pairs(FF.tree(dir,filetype)) do
        errorlevel = update_file_tag(dir .. "/" .. file,tagname,tagdate)
        if errorlevel ~= 0 then
          return errorlevel
        end
      end
    end
  end
  return tag_hook(tagname,tagdate)
end

