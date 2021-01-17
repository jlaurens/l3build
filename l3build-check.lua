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

-- Local safe guards

local open             = io.open
local close            = io.close
local write            = io.write
local output           = io.output

local rnd              = math.random

local luatex_version   = status.luatex_version

local char             = string.char
local format           = string.format

local sort             = table.sort

local utf8_char        = unicode.utf8.char

local exit             = os.exit
local execute          = os.execute
local remove           = os.remove

local L3B = L3B
local Opts = Opts

-- Global tables

local OS   = L3B.require('OS'  )
local Aux  = L3B.require('Aux' )
local FS   = L3B.require('FS'  )
local V    = L3B.require('Vars')
local Pack = L3B.require('Pack')
local Tpst = L3B.require('Tpst')

-- Module

local Chk = L3B.provide('Chk')

--
-- Auxiliary functions which are used by more than one main function
--

-- Set up the check system files: needed for checking one or more tests and
-- for saving the test files
local function check_init()
  if not Opts.dirty then
    FS.cleandir(FS.dir.test)
    FS.cleandir(FS.dir.result)
  end
  Aux.depinstall(V.checkdeps)
  -- Copy dependencies to the test directory itself: this makes the paths
  -- a lot easier to manage, and is important for dealing with the log and
  -- with file input/output tests
  for _, i in ipairs(FS.filelist(FS.dir.local)) do
    FS.cp(i, FS.dir.local, FS.dir.test)
  end
  Pack.bundleunpack({ FS.dir.sourcefile, FS.dir.testfile })
  for _, i in ipairs(V.installfiles) do
    FS.cp(i, FS.dir.unpack, FS.dir.test)
  end
  for _, i in ipairs(V.checkfiles) do
    FS.cp(i, FS.dir.unpack, FS.dir.test)
  end
  if FS.direxists(FS.dir.testsupp) then
    for _, i in ipairs(FS.filelist(FS.dir.testsupp)) do
      FS.cp(i, FS.dir.testsupp, FS.dir.test)
    end
  end
  for _, i in ipairs(V.checksuppfiles) do
    FS.cp(i, FS.dir.support, FS.dir.test)
  end
  execute(OS.ascii .. ">" .. FS.dir.test .. "/ascii.tcx")
  return V.checkinit_hook()
end

local function translate(source, result, translator, ...)
  local f = assert(open(source, "rb"))
  local before = (f:read("a") .. "\n"):gsub("\r\n", "\n")
  f:close()
  local after = translator(before, ...)
  f = open(result, "w")
  output(f)
  write(after)
  f:close()
end

