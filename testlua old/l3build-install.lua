--[[

File l3build-install.lua Copyright (C) 2018-2020 The LaTeX3 Project

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
local V = L3.require('variables')

local function gethome()
  local p = L3.options.texmfhome
  if not p then
    L3.set_program_name("latex")
    p = L3.var_value("TEXMFHOME")
  end
  return FF.abspath(p)
end

L3.uninstall = function (self)
  local function zapdir(dir)
    local installdir = gethome() .. "/" .. dir
    if self.options["dry-run"] then
      local files = FF.filelist(installdir)
      if next(files) then
        print("\n" .. "For removal from " .. installdir .. ":")
        for _,file in pairs(FF.filelist(installdir)) do
          print("- " .. file)
        end
      end
      return 0
    else
      if FF.direxists(installdir) then
        return FF.rmdir(installdir)
      end
    end
    return 0
  end
  local function uninstall_files(dir,subdir)
    dir = dir .. "/" .. (subdir or V.moduledir)
    return zapdir(dir)
  end
  local errorlevel = 0
  -- Any script man files need special handling
  local manfiles = { }
  for _,glob in pairs(V.scriptmanfiles) do
    for file,_ in pairs(FF.tree(V.docfiledir,glob)) do
      -- Man files should have a single-digit extension: the type
      local installdir = gethome() .. "/doc/man/man"  .. file:match(".$")
      if FF.fileexists(installdir .. "/" .. file) then
        if L3.options["dry-run"] then
          manfiles[#manfiles+1] = "man" .. file:match(".$") .. "/" ..
          select(2,FF.splitpath(file))
        else
          errorlevel = errorlevel + FF.rm(installdir,file)
        end
      end
    end
  end
  if next(manfiles) then
    print("\n" .. "For removal from " .. gethome() .. "/doc/man:")
    for _,v in ipairs(manfiles) do
      print("- " .. v)
    end
  end
  errorlevel = uninstall_files("doc")
         + uninstall_files("source")
         + uninstall_files("tex")
         + uninstall_files("bibtex/bst",module)
         + uninstall_files("makeindex",module)
         + uninstall_files("scripts",module)
         + errorlevel
  if errorlevel ~= 0 then return errorlevel end
  -- Finally, clean up special locations
  for _,location in ipairs(V.tdslocations) do
    local path,_ = FF.splitpath(location)
    errorlevel = zapdir(path)
    if errorlevel ~= 0 then return errorlevel end
  end
  return 0
end

L3.install_files = function (self, dir,full,dry_run)

  -- Needed so paths are only cleaned out once
  local cleanpaths = {}
  -- Collect up all file data before copying:
  -- ensures no files are lost during clean-up
  local installmap = {}

  local function create_install_map(source,dir,files,subdir)
    -- For material associated with secondary tools (BibTeX, MakeIndex)
    -- the structure needed is slightly different from those items going
    -- into the tex/doc/source trees
    if (dir == "makeindex" or dir:match("$bibtex")) and V.module == "base" then
      subdir = "latex"
    else
      subdir = subdir or V.moduledir
    end
    dir = dir .. (subdir and ("/" .. subdir) or "")
    local filenames = { }
    local sourcepaths = { }
    local paths = { }
    -- Generate a file list and include the directory
    for _,glob_table in pairs(files) do
      for _,glob in pairs(glob_table) do
        for file,_ in pairs(FF.tree(source,glob)) do
          -- Just want the name
          local path,filename = FF.splitpath(file)
          local sourcepath = "/"
          if path == "." then
            sourcepaths[filename] = source
          else
            path = path:gsub("^%.","")
            sourcepaths[filename] = source .. path
            if not V.flattentds then sourcepath = path .. "/" end
          end
          local matched = false
          for _,location in ipairs(V.tdslocations) do
            local path,glob = FF.splitpath(location)
            local pattern = FF.glob_to_pattern(glob)
            if filename:match(pattern) then
              paths[#paths+1] = path
              filenames[#filenames+1] = path .. sourcepath .. filename
              matched = true
              break
            end
          end
          if not matched then
            paths[#paths+1] = dir
            filenames[#filenames+1] = dir .. sourcepath .. filename
          end
        end
      end
    end

    local errorlevel = 0
    -- The target is only created if there are actual files to install
    if next(filenames) then
      if not dry_run then
        for _,path in pairs(paths) do
          local dir = dir .. "/" .. path
          if not cleanpaths[dir] then
            errorlevel = FF.cleandir(dir)
            if errorlevel ~= 0 then return errorlevel end
          end
          cleanpaths[dir] = true
        end
      end
      for _,file in ipairs(filenames) do
        if dry_run then
          print("- " .. file)
        else
          local path,file = FF.splitpath(file)
          installmap[#installmap+1] = 
            {file = file, source = sourcepaths[file], dest = dir .. "/" .. path}
        end
      end
    end
    return 0
  end

  local errorlevel = unpack()
  if errorlevel ~= 0 then return errorlevel end

    -- Creates a 'controlled' list of files
    local function excludelist(dir,include,exclude)
      include = include or { }
      exclude = exclude or { }
      dir = dir or V.currentdir
      local includelist = { }
      local excludelist = { }
      for _,glob_table in pairs(exclude) do
        for _,glob in pairs(glob_table) do
          for file,_ in pairs(FF.tree(dir,glob)) do
            excludelist[file] = true
          end
        end
      end
      for _,glob in pairs(include) do
        for file,_ in pairs(FF.tree(dir,glob)) do
          if not excludelist[file] then
            includelist[#includelist+1] = file
          end
        end
      end
      return includelist
    end

  local installlist = excludelist(V.unpackdir,V.installfiles,{V.scriptfiles})

  if full then
    errorlevel = doc()
    if errorlevel ~= 0 then return errorlevel end
    -- For the purposes here, any typesetting demo files need to be
    -- part of the main typesetting list
    local typesetfiles = V.typesetfiles
    for _,glob in pairs(V.typesetdemofiles) do
      typesetfiles[#typesetfiles+1] = glob
    end

    -- Find PDF files
    V.pdffiles = { }
    for _,glob in pairs(typesetfiles) do
      V.pdffiles[#V.pdffiles+1] = glob:gsub("%.%w+$",".pdf")
    end

    -- Set up lists: global as they are also needed to do CTAN releases
    V.typesetlist = excludelist(V.docfiledir,V.typesetfiles,{V.sourcefiles})
    V.sourcelist = excludelist(V.sourcefiledir,V.sourcefiles,
      {V.bstfiles,V.installfiles,V.makeindexfiles,V.scriptfiles})
 
  if dry_run then
    print("\nFor installation inside " .. dir .. ":")
  end 
    
    errorlevel = create_install_map(V.sourcefiledir,"source",{V.sourcelist})
      + create_install_map(V.docfiledir,"doc",
          {V.bibfiles,V.demofiles,V.docfiles,V.pdffiles,V.textfiles,V.typesetlist})
    if errorlevel ~= 0 then return errorlevel end

    -- Rename README if necessary
    if not dry_run then
      if V.ctanreadme ~= "" and not V.ctanreadme:lower():match("^readme%.%w+") then
        local installdir = dir .. "/doc/" .. V.moduledir
        if FF.fileexists(installdir .. "/" .. V.ctanreadme) then
          FF.ren(installdir,V.ctanreadme,"README." .. V.ctanreadme:match("%.(%w+)$"))
        end
      end
    end

    -- Any script man files need special handling
    local manfiles = { }
    for _,glob in pairs(V.scriptmanfiles) do
      for file,_ in pairs(FF.tree(docfiledir,glob)) do
        if dry_run then
          manfiles[#manfiles+1] = "man" .. file:match(".$") .. "/" ..
            select(2,FF.splitpath(file))
        else
          -- Man files should have a single-digit extension: the type
          local installdir = dir .. "/doc/man/man"  .. file:match(".$")
          errorlevel = errorlevel + FF.mkdir(installdir)
          errorlevel = errorlevel + FF.cp(file,docfiledir,installdir)
        end
      end
    end
    if next(manfiles) then
      for _,v in ipairs(manfiles) do
        print("- doc/man/" .. v)
      end
    end
  end

  if errorlevel ~= 0 then return errorlevel end

  errorlevel = create_install_map(V.unpackdir,"tex",{installlist})
    + create_install_map(V.unpackdir,"bibtex/bst",{V.bstfiles},module)
    + create_install_map(V.unpackdir,"makeindex",{V.makeindexfiles},module)
    + create_install_map(V.unpackdir,"scripts",{V.scriptfiles},module)

  if errorlevel ~= 0 then return errorlevel end

  -- Files are all copied in one shot: this ensures that FF.cleandir()
  -- can't be an issue even if there are complex set-ups
  for _,v in ipairs(installmap) do
    errorlevel = FF.cp(v.file,v.source,v.dest)
    if errorlevel ~= 0  then return errorlevel end
  end 
  
  return 0
end

L3.install = function (self)
  return self:install_files(gethome(),L3.options.full,L3.options["dry-run"])
end

