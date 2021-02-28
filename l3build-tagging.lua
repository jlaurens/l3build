--[[

File l3build-tagging.lua Copyright (C) 2018-2020 The LaTeX Project

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

local open    = io.open
local os_date = os.date
local match   = string.match
local gsub    = string.gsub

local util    = require("l3b.util")
local entries = util.entries
local keys    = util.keys

update_tag = update_tag or function(filename,content,tagname,tagdate)
  return content
end

function tag_hook(tagname,tagdate)
  return 0
end

local function update_file_tag(file,tagname,tagdate)
  local filename = basename(file)
  print("Tagging  ".. filename)
  local f = assert(open(file,"rb"))
  local content = f:read("*all")
  f:close()
  -- Deal with Unix/Windows line endings
  content = gsub(content .. (match(content,"\n$") and "" or "\n"),
    "\r\n", "\n")
  local updated_content = update_tag(filename,content,tagname,tagdate)
  if content == updated_content then
    return 0
  else
    local path = dirname(file)
    ren(path,filename,filename .. ".bak")
    f = assert(open(file,"w"))
    -- Convert line ends back if required during write
    -- Watch for the second return value!
    f:write((gsub(updated_content,"\n",os_newline)))
    f:close()
    rm(path,filename .. ".bak")
  end
  return 0
end

function tag(tagnames)
  local tagdate = options["date"] or os_date("%Y-%m-%d")
  local tagname = nil
  if tagnames then
    tagname = tagnames[1]
  end
  local dirs = remove_duplicates({currentdir, sourcefiledir, docfiledir})
  local errorlevel = 0
  for dir in entries(dirs) do
    for filetype in entries(tagfiles) do
      for file in keys(tree(dir,filetype)) do
        errorlevel = update_file_tag(dir .. "/" .. file,tagname,tagdate)
        if errorlevel ~= 0 then
          return errorlevel
        end
      end
    end
  end
  return tag_hook(tagname,tagdate)
end