-- Convert the raw log file into one for comparison/storage: keeps only
-- the 'business' part from the tests and removes system-dependent stuff
local function normalize_log(content, engine, errlevels)
  local maxprintline = V.maxprintline
  if engine:match("^lua") or engine:match("^harf") then
    maxprintline = maxprintline + 1 -- Deal with an out-by-one error
  end
  local function killcheck(line)
      -- Skip \openin/\openout lines in web2c 7.x
      -- As Lua doesn't allow "(in|out)", a slightly complex approach:
      -- do a substitution to check the line is exactly what is required!
    return line:gsub("^\\openin", "\\openout"):match("^\\openout%d%d? = ")
  end
    -- Substitutions to remove some non-useful changes
  local function normalize(line, lastline, drop_fd)
    if drop_fd then
      if line:match(" *%)") then
        return "", ""
      else
        return "", "", true
      end
    end
    local function lgsub(pattern, repl)
      line = line:gsub(pattern, repl)
    end
    -- Zap line numbers from \show, \showbox, \box_show and the like:
    -- do this before wrapping lines
    lgsub("^l%.%d+ ", "l. ...")
    -- Also from lua stack traces.
    lgsub("lua:%d+: in function", "lua:...: in function")
    -- Allow for wrapped lines: preserve the content and wrap
    -- Skip lines that have an explicit marker for truncation
    if #line == maxprintline  and not line:match("%.%.%.$") then
      return "", (lastline or "") .. line
    end
    local line = (lastline or "") .. line
    lastline = ""
    -- Zap ./ at begin of filename
    lgsub("%(%.%/", "(")
    -- Zap paths
    -- The pattern excludes < and > as the image part can have
    -- several entries on one line
    local pattern = "%w?:?/[^ %<%>]*/([^/%(%)]*%.%w*)"
    -- Files loaded from TeX: all start ( -- )
    lgsub("%(" .. pattern, "(../%1")
    -- Images
    lgsub("<" .. pattern .. ">", "<../%1>")
    -- luaotfload files start with keywords
    lgsub("from " .. pattern .. "%(", "from. ./%1(")
    lgsub(": " .. pattern .. "%)", ": ../%1)")
    -- Deal with XeTeX specials
    if line:match("^%.+\\XeTeX.?.?.?file") then
      lgsub(pattern, "../%1")
    end
    -- Deal with dates
    if line:match("[^<]%d%d%d%d[/%-]%d%d[/%-]%d%d") then
        lgsub("%d%d%d%d[/%-]%d%d[/%-]%d%d","....-..-..")
        lgsub("v%d+%.?%d?%d?%w?","v...")
    end
    -- Deal with leading spaces for file and page number lines
    lgsub("^ *%[(%d)", "[%1")
    lgsub("^ *%(", "(")
    -- Zap .fd lines: drop the first part, and skip to the end
    if line:match("^ *%([%.%/%w]+%.fd[^%)]*$") then
      return "", "", true
    end
    -- TeX90/XeTeX knows only the smaller set of dimension units
    lgsub("cm, mm, dd, cc, bp, or sp",
         "cm, mm, dd, cc, nd, nc, bp, or sp")
    -- On the other hand, (u)pTeX has some new units!
    lgsub("em, ex, zw, zh, in, pt, pc,",
         "em, ex, in, pt, pc,")
    lgsub("cm, mm, dd, cc, bp, H, Q, or sp;",
         "cm, mm, dd, cc, nd, nc, bp, or sp;")
    -- Normalise a case where fixing a TeX bug changes the message text
    lgsub("\\csname\\endcsname ", "\\csname\\endcsname")
    -- Zap "on line <num>" and replace with "on line ..."
    -- Two similar cases, Lua patterns mean we need to do them separately
    lgsub("on line %d*", "on line ...")
    lgsub("on input line %d*", "on input line ...")
    -- Tidy up to ^^ notation
    for i = 0, 31 do
      lgsub(char(i), "^^" .. char(64 + i))
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
      lgsub("%d+$", "...")
    end
    -- Also deal with showing boxes
    if line:match("^> \\box%d+=$") or line:match("^> \\box%d+=(void)$") then
      lgsub("%d+=", "...=")
    end
    if not V.stdengine:match("^e?u?ptex$") then
      -- Remove 'normal' direction information on boxes with (u)pTeX
      lgsub(",? yoko direction,?", "")
      lgsub(",? yoko%(math%) direction,?", "")
      -- Remove '\displace 0.0' lines in (u)pTeX
      if line:match("^%.*\\displace 0%.0$") then
        return ""
       end
     end
    -- Deal with Lua function calls
    if line:match("^Lua function") then
      lgsub("= %d+$", "= ...")
    end
     -- Remove the \special line that in DVI mode keeps PDFs comparable
    if line:match("^%.*\\special%{pdf: docinfo << /Creator") or
       line:match("^%.*\\special%{ps: /setdistillerparams") or
       line:match("^%.*\\special%{! <</........UUID") then
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
       line:match("^close source    >") or
       line:match("^mkiv lua stats  >") or
       line:match("^pages           >") or
       line:match("^system          >") or
       line:match("^used file       >") or
       line:match("^used option     >") or
       line:match("^used structure  >") then
       return ""
    end
    -- The first time a new font is used by LuaTeX, it shows up
    -- as being cached: make it appear loaded every time
    lgsub("save cache:", "load cache:")
    -- A tidy-up to keep LuaTeX and other engines in sync
    lgsub(utf8_char(127), "^^?")
    -- Remove lua data reference ids
    lgsub("<lua data reference [0-9]+>",
         "<lua data reference ...>")
    -- Unicode engines display chars in the upper half of the 8-bit range:
    -- tidy up to match pdfTeX if an ASCII engine is in use
    if V.asciiengines[1] then
      for i = 128, 255 do
        lgsub(utf8_char(i), "^^" .. format("%02x", i))
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
      line, lastline, drop_fd = normalize(line, lastline, drop_fd)
      if not line:match("^ *$") and not killcheck(line) then
        new_content = new_content .. line .. OS.newline
      end
    end
  end
  if V.recordstatus then
    new_content = new_content .. '***************' .. OS.newline
    for i = 1, V.checkruns do
      if (errlevels[i]==nil) then
        new_content = new_content ..
          'Compilation ' .. i .. ' of test file skipped ' .. OS.newline
      else
        new_content = new_content ..
          'Compilation ' .. i .. ' of test file completed with exit status ' ..
          errlevels[i] .. OS.newline
      end
    end
  end
  return new_content
