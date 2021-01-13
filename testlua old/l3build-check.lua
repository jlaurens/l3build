--[[

File l3build-check.lua Copyright (C) 2018-2020 The LaTeX3 Project

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

-- Local access to functions
local char             = string.char
local utf8_char        = unicode.utf8.char

--
-- Auxiliary functions which are used by more than one main function
--

-- Set up the check system files: needed for checking one or more tests and
-- for saving the test files
-- TODO: clean the other directories `testdir-config`
L3.checkinit = function (self)
  if not L3.options.dirty then
    FF.cleandir(V.testdir)
    FF.cleandir(V.resultdir)
  end
  self:depinstall(V.checkdeps)
  -- Copy dependencies to the test directory itself: this makes the paths
  -- a lot easier to manage, and is important for dealing with the log and
  -- with file input/output tests
  for _,i in ipairs(FF.filelist(V.localdir)) do
    FF.cp(i, V.localdir, V.testdir)
  end
  bundleunpack({V.sourcefiledir, V.testfiledir})
  for _,i in ipairs(V.installfiles) do
    FF.cp(i, V.unpackdir, V.testdir)
  end
  for _,i in ipairs(V.checkfiles) do
    FF.cp(i, V.unpackdir, V.testdir)
  end
  if FF.direxists(V.testsuppdir) then
    for _,i in ipairs(FF.filelist(V.testsuppdir)) do
      FF.cp(i, V.testsuppdir, V.testdir)
    end
  end
  for _,i in ipairs(V.checksuppfiles) do
    FF.cp(i, V.supportdir, V.testdir)
  end
  os.execute(FF.os_ascii .. ">" .. V.testdir .. "/ascii.tcx")
  return self:checkinit_hook()
end

L3.checkinit_hook = checkinit_hook or function() return 0 end

local function rewrite(source,result,processor,...)
  local file = assert(io.open(source,"rb"))
  local content = (file:read("a") .. "\n"):gsub("\r\n","\n")
  io.close(file)
  local new_content = processor(content,...)
  local newfile = io.open(result,"w")
  io.output(newfile)
  io.write(new_content)
  io.close(newfile)
end

-- Convert the raw log file into one for comparison/storage: keeps only
-- the 'business' part from the tests and removes system-dependent stuff
local function normalize_log(content,engine,errlevels)
  local maxprintline = V.maxprintline
  if engine:match("^(lua|harf)") then
    maxprintline = maxprintline + 1 -- Deal with an out-by-one error
  end
  local function killcheck(line)
      -- Skip \openin/\openout lines in web2c 7.x
      -- As Lua doesn't allow "(in|out)", a slightly complex approach:
      -- do a substitution to check the line is exactly what is required!
    return line:gsub("^\\openin", "\\openout"):match("^\\openout%d%d? = ")
  end
    -- Substitutions to remove some non-useful changes
  local function normalize(line,lastline,drop_fd)
    if drop_fd then
      if line:match(" *%)") then
        return "",""
      else
        return "","",true
      end
    end
    -- Zap line numbers from \show, \showbox, \box_show and the like:
    -- do this before wrapping lines
    line = line:gsub("^l%.%d+ ", "l. ...")
    -- Also from lua stack traces.
    line = line:gsub("lua:%d+: in function", "lua:...: in function")
    -- Allow for wrapped lines: preserve the content and wrap
    -- Skip lines that have an explicit marker for truncation
    if line:len() == maxprintline  and
       not line:match("%.%.%.$") then
      return "", (lastline or "") .. line
    end
    local line = (lastline or "") .. line
    lastline = ""
    -- Zap ./ at begin of filename
    line = line:gsub( "%(%.%/", "(")
    -- Zap paths
    -- The pattern excludes < and > as the image part can have
    -- several entries on one line
    local pattern = "%w?:?/[^ %<%>]*/([^/%(%)]*%.%w*)"
    -- Files loaded from TeX: all start ( -- )
    line = line:gsub("%(" .. pattern, "(../%1")
    -- Images
    line = line:gsub("<" .. pattern .. ">", "<../%1>")
    -- luaotfload files start with keywords
    line = line:gsub("from " .. pattern .. "%(", "from. ./%1(")
               :gsub(": " .. pattern .. "%)", ": ../%1)")
    -- Deal with XeTeX specials
    if line:match("^%.+\\XeTeX.?.?.?file") then
      line = line:gsub( pattern, "../%1")
    end
    -- Deal with dates
    if line:match("[^<]%d%d%d%d[/%-]%d%d[/%-]%d%d") then
        line = line:gsub("%d%d%d%d[/%-]%d%d[/%-]%d%d","....-..-..")
                   :gsub("v%d+%.?%d?%d?%w?","v...")
    end
    -- Deal with leading spaces for file and page number lines
    line = line:gsub("^ *%[(%d)","[%1")
               :gsub("^ *%(","(")
    -- Zap .fd lines: drop the first part, and skip to the end
    if line:match("^ *%([%.%/%w]+%.fd[^%)]*$") then
      return "","",true
    end
    -- TeX90/XeTeX knows only the smaller set of dimension units
    line = line:gsub(
      "cm, mm, dd, cc, bp, or sp",
      "cm, mm, dd, cc, nd, nc, bp, or sp")
    -- On the other hand, (u)pTeX has some new units!
               :gsub(
      "em, ex, zw, zh, in, pt, pc,",
      "em, ex, in, pt, pc,")
               :gsub(
      "cm, mm, dd, cc, bp, H, Q, or sp;",
      "cm, mm, dd, cc, nd, nc, bp, or sp;")
    -- Normalise a case where fixing a TeX bug changes the message text
               :gsub("\\csname\\endcsname ", "\\csname\\endcsname")
    -- Zap "on line <num>" and replace with "on line ..."
    -- Two similar cases, Lua patterns mean we need to do them separately
               :gsub("on line %d*", "on line ...")
               :gsub("on input line %d*", "on input line ...")
    -- Tidy up to ^^ notation
    for i = 0, 31 do
      line = line:gsub(char(i), "^^" .. char(64 + i))
    end
    -- Normalise register allocation to hard-coded numbers
    -- No regex, so use a pattern plus lookup approach
    local register_types = {
        attribute      = true,
        box            = true,
        bytecode       = true,
        catcodetable   = true,
        count          = true,
        dimen          = true,
        insert         = true,
        language       = true,
        luabytecode    = true,
        luachunk       = true,
        luafunction    = true,
        marks          = true,
        muskip         = true,
        read           = true,
        skip           = true,
        toks           = true,
        whatsit        = true,
        write          = true,
        XeTeXcharclass = true
      }
    if register_types[line:match("^\\[^%]]+=\\([a-z]+)%d+$")] then
      line = line:gsub("%d+$", "...")
    end
    -- Also deal with showing boxes
    if line:match("^> \\box%d+=(void)?$") then
      line = line:gsub("%d+=", "...=")
    end
    if not V.stdengine:match("^e?u?ptex$") then
      -- Remove 'normal' direction information on boxes with (u)pTeX
      line = line:gsub(",? yoko direction,?", "")
                 :gsub(",? yoko%(math%) direction,?", "")
      -- Remove '\displace 0.0' lines in (u)pTeX
      if line:match("^%.*\\displace 0%.0$") then
        return ""
       end
     end
    -- Deal with Lua function calls
    if line:match("^Lua function") then
      line = line:gsub("= %d+$","= ...")
    end
     -- Remove the \special line that in DVI mode keeps PDFs comparable
    if line:match("^%.*\\special%{pdf: docinfo << /Creator") or
      line:match( "^%.*\\special%{ps: /setdistillerparams") or
      line:match( "^%.*\\special%{! <</........UUID") then
      return ""
    end
     -- Remove \special lines for DVI .pro files
    if line:match("^%.*\\special%{header=") then
      return ""
    end
    if line:match("^%.*\\special%{dvipdfmx:config") then
      return ""
    end
    -- Remove the \special line possibly present in DVI mode for paper size
    if line:match("^%.*\\special%{papersize") then
      return ""
    end
    -- Remove ConTeXt stuff
    if line:match("^backend         >") or
      line:match( "^close source    >") or
      line:match( "^mkiv lua stats  >") or
      line:match( "^pages           >") or
      line:match( "^system          >") or
      line:match( "^used file       >") or
      line:match( "^used option     >") or
      line:match( "^used structure  >") then
      return ""
    end
    -- The first time a new font is used by LuaTeX, it shows up
    -- as being cached: make it appear loaded every time
    line = line:gsub("save cache:", "load cache:")
    -- A tidy-up to keep LuaTeX and other engines in sync
               :gsub(utf8_char(127), "^^?")
    -- Remove lua data reference ids
               :gsub("<lua data reference [0-9]+>",
                       "<lua data reference ...>")
    -- Unicode engines display chars in the upper half of the 8-bit range:
    -- tidy up to match pdfTeX if an ASCII engine is in use
    if next(V.asciiengines) then
      for i = 128, 255 do
        line = line:gsub(utf8_char(i), "^^" .. format("%02x", i))
      end
    end
    return line, lastline
  end
  local lastline = ""
  local drop_fd = false
  local new_content = ""
  local prestart = true
  local skipping = false
  for line in content:gmatch("([^\n]*)\n") do
    if line == "START-TEST-LOG" then
      prestart = false
    elseif line == "END-TEST-LOG" or
      line:match("^Here is how much of .?.?.?TeX\'s memory you used:") then
      break
    elseif line == "OMIT" then
      skipping = true
    elseif line:match("^%)?TIMO$") then
      skipping = false
    elseif not prestart and not skipping then
      line, lastline, drop_fd = normalize(line, lastline,drop_fd)
      if not line:match("^ *$") and not killcheck(line) then
        new_content = new_content .. line .. FF.os_newline
      end
    end
  end
  if V.recordstatus then
    new_content = new_content .. '***************' .. FF.os_newline
    for i = 1, V.checkruns do
      if (errlevels[i]==nil) then
        new_content = new_content ..
          'Compilation ' .. i .. ' of test file skipped ' .. FF.os_newline
      else
        new_content = new_content ..
          'Compilation ' .. i .. ' of test file completed with exit status ' ..
          errlevels[i] .. FF.os_newline
      end
    end
  end
  return new_content
end

-- Additional normalization for LuaTeX
local function normalize_lua_log(content,luatex)
  local function normalize(line, lastline, dropping)
    -- Find \discretionary or \whatsit lines:
    -- These may come back later
    if line:match("^%.+\\discretionary$")                or
       line:match("^%.+\\discretionary %(penalty 50%)$") or
       line:match("^%.+\\discretionary50%|$")            or
       line:match("^%.+\\discretionary50%| replacing $") or
       line:match("^%.+\\whatsit$")                      then
      return "", line
    end
    -- For \mathon, we always need this line but the next
    -- may be affected
    if line:match("^%.+\\mathon$") then
      return line, line
    end
    -- LuaTeX has a flexible output box
    line = line:gsub("\\box\\outputbox", "\\box255")
    -- LuaTeX identifies spaceskip glue
    line = line:gsub("%(\\spaceskip%) ", " ")
    -- Remove 'display' at end of display math boxes:
    -- LuaTeX omits this as it includes direction in all cases
    line = line:gsub( "(\\hbox%(.*), display$", "%1")
    -- Remove 'normal' direction information on boxes:
    -- any bidi/vertical stuff will still show
    line = line:gsub( ", direction TLT", "")
    -- Find glue setting and round out the last place
    local function round_digits(l, m)
      return l:gsub(
        m .. " (%-?)%d+%.%d+",
        m .. " %1"
          .. (("%.3f"):format(
            line:match(m .. " %-?(%d+%.%d+)") or 0
          ))
      )
    end
    if line:match("glue set %-?%d+%.%d+") then
      line = round_digits(line, "glue set")
    end
    if line:match(
      "glue %-?%d+%.%d+ plus %-?%d+%.%d+ minus %-?%d+%.%d+$") then
      line = round_digits(line, "glue")
      line = round_digits(line, "plus")
      line = round_digits(line, "minus")
    end
    -- LuaTeX writes ^^M as a new line, which we lose
    line = line:gsub( "%^%^M", "")
    -- Remove U+ notation in the "Missing character" message
    line = line:gsub(
        "Missing character: There is no (%^%^..) %(U%+(....)%)",
        "Missing character: There is no %1"
      )
    -- LuaTeX from v1.07 logs kerns differently ...
    -- This block only applies to the output of LuaTeX itself,
    -- hence needing a flag to skip the case of the reference log
    if luatex and
       tonumber(status.luatex_version) >= 107 and
       line:match("^%.*\\kern") then
       -- Re-insert the space in explicit kerns
       if line:match("kern%-?%d+%.%d+ *$") then
         line = line:gsub( "kern", "kern ")
       elseif line:match("%(accent%)$") then
         line = line:gsub( "kern", "kern ")
         line = line:gsub( "%(accent%)$", "(for accent)")
       elseif line:match("%(italic%)$") then
         line = line:gsub( "kern", "kern ")
         line = line:gsub( " %(italic%)$", "")
       else
         line = line:gsub( " %(font%)$", "")
       end
    end
    -- Changes in PDF specials
    line = line:gsub( "\\pdfliteral origin", "\\pdfliteral")
    -- A function to handle the box prefix part
    local function boxprefix(s)
      return s:match("^(%.+)"):gsub("%.", "%%.")
    end
    -- 'Recover' some discretionary data
    if lastline:match("^%.+\\discretionary %(penalty 50%)$") and
       line:match(boxprefix(lastline) .. "%.= ") then
       return line:gsub(" %(font%)$","")
                  :gsub( "%.= ", ""),
              ""
    end
    -- Where the last line was a discretionary, looks for the
    -- info one level in about what it represents
    if lastline:match("^%.+\\discretionary$")                or
       lastline:match("^%.+\\discretionary %(penalty 50%)$") or
       lastline:match("^%.+\\discretionary50%|$")            or
       lastline:match("^%.+\\discretionary50%| replacing $") then
      local prefix = boxprefix(lastline)
      if line:match(prefix .. "%.") or
         line:match(prefix .. "%|") then
         if lastline:match(" replacing $") and
            not dropping then
           -- Modify the return line
           return line:gsub("^%.", ""), lastline, true
         else
           return "", lastline, true
         end
      else
        if dropping then
          -- End of a \discretionary block
          return line, ""
        else
          -- Not quite a normal discretionary
          if lastline:match("^%.+\\discretionary50%|$") then
            lastline = lastline:gsub("50%|$", "")
          end
          -- Remove some info that TeX90 lacks
          lastline = lastline:gsub(" %(penalty 50%)$", "")
          -- A normal (TeX90) discretionary:
          -- add with the line break reintroduced
          return lastline .. FF.os_newline .. line, ""
        end
      end
    end
    -- Look for another form of \discretionary, replacing a "-"
    local pattern = "^%.+\\discretionary replacing *$"
    if line:match(pattern) then
      return "", line
    else
      if lastline:match(pattern) then
        local prefix = boxprefix(lastline)
        if line:match(prefix .. "%.\\kern") then
          return line:gsub("^%.", ""), lastline, true
        elseif dropping then
          return "", ""
        else
          return lastline .. FF.os_newline .. line, ""
        end
      end
    end
    -- For \mathon, if the current line is an empty \hbox then
    -- drop it
    if lastline:match("^%.+\\mathon$") then
      local prefix = boxprefix(lastline)
      if line:match(prefix .. "\\hbox%(0%.0%+0%.0%)x0%.0$") then
        return "", ""
      end
    end
    -- Various \local... things that other engines do not do:
    -- Only remove the no-op versions
    if line:match("^%.+\\localpar$")                or
       line:match("^%.+\\localinterlinepenalty=0$") or
       line:match("^%.+\\localbrokenpenalty=0$")    or
       line:match("^%.+\\localleftbox=null$")       or
       line:match("^%.+\\localrightbox=null$")      then
       return "", ""
    end
    -- Older LuaTeX versions set the above up as a whatsit
    -- (at some stage this can therefore go)
    if lastline:match("^%.+\\whatsit$") then
      local prefix = boxprefix(lastline)
      if line:match(prefix .. "%.") then
        return "", lastline, true
      else
        -- End of a \whatsit block
        return line, ""
      end
    end
    -- Wrap some cases that can be picked out
    -- In some places LuaTeX does use max_print_line, then we
    -- get into issues with different wrapping approaches
    if line:len() == V.maxprintline then
      return "", lastline .. line
    elseif lastline:len() == V.maxprintline then
      if line:match("\\ETC%.%}$") then
        -- If the line wrapped at \ETC we might have lost a space
        return lastline
          .. ((line:match("^\\ETC%.%}$") and " ") or "")
          .. line, ""
      elseif line:match("^%}%}%}$") then
        return lastline .. line, ""
      else
        return lastline .. FF.os_newline .. line, ""
      end
    -- Return all of the text for a wrapped (multi)line
    elseif lastline:len() > V.maxprintline then
      return lastline .. line, ""
    end
    -- Remove spaces at the start of lines: deals with the fact that LuaTeX
    -- uses a different number to the other engines
    return line:gsub( "^%s+", ""), ""
  end
  local new_content = ""
  local lastline = ""
  local dropping = false
  for line in content:gmatch("([^\n]*)\n") do
    line, lastline, dropping = normalize(line, lastline, dropping)
    if not line:match("^ *$") then
      new_content = new_content .. line .. FF.os_newline
    end
  end
  return new_content
end

local function normalize_pdf(content)
  local new_content = ""
  local stream_content = ""
  local binary = false
  local stream = false
  for line in content:gmatch("([^\n]*)\n") do
    if stream then
      if line:match("endstream") then
        stream = false
        if binary then
          new_content = new_content .. "[BINARY STREAM]" .. FF.os_newline
        else
           new_content = new_content .. stream_content .. line .. FF.os_newline
        end
        binary = false
      else
        for i = 0, 31 do
          if line:match(char(i)) then
            binary = true
            break
          end
        end
        if not binary and not line:match("^ *$") then
          stream_content = stream_content .. line .. FF.os_newline
        end
      end
    elseif line:match("^stream$") then
      binary = false
      stream = true
      stream_content = "stream" .. FF.os_newline
    elseif not line:match("^ *$") and
      not line:match("^%%%%Invocation") and 
      not line:match("^%%%%%+") then
      line = line:gsub("%/ID( ?)%[<[^>]+><[^>]+>]","/ID%1[<ID-STRING><ID-STRING>]")
      new_content = new_content .. line .. FF.os_newline
    end
  end
  return new_content
end

-- Look for a test: could be in the testfiledir or the unpackdir
local function testexists(test)
  return(FF.locate({V.testfiledir, V.unpackdir},
    {test .. V.lvtext, test .. V.pvtext}))
end

local function setup_check(self, name, engine)
  local testname = name .. "." .. engine
  local tlgfile = FF.locate(
    {V.testfiledir, V.unpackdir},
    {testname .. V.tlgext, name .. V.tlgext}
  )
  local tpffile = FF.locate(
    {V.testfiledir, V.unpackdir},
    {testname .. V.tpfext, name .. V.tpfext}
  )
  -- Attempt to generate missing reference file from expectation
  if not (tlgfile or tpffile) then
    if not FF.locate({V.unpackdir, V.testfiledir}, {name .. V.lveext}) then
      print(
        "Error: failed to find " .. V.tlgext .. ", " .. V.tpfext .. " or "
          .. V.lveext .. " file for " .. name .. "!"
      )
      os.exit(1)
    end
    self:runtest(name, engine, true, V.lveext)
    FF.ren(V.testdir, testname .. V.logext, testname .. V.tlgext)
  else
    -- Install comparison files found
    for _,v in pairs({tlgfile, tpffile}) do
      if v then
        FF.cp(
          v:match(".*/(.*)"),
          v:match("(.*)/.*"),
          V.testdir
        )
      end
    end
  end
end

-- Run one test which may have multiple engine-dependent comparisons
-- Should create a difference file for each failed test
L3.runcheck = function (self, name, hide)
  if not testexists(name) then
    print("Failed to find input for test " .. name)
    return 1
  end
  local checkengines = V.checkengines
  if L3.options.engine then
    checkengines = L3.options.engine
  end
  -- Used for both .lvt and .pvt tests
  local function check_and_diff(ext,engine,comp,pdftest)
    runtest(name,engine,hide,ext,pdftest,true)
    local errorlevel = comp(name,engine)
    if errorlevel == 0 then
      return errorlevel
    end
    if self.options["show-log-on-error"] then
      self:showfailedlog(name)
    end
    if self.options["halt-on-error"] then
      self:showfaileddiff()
    end
    return errorlevel
  end
  local errorlevel = 0
  for _,engine in pairs(checkengines) do
    setup_check(self, name, engine)
    local errlevel = 0
    if FF.fileexists(V.testfiledir .. "/" .. name .. V.pvtext) then
      errlevel = check_and_diff(V.pvtext,engine,compare_pdf,true)
    else
      errlevel = check_and_diff(V.lvtext,engine,compare_tlg)
    end
    if errlevel ~= 0 and L3.options["halt-on-error"] then
      return 1
    end
    if errlevel > errorlevel then
      errorlevel = errlevel
    end
  end
  -- Return everything
  return errorlevel
end

local function compare_pdf(name,engine,cleanup)
  local testname = name .. "." .. engine
  local difffile = V.testdir .. "/" .. testname .. V.pdfext .. FF.os_diffext
  local pdffile  = V.testdir .. "/" .. testname .. V.pdfext
  local tpffile  = FF.locate({V.testdir}, {testname .. V.tpfext, name .. tpfext})
  if not tpffile then
    return 1
  end
  local errorlevel = os.execute(FF.os_diffexe .. " "
    .. FF.normalize_path(tpffile .. " " .. pdffile .. " > " .. difffile))
  if errorlevel == 0 or cleanup then
    os.remove(difffile)
  end
  return errorlevel
end

function compare_tlg(name,engine,cleanup)
  local errorlevel
  local testname = name .. "." .. engine
  local difffile = V.testdir .. "/" .. testname .. FF.os_diffext
  local logfile  = V.testdir .. "/" .. testname .. V.logext
  local tlgfile  = FF.locate({V.testdir}, {testname .. V.tlgext, name .. V.tlgext})
  if not tlgfile then
    return 1
  end
  -- Do additional log formatting if the engine is LuaTeX, there is no
  -- LuaTeX-specific .tlg file and the default engine is not LuaTeX
  if (engine:match("^lua") or engine:match("^harf"))
    and not tlgfile:match("%.luatex" .. "%" .. V.tlgext)
    and not V.stdengine:match("^lua")
    then
    local lualogfile = logfile
    if cleanup then
      lualogfile = V.testdir .. "/" .. testname .. ".tmp" .. V.logext
    end
    local luatlgfile = V.testdir .. "/" .. testname .. V.tlgext
    rewrite(tlgfile,luatlgfile,normalize_lua_log)
    rewrite(logfile,lualogfile,normalize_lua_log,true)
    errorlevel = os.execute(FF.os_diffexe .. " "
      .. FF.normalize_path(luatlgfile .. " " .. lualogfile .. " > " .. difffile))
    if cleanup then
      os.remove(lualogfile)
      os.remove(luatlgfile)
    end
  else
    errorlevel = os.execute(FF.os_diffexe .. " "
      .. FF.normalize_path(tlgfile .. " " .. logfile .. " > " .. difffile))
  end
  if errorlevel == 0 or cleanup then
    os.remove(difffile)
  end
  return errorlevel
end

-- Run one of the test files: doesn't check the result so suitable for
-- both creating and verifying
L3.runtest = function (self, name, engine, hide, ext, pdfmode, breakout)
  local lvtfile = name .. (ext or V.lvtext)
  FF.cp(lvtfile, FF.fileexists(testfiledir .. "/" .. lvtfile)
    and V.testfiledir or V.unpackdir, V.testdir)
  local checkopts = V.checkopts
  local engine = engine or V.stdengine
  local binary = engine
  local format = engine:gsub("tex$",V.checkformat)
  -- Special binary/format combos
  if V.specialformats[V.checkformat] and next(V.specialformats[V.checkformat]) then
    local t = V.specialformats[V.checkformat]
    if t[engine] and next(t[engine]) then
      local t = t[engine]
      binary    = t.binary  or binary
      checkopts = t.options or checkopts
      format    = t.format  or format
    end
  end
  -- Finalise format string
  if format ~= "" then
    format = " --fmt=" .. format
  end
  -- Special casing for XeTeX engine
  if engine:match("xetex") and not pdfmode then
    checkopts = checkopts .. " -no-pdf"
  end
  -- Special casing for ConTeXt
  local function setup(file)
    return " -jobname=" .. name .. " " .. ' "\\input ' .. file .. '" '
  end
  if V.checkformat:match("^context$") then
    function setup(file) return ' "' .. file .. '" '  end
  end
  local basename = V.testdir .. "/" .. name
  local logfile = basename .. V.logext
  local newfile = basename .. "." .. engine .. V.logext
  local pdffile = basename .. V.pdfext
  local npffile = basename .. "." .. engine .. V.pdfext
  local asciiopt = ""
  for _,i in ipairs(V.asciiengines) do
    if binary == i then
      asciiopt = "-translate-file ./ascii.tcx "
      break
    end
  end
  -- Clean out any dynamic files
  for _,filetype in pairs(V.dynamicfiles) do
    FF.rm(V.testdir,filetype)
  end
  -- Ensure there is no stray .log file
  FF.rm(testdir,name .. logext)
  local errlevels = {}
  local localtexmf = ""
  if texmfdir and texmfdir ~= "" and FF.direxists(texmfdir) then
    localtexmf = FF.os_pathsep .. FF.abspath(texmfdir) .. "//"
  end
  for i = 1, checkruns do
    errlevels[i] = run(
      testdir,
      -- No use of localdir here as the files get copied to testdir:
      -- avoids any paths in the logs
      FF.os_setenv .. " TEXINPUTS=." .. localtexmf
        .. (checksearch and FF.os_pathsep or "")
        .. FF.os_concat ..
      FF.os_setenv .. " LUAINPUTS=." .. localtexmf
        .. (checksearch and FF.os_pathsep or "")
        .. FF.os_concat ..
      -- Avoid spurious output from (u)pTeX
      FF.os_setenv .. " GUESS_INPUT_KANJI_ENCODING=0"
        .. FF.os_concat ..
      -- Allow for local texmf files
      FF.os_setenv .. " TEXMFCNF=." .. FF.os_pathsep
        .. FF.os_concat ..
      (forcecheckepoch and L3:setepoch() or "") ..
      -- Ensure lines are of a known length
      FF.os_setenv .. " max_print_line=" .. maxprintline
        .. FF.os_concat ..
      binary .. format
        .. " " .. asciiopt .. " " .. checkopts
        .. setup(lvtfile)
        .. (hide and (" > " .. FF.os_null) or "")
        .. FF.os_concat ..
      runtest_tasks(FF.jobname(lvtfile),i)
    )
    -- Break the loop if the result is stable
    if breakout and i < checkruns then
      if pdfmode then
        if FF.fileexists(testdir .. "/" .. name .. dviext) then
          dvitopdf(name, testdir, engine, hide)
        end
        rewrite(pdffile,npffile,normalize_pdf)
        if compare_pdf(name,engine,true) == 0 then
          break
        end
      else
        rewrite(logfile,newfile,normalize_log,engine,errlevels)
        if compare_tlg(name,engine,true) == 0 then
          break
        end
      end
    end
  end
  if pdfmode and FF.fileexists(testdir .. "/" .. name .. dviext) then
    dvitopdf(name, testdir, engine, hide)
  end
  if pdfmode then
    FF.cp(name .. pdfext,testdir,resultdir)
    FF.ren(resultdir,name .. pdfext,name .. "." .. engine .. pdfext)
    rewrite(pdffile,npffile,normalize_pdf)
  else
    rewrite(logfile,newfile,normalize_log,engine,errlevels)
  end
  -- Store secondary files for this engine
  for _,filetype in pairs(auxfiles) do
    for _,file in pairs(FF.filelist(testdir, filetype)) do
      if file:match("^" .. name .. ".[^.]+$") then
        local ext = file:match("%.[^.]+$")
        if ext ~= lvtext and
           ext ~= tlgext and
           ext ~= lveext and
           ext ~= logext then
           local newname = file:gsub("(%.[^.]+)$","." .. engine .. "%1")
           if FF.fileexists(testdir,newname) then
             FF.rm(testdir,newname)
           end
           FF.ren(testdir,file,newname)
        end
      end
    end
  end
  return 0
end

-- A hook to allow additional tasks to run for the tests
runtest_tasks = runtest_tasks or function(name,run)
  return ""
end

L3.check = function (self, names)
  local errorlevel = 0
  if V.testfiledir ~= "" and FF.direxists(V.testfiledir) then
    if not self.options.rerun then
      self:checkinit()
    end
    local hide = true
    if names and #names then
      hide = false
    else
      names = {}
    end
    -- No names passed: find all test files
    if not #names then
      local excludenames = { }
      for _,glob in pairs(V.excludetests) do
        for _,name in pairs(FF.filelist(V.testfiledir, glob .. V.lvtext)) do
          excludenames[FF.jobname(name)] = true
        end
        for _,name in pairs(FF.filelist(V.unpackdir, glob .. V.lvtext)) do
          excludenames[FF.jobname(name)] = true
        end
        for _,name in pairs(FF.filelist(V.testfiledir, glob .. V.pvtext)) do
          excludenames[FF.jobname(name)] = true
        end
      end
      local function addname(name)
        if not excludenames[FF.jobname(name)] then
          names[#names+1] = FF.jobname(name)
        end
      end
      for _,glob in pairs(V.includetests) do
        for _,name in pairs(FF.filelist(V.testfiledir, glob .. V.lvtext)) do
          addname(name)
        end
        for _,name in pairs(FF.filelist(V.testfiledir, glob .. V.pvtext)) do
          addname(name)
        end
        for _,name in pairs(FF.filelist(V.unpackdir, glob .. V.lvtext)) do
          if FF.fileexists(V.testfiledir .. "/" .. name) then
            print("Duplicate test file: " .. i)
            return 1
          end
          addname(name)
        end
      end
      names:sort()
      -- Deal limiting range of names
      local firstname = self.options.first
      if firstname then
        local allnames = names
        local active = false
        names = { }
        for _,name in ipairs(allnames) do
          if name == firstname then
            active = true
          end
          if active then
            names[#names+1] = name
          end
        end
      end
      local lastname = self.options.last
      if lastname then
        local allnames = names
        names = { }
        for _,name in ipairs(allnames) do
          names[#names+1] = name
          if name == lastname then
            break
          end
        end
      end
    end
    -- https://stackoverflow.com/a/32167188
    local function shuffle(tbl)
      local len, random = #tbl, math.random
      for i = len, 2, -1 do
          local j = random(1, i)
          tbl[i], tbl[j] = tbl[j], tbl[i]
      end
      return tbl
    end
    if self.options.shuffle then
      names = shuffle(names)
    end
    -- Actually run the tests
    print("Running checks on")
    local i = 0
    for _,name in ipairs(names) do
      i = i + 1
      print("  " .. name .. " (" ..  i.. "/" .. #names ..")")
      local errlevel = self:runcheck(name, hide)
      -- Return value must be 1 not errlevel
      if errlevel ~= 0 then
        if self.options["halt-on-error"] then
          return 1
        else
          errorlevel = 1
          -- visually show that something has failed
          print("          --> failed\n")
        end
      end
    end
    if errorlevel ~= 0 then
      self:checkdiff()
    else
      print("\n  All checks passed\n")
    end
  end
  return errorlevel
end

-- A short auxiliary to print the list of differences for check
L3.checkdiff = function (self)
  print("\n  Check failed with difference files")
  for _,i in ipairs(FF.filelist(testdir, "*" .. FF.os_diffext)) do
    print("  - " .. V.testdir .. "/" .. i)
  end
  print("")
end

L3.showfailedlog = function (self, name)
  print("\nCheck failed with log file")
  for _,i in ipairs(FF.filelist(V.testdir, name..".log")) do
    print("  - " .. V.testdir .. "/" .. i)
    print("")
    local f = io.open(V.testdir .. "/" .. i,"r")
    local content = f:read("a")
    io.close(f)
    print("-----------------------------------------------------------------------------------")
    print(content)
    print("-----------------------------------------------------------------------------------")
  end
end

L3.showfaileddiff = function ()
  print("\nCheck failed with difference file")
  for _,i in ipairs(FF.filelist(V.testdir, "*" .. FF.os_diffext)) do
    print("  - " .. V.testdir .. "/" .. i)
    print("")
    local f = io.open(V.testdir .. "/" .. i,"r")
    local content = f:read("a")
    io.close(f)
    print("-----------------------------------------------------------------------------------")
    print(content)
    print("-----------------------------------------------------------------------------------")
  end
end

L3.save = function (self, names)
  self:checkinit()
  local engines = L3.options.engine or {V.stdengine}
  if names == nil then
    print("Arguments are required for the save command")
    return 1
  end
  for _,name in pairs(names) do
    if testexists(name) then
      for _,engine in pairs(engines) do
        local testengine = ((engine == V.stdengine and "") or "." .. engine)
        local function save_test(test_ext,gen_ext,out_ext,pdfmode)
          local out_file = name .. testengine .. out_ext
          local gen_file = name .. "." .. engine .. gen_ext
          print("Creating and copying " .. out_file)
          self:runtest(name,engine,false,test_ext,pdfmode)
          FF.ren(V.testdir,gen_file,out_file)
          FF.cp(out_file,V.testdir,V.testfiledir)
          if FF.fileexists(V.unpackdir .. "/" .. out_file) then
            print("Saved " .. out_ext
              .. " file overrides unpacked version of the same name")
            return 1
          end
          return 0
        end
        local errorlevel
        if FF.fileexists(V.testfiledir .. "/" .. name .. lvtext) then
          errorlevel = save_test(V.lvtext,V.logext,V.tlgext)
        else
          errorlevel = save_test(V.pvtext,V.pdfext,V.tpfext,true)
        end
        if errorlevel ~=0 then return errorlevel end
      end
    elseif FF.locate({V.unpackdir, V.testfiledir}, {name .. V.lveext}) then
      print("Saved " .. V.tlgext .. " file overrides a "
        .. V.lveext .. " file of the same name")
      return 1
    else
      print('Test "' .. name .. '" not found')
      return 1
    end
  end
  return 0
end