end

-- Additional normalization for LuaTeX
local function normalize_lua_log(content, luatex)
  local function normalize(line, lastline, dropping)
    -- Find \discretionary or \whatsit lines:
    -- These may come back later
    if line:match("^%.+\\discretionary$")
    or line:match("^%.+\\discretionary %(penalty 50%)$")
    or line:match("^%.+\\discretionary50%|$")
    or line:match("^%.+\\discretionary50%| replacing $")
    or line:match("^%.+\\whatsit$") then
      return "", line
    end
    -- For \mathon, we always need this line but the next
    -- may be affected
    if line:match("^%.+\\mathon$") then
      return line, line
    end
    local function lgsub(pattern, repl)
      line = line:gsub(pattern, repl)
    end
    -- LuaTeX has a flexible output box
    lgsub("\\box\\outputbox", "\\box255")
    -- LuaTeX identifies spaceskip glue
    lgsub("%(\\spaceskip%) ", " ")
    -- Remove 'display' at end of display math boxes:
    -- LuaTeX omits this as it includes direction in all cases
    lgsub("(\\hbox%(.*), display$", "%1")
    -- Remove 'normal' direction information on boxes:
    -- any bidi/vertical stuff will still show
    lgsub(", direction TLT", "")
    -- Find glue setting and round out the last place
    local function l_round_digits(m)
      line = line:gsub(m .. " (%-?)%d+%.%d+",
                    m .. " %1" .. ("%.3f"):format(
                      line:match(m .. " %-?(%d+%.%d+)") or 0
                    )
      )
    end
    if line:match("glue set %-?%d+%.%d+") then
      l_round_digits("glue set")
    end
    if line:match(
      "glue %-?%d+%.%d+ plus %-?%d+%.%d+ minus %-?%d+%.%d+$"
    ) then
      l_round_digits("glue")
      l_round_digits("plus")
      l_round_digits("minus")
    end
    -- LuaTeX writes ^^M as a new line, which we lose
    lgsub("%^%^M", "")
    -- Remove U+ notation in the "Missing character" message
    lgsub( "Missing character: There is no (%^%^..) %(U%+(....)%)",
          "Missing character: There is no %1")
    -- LuaTeX from v1.07 logs kerns differently ...
    -- This block only applies to the output of LuaTeX itself,
    -- hence needing a flag to skip the case of the reference log
    if luatex and tonumber(luatex_version) >= 107
              and line:match("^%.*\\kern") then
      -- Re-insert the space in explicit kerns
      if line:match("kern%-?%d+%.%d+ *$") then
        lgsub("kern", "kern ")
      elseif line:match("%(accent%)$") then
        lgsub("kern", "kern ")
        lgsub("%(accent%)$", "(for accent)")
      elseif line:match("%(italic%)$") then
        lgsub("kern", "kern ")
        lgsub(" %(italic%)$", "")
      else
        lgsub(" %(font%)$", "")
      end
    end
    -- Changes in PDF specials
    lgsub("\\pdfliteral origin", "\\pdfliteral")
    -- A function to handle the box prefix part
    local function box_prefix(s)
      return s:match("^(%.+)"):gsub("%.", "%%.")
    end
    -- 'Recover' some discretionary data
    if lastline:match("^%.+\\discretionary %(penalty 50%)$")
    and line:match(box_prefix(lastline) .. "%.= ") then
      lgsub(" %(font%)$", "")
      return line:gsub("%.= ", ""), ""
    end
    -- Where the last line was a discretionary, looks for the
    -- info one level in about what it represents
    if lastline:match("^%.+\\discretionary$")
    or lastline:match("^%.+\\discretionary %(penalty 50%)$")
    or lastline:match("^%.+\\discretionary50%|$")
    or lastline:match("^%.+\\discretionary50%| replacing $") then
      local prefix = box_prefix(lastline)
      if line:match(prefix .. "%.")
      or line:match(prefix .. "%|") then
        if lastline:match(" replacing $")
        and not dropping then
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
          return lastline .. OS.newline .. line, ""
        end
      end
    end
    -- Look for another form of \discretionary, replacing a "-"
    local pattern = "^%.+\\discretionary replacing *$"
    if line:match(pattern) then
      return "", line
    else
      if lastline:match(pattern) then
        local prefix = box_prefix(lastline)
        if line:match(prefix .. "%.\\kern") then
          return line:gsub("^%.", ""), lastline, true
        elseif dropping then
          return "", ""
        else
          return lastline .. OS.newline .. line, ""
        end
      end
    end
    -- For \mathon, if the current line is an empty \hbox then
    -- drop it
    if lastline:match("^%.+\\mathon$") then
      local prefix = box_prefix(lastline)
      if line:match(prefix .. "\\hbox%(0%.0%+0%.0%)x0%.0$") then
        return "", ""
      end
    end
    -- Various \local... things that other engines do not do:
    -- Only remove the no-op versions
    if line:match("^%.+\\localpar$")
    or line:match("^%.+\\localinterlinepenalty=0$")
    or line:match("^%.+\\localbrokenpenalty=0$")
    or line:match("^%.+\\localleftbox=null$")
    or line:match("^%.+\\localrightbox=null$")      then
       return "", ""
    end
    -- Older LuaTeX versions set the above up as a whatsit
    -- (at some stage this can therefore go)
    if lastline:match("^%.+\\whatsit$") then
      local prefix = box_prefix(lastline)
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
    if #line == V.maxprintline then
      return "", lastline .. line
    elseif #lastline == V.maxprintline then
      if line:match("\\ETC%.%}$") then
        -- If the line wrapped at \ETC we might have lost a space
        return lastline
          .. ((line:match("^\\ETC%.%}$") and " ") or "")
          .. line, ""
      elseif line:match("^%}%}%}$") then
        return lastline .. line, ""
      else
        return lastline .. OS.newline .. line, ""
      end
    -- Return all of the text for a wrapped (multi)line
    elseif #lastline > V.maxprintline then
      return lastline .. line, ""
    end
    -- Remove spaces at the start of lines: deals with the fact that LuaTeX
    -- uses a different number to the other engines
    return line:gsub("^%s+", ""), ""
  end
  local new_content = ""
  local lastline = ""
  local dropping = false
  for line in content:gmatch("([^\n]*)\n") do
    line, lastline, dropping = normalize(line, lastline, dropping)
    if not line:match("^ *$") then
      new_content = new_content .. line .. OS.newline
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
          new_content = new_content .. "[BINARY STREAM]" .. OS.newline
        else
           new_content = new_content .. stream_content .. line .. OS.newline
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
          stream_content = stream_content .. line .. OS.newline
        end
      end
    elseif line:match("^stream$") then
      binary = false
      stream = true
      stream_content = "stream" .. OS.newline
    elseif not line:match("^ *$")
    and not line:match("^%%%%Invocation")
    and not line:match("^%%%%%+") then
      line = line:gsub("%/ID( ?)%[<[^>]+><[^>]+>]",
                       "/ID%1[<ID-STRING><ID-STRING>]")
      new_content = new_content .. line .. OS.newline
    end
  end
  return new_content
end

-- Look for a test: could be in the testfiledir or the unpackdir
local function test_exists(test)
  return(FS.locate( { FS.dir.testfile   , FS.dir.unpack },
                    { test .. V.lvtext, test .. V.pvtext }))
end

local function showfailedlog(name, testdir)
  print("\nCheck failed with log file")
  for _, i in ipairs(FS.filelist(testdir, name..".log")) do
    print("  - " .. testdir .. "/" .. i)
    print("")
    local f = open(testdir .. "/" .. i,"r")
    local content = f:read("*all")
    close(f)
    print("-----------------------------------------------------------------------------------")
    print(content)
    print("-----------------------------------------------------------------------------------")
  end
end

local function showfaileddiff(testdir)
  print("\nCheck failed with difference file")
  for _, i in ipairs(FS.filelist(testdir, "*" .. OS.diffext)) do
    print("  - " .. testdir .. "/" .. i)
    print("")
    local f = open(testdir .. "/" .. i,"r")
    local content = f:read("*all")
    close(f)
    print("-----------------------------------------------------------------------------------")
    print(content)
    print("-----------------------------------------------------------------------------------")
  end
end

local function compare_pdf(name, engine, cleanup)
  local testname = name .. "." .. engine
  local diff_p = FS.dir.test .. "/" .. testname .. V.pdfext .. OS.diffext
  local pdf_p  = FS.dir.test .. "/" .. testname .. V.pdfext
  local tpf_p  = FS.locate( { FS.dir.test },
                            { testname .. V.tpfext, name .. V.tpfext })
  if not tpf_p then
    return 1
  end
  local error_n = execute(OS.diffexe .. " "
    .. FS.normalize_path(tpf_p .. " " .. pdf_p .. " > " .. diff_p))
  if error_n == 0 or cleanup then
    remove(diff_p)
  end
  return error_n
end

local function compare_tlg(name, engine, cleanup)
  local error_p
  local test_name = name .. "." .. engine
  local diff_p = FS.dir.test .. "/" .. test_name .. OS.diffext
  local log_p  = FS.dir.test .. "/" .. test_name .. V.logext
  local tlg_p  = FS.locate({ FS.dir.test }, { test_name .. V.tlgext, name .. V.tlgext })
  if not tlg_p then
    return 1
  end
  -- Do additional log formatting if the engine is LuaTeX, there is no
  -- LuaTeX-specific .tlg file and the default engine is not LuaTeX
  if (engine:match("^lua") or engine:match("^harf"))
  and not tlg_p:match("%.luatex" .. "%" .. V.tlgext)
  and not V.stdengine:match("^lua") then
    local lua_log_p = log_p
    if cleanup then
      lua_log_p = FS.dir.test .. "/" .. test_name .. ".tmp" .. V.logext
    end
    local lua_tlg_p = FS.dir.test .. "/" .. test_name .. V.tlgext
    translate(tlg_p, lua_tlg_p, normalize_lua_log)
    translate(log_p, lua_log_p, normalize_lua_log, true)
    error_p = execute(OS.diffexe .. " "
      .. FS.normalize_path(lua_tlg_p .. " " .. lua_log_p .. " > " .. diff_p))
    if cleanup then
      remove(lua_log_p)
      remove(lua_tlg_p)
    end
  else
    error_p = execute(OS.diffexe .. " "
      .. FS.normalize_path(tlg_p .. " " .. log_p .. " > " .. diff_p))
  end
  if error_p == 0 or cleanup then
    remove(diff_p)
  end
  return error_p
end

-- Run one of the test files: doesn't check the result so suitable for
-- both creating and verifying
local function runtest(name, engine, hide, ext, pdfmode, breakout)
  local lvt_p = name .. (ext or V.lvtext)
  FS.cp(lvt_p, FS.fileexists(FS.dir.testfile .. "/" .. lvt_p)
    and FS.dir.testfile or FS.dir.unpack, FS.dir.test)
  local checkopts = V.checkopts
  local engine = engine or V.stdengine
  local binary = engine
  local format = engine:gsub("tex$", V.checkformat)
  -- Special binary/format combos
  if V.specialformats[V.checkformat] then
    local t = V.specialformats[V.checkformat][engine]
    if t and t[1] then
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
    setup = function (file) return ' "' .. file .. '" '  end
  end
  local basename = FS.dir.test .. "/" .. name
  local log_p = basename .. V.logext
  local new_p = basename .. "." .. engine .. V.logext
  local pdf_p = basename .. V.pdfext
  local npf_p = basename .. "." .. engine .. V.pdfext
  local asciiopt = ""
  for _, i in ipairs(V.asciiengines) do
    if binary == i then
      asciiopt = "-translate-file ./ascii.tcx "
      break
    end
  end
  -- Clean out any dynamic files
  for _, filetype in pairs(V.dynamicfiles) do
    FS.rm(FS.dir.test, filetype)
  end
  -- Ensure there is no stray .log file
  FS.rm(FS.dir.test, name .. V.logext)
  local errlevels = {}
  local localtexmf = ""
  if FS.dir.texmf and FS.dir.texmf ~= "" and FS.direxists(FS.dir.texmf) then
    localtexmf = OS.pathsep .. FS.abspath(FS.dir.texmf) .. "//"
  end
  for i = 1, V.checkruns do
    errlevels[i] = OS.run(
      FS.dir.test,
      -- No use of localdir here as the files get copied to testdir:
      -- avoids any paths in the logs
      OS.setenv .. " TEXINPUTS=." .. localtexmf
        .. (V.checksearch and OS.pathsep or "")
        .. OS.concat ..
      OS.setenv .. " LUAINPUTS=." .. localtexmf
        .. (V.checksearch and OS.pathsep or "")
        .. OS.concat ..
      -- Avoid spurious output from (u)pTeX
      OS.setenv .. " GUESS_INPUT_KANJI_ENCODING=0"
        .. OS.concat ..
      -- Allow for local texmf files
      OS.setenv .. " TEXMFCNF=." .. OS.pathsep
        .. OS.concat ..
      (V.forcecheckepoch and Aux.set_epoch_cmd(V.epoch) or "") ..
      -- Ensure lines are of a known length
      OS.setenv .. " max_print_line=" .. V.maxprintline
        .. OS.concat ..
      binary .. format
        .. " " .. asciiopt .. " " .. checkopts
        .. setup(lvt_p)
        .. (hide and (" > " .. OS.null) or "")
        .. OS.concat ..
      V.runtest_tasks(FS.jobname(lvt_p), i)
    )
    -- Break the loop if the result is stable
    if breakout and i < V.checkruns then
      if pdfmode then
        if FS.fileexists(FS.dir.test .. "/" .. name .. V.dviext) then
          Tpst.dvitopdf(name, FS.dir.test, engine, hide)
        end
        translate(pdf_p, npf_p, normalize_pdf)
        if compare_pdf(name, engine, true) == 0 then
          break
        end
      else
        translate(log_p, new_p, normalize_log, engine, errlevels)
        if compare_tlg(name, engine, true) == 0 then
          break
        end
      end
    end
  end
  if pdfmode and FS.fileexists(FS.dir.test .. "/" .. name .. V.dviext) then
    Tpst.dvitopdf(name, FS.dir.test, engine, hide)
  end
  if pdfmode then
    FS.cp(name .. V.pdfext, FS.dir.test, rV.esultdir)
    FS.ren(FS.dir.result, name .. V.pdfext, name .. "." .. engine .. V.pdfext)
    translate(pdf_p, npf_p, normalize_pdf)
  else
    translate(log_p, new_p, normalize_log, engine, errlevels)
  end
  -- Store secondary files for this engine
  for _, filetype in pairs(V.auxfiles) do
    for _, file in pairs(FS.filelist(FS.dir.test, filetype)) do
      if file:match("^" .. name .. ".[^.]+$") then
        ext = file:match("%.[^.]+$")
        if ext ~= V.lvtext and
           ext ~= V.tlgext and
           ext ~= V.lveext and
           ext ~= V.logext then
           local newname = file:gsub("(%.[^.]+)$","." .. engine .. "%1")
           if FS.fileexists(FS.dir.test, newname) then
             FS.rm(FS.dir.test, newname)
           end
           FS.ren(FS.dir.test, file, newname)
        end
      end
    end
  end
  return 0
end

local function setup_check(name, engine)
  local test_name = name .. "." .. engine
  local tlg_p = FS.locate(
    { FS.dir.testfile, FS.dir.unpack },
    { test_name .. V.tlgext, name .. V.tlgext }
  )
  local tpf_p = FS.locate(
    { FS.dir.testfile, FS.dir.unpack },
    { test_name .. V.tpfext, name .. V.tpfext }
  )
  -- Attempt to generate missing reference file from expectation
  if not (tlg_p or tpf_p) then
    if not FS.locate( { FS.dir.unpack, FS.dir.testfile },
                      { name .. V.lveext } ) then
      L3B.error(1, "failed to find %s, %s or %s file for %s!",
                V.tlgext, V.tpfext, V.lveext, name)
    end
    runtest(name, engine, true, V.lveext)
    FS.ren(FS.dir.test, test_name .. V.logext, test_name .. V.tlgext)
  else
    -- Install comparison files found
    for _, v in pairs({ tlg_p, tpf_p }) do
      if v then
        FS.cp(v:match(".*/(.*)"),
              v:match("(.*)/.*"),
              FS.dir.test)
      end
    end
  end
end

-- Run one test which may have multiple engine-dependent comparisons
-- Should create a difference file for each failed test
function Chk.runcheck(name, hide)
  if not test_exists(name) then
    print("Failed to find input for test " .. name)
    return 1
  end
  local check_engines = V.checkengines
  if Opts.engines then
    check_engines = Opts.engines
  end
  -- Used for both .lvt and .pvt tests
  local function check_and_diff(ext, engine, comp, pdftest)
    runtest(name, engine, hide, ext, pdftest, true)
    local error_n = comp(name, engine)
    if error_n == 0 then
      return error_n
    end
    if Opts["show-log-on-error"] then
      showfailedlog(name, FS.dir.test)
    end
    if Opts["halt-on-error"] then
      showfaileddiff(FS.dir.test)
    end
    return error_n
  end
  local error_p = 0
  for _, engine in pairs(check_engines) do
    setup_check(name, engine)
    local errlevel = 0
    if FS.fileexists(testfiledir .. "/" .. name .. V.pvtext) then
      errlevel = check_and_diff(V.pvtext, engine, compare_pdf, true)
    else
      errlevel = check_and_diff(V.lvtext, engine, compare_tlg)
    end
    if errlevel ~= 0 and Opts["halt-on-error"] then
      return 1
    end
    if errlevel > error_p then
      error_p = errlevel
    end
  end
  -- Return everything
  return error_p
end

function Chk.check(names)
  local error_n = 0
  if testfiledir ~= "" and FS.direxists(testfiledir) then
    if not Opts.rerun then
      check_init()
    end
    local hide = true
    if names and names[1] then
      hide = false
    end
    names = names or {}
    -- No names passed: find all test files
    if not next(names) then
      local excludenames = {}
      for _, glob in pairs(V.excludetests) do
        for _, name in pairs(FS.filelist(FS.dir.testfile, glob .. V.lvtext)) do
          excludenames[FS.jobname(name)] = true
        end
        for _, name in pairs(FS.filelist(FS.dir.unpack, glob .. V.lvtext)) do
          excludenames[FS.jobname(name)] = true
        end
        for _, name in pairs(FS.filelist(FS.dir.testfile, glob .. V.pvtext)) do
          excludenames[FS.jobname(name)] = true
        end
      end
      local function addname(name)
        if not excludenames[FS.jobname(name)] then
          names[#names+1] = FS.jobname(name)
        end
      end
      for _, glob in pairs(V.includetests) do
        for _, name in pairs(FS.filelist(FS.dir.testfile, glob .. V.lvtext)) do
          addname(name)
        end
        for _, name in pairs(FS.filelist(FS.dir.testfile, glob .. V.pvtext)) do
          addname(name)
        end
        for _, name in pairs(FS.filelist(FS.dir.unpack, glob .. V.lvtext)) do
          if FS.fileexists(FS.dir.testfile .. "/" .. name) then
            print("Duplicate test file: " .. name)
            return 1
          end
          addname(name)
        end
      end
      sort(names)
      -- Deal limiting range of names
      if Opts.first then
        local allnames = names
        local active = false
        local firstname = Opts.first
        names = {}
        for _, name in ipairs(allnames) do
          if name == firstname then
            active = true
          end
          if active then
            names[#names+1] = name
          end
        end
      end
      if Opts.last then
        local allnames = names
        local lastname = Opts.last
        names = {}
        for _, name in ipairs(allnames) do
          names[#names+1] = name
          if name == lastname then
            break
          end
        end
      end
    end
    -- https://stackoverflow.com/a/32167188
    local function shuffle(tbl)
      local len, random = #tbl, rnd
      for i = len, 2, -1 do
          local j = random(1, i)
          tbl[i], tbl[j] = tbl[j], tbl[i]
      end
      return tbl
    end
    if Opts.shuffle then
      names = shuffle(names)
    end
    -- Actually run the tests
    print("Running checks on")
    local i = 0
    for _, name in ipairs(names) do
      i = i + 1
      print("  " .. name .. " (" ..  i.. "/" .. #names ..")")
      local errlevel = Chk.runcheck(name, hide)
      -- Return value must be 1 not errlevel
      if errlevel ~= 0 then
        if Opts["halt-on-error"] then
          return 1
        else
          error_n = 1
          -- visually show that something has failed
          print("          --> failed\n")
        end
      end
    end
    if error_n ~= 0 then
      checkdiff()
    else
      print("\n  All checks passed\n")
    end
  end
  return error_n
end

-- A short auxiliary to print the list of differences for check
function checkdiff()
  print("\n  Check failed with difference files")
  for _, i in ipairs(FS.filelist(testdir, "*" .. OS.diffext)) do
    print("  - " .. testdir .. "/" .. i)
  end
  print("")
end

function save(names)
  check_init()
  local engines = Opts.engines or { V.stdengine }
  if names == nil then
    print("Arguments are required for the save command")
    return 1
  end
  for _, name in pairs(names) do
    if test_exists(name) then
      for _, engine in pairs(engines) do
        local test_engine = (engine == V.stdengine and "") or ("." .. engine) -- why "."?
        local function save_test(test_ext, gen_ext, out_ext, pdf_mode)
          local out_file = name .. test_engine .. out_ext
          local gen_file = name .. "." .. engine .. gen_ext
          print("Creating and copying " .. out_file)
          runtest(name, engine, false, test_ext, pdf_mode)
          FS.ren(FS.dir.test, gen_file, out_file)
          FS.cp(out_file, FS.dir.test, FS.dir.testfile)
          if FS.fileexists(FS.dir.unpack .. "/" .. out_file) then
            print("Saved " .. out_ext
              .. " file overrides unpacked version of the same name")
            return 1
          end
          return 0
        end
        local error_level
        if FS.fileexists(FS.dir.testfile .. "/" .. name .. V.lvtext) then
          error_level = save_test(V.lvtext, V.logext, V.tlgext)
        else
          error_level = save_test(V.pvtext, V.pdfext, V.tpfext, true)
        end
        if error_level ~=0 then return error_level end
      end
    elseif FS.locate( { FS.dir.unpack, FS.dir.testfile },
                      { name .. V.lveext }) then
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

function Chk.check_many(target)  
  if target == "check" and #V.checkconfigs > 1 then
    local error_n = 0
    local failed_t = {}
    for i = 1, #V.checkconfigs do
      Opts.config = { V.checkconfigs[i] }
      error_n = Aux.call({ "." }, "check", Opts) -- remove the 3rd argument
      if error_n ~= 0 then
        if Opts["halt-on-error"] then
          exit(1)
        end
        failed_t[#failed_t+1] = V.checkconfigs[i]
      end
    end
    if #failed_t then
      for _, conf8n in ipairs(failed_t) do
        print("Failed tests for configuration " .. conf8n .. ":")
        print("\n  Check failed with difference files")
        local testdir = FS.dir.test
        if conf8n ~= "build" then
          testdir = testdir .. "-" .. conf8n
        end
        for _, i in ipairs(FS.filelist(testdir, "*" .. OS.diffext)) do
          print("  - " .. testdir .. "/" .. i)
        end
        print("")
      end
      exit(1)
    else
      -- Avoid running the 'main' set of tests twice
      exit(0)
    end
  end
end
