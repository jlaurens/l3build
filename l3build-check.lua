--[[

File l3build-check.lua Copyright (C) 2018-2020 The LaTeX Project

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

-- Local access to functions
local open            = io.open
local close           = io.close
local write           = io.write
local output          = io.output

local rnd             = math.random

local status          = require("status")
local luatex_version  = status.luatex_version

local len             = string.len
local char            = string.char
local str_format      = string.format
local gmatch          = string.gmatch
local gsub            = string.gsub
local match           = string.match

local insert          = table.insert
local sort            = table.sort
local tbl_unpack      = table.unpack

local unicode         = require("unicode")
local utf8_char       = unicode.utf8.char

local exit            = os.exit
local execute         = os.execute
local remove          = os.remove

local util            = require("l3b.util")
local entries         = util.entries

local fifu        = require("l3b.file-functions")
local all_files   = fifu.all_files
local cmd_concat  = fifu.cmd_concat
local copy_tree   = fifu.copy_tree
local file_exists = fifu.file_exists
local locate      = fifu.locate
local run         = fifu.run
local rename      = fifu.rename
local to_host     = fifu.to_host
local remove_tree = fifu.remove_tree
local remove_file = fifu.remove_file
local job_name    = fifu.job_name
local directory_exists      = fifu.directory_exists
local absolute_path         = fifu.absolute_path
local make_clean_directory  = fifu.make_clean_directory
local glob_to_pattern       = fifu.glob_to_pattern

--
-- Auxiliary functions which are used by more than one main function
--

checkinit_hook = checkinit_hook or function() return 0 end

-- Set up the check system files: needed for checking one or more tests and
-- for saving the test files
local function checkinit()
  if not options["dirty"] then
    make_clean_directory(testdir)
    make_clean_directory(resultdir)
  end
  dep_install(checkdeps)
  -- Copy dependencies to the test directory itself: this makes the paths
  -- a lot easier to manage, and is important for dealing with the log and
  -- with file input/output tests
  for i in all_files(localdir) do
    copy_tree(i, localdir, testdir)
  end
  bundleunpack({ sourcefiledir, testfiledir })
  for i in entries(installfiles) do
    copy_tree(i, unpackdir, testdir)
  end
  for i in entries(checkfiles) do
    copy_tree(i, unpackdir, testdir)
  end
  if directory_exists(testsuppdir) then
    for i in all_files(testsuppdir) do
      copy_tree(i, testsuppdir, testdir)
    end
  end
  for i in entries(checksuppfiles) do
    copy_tree(i, supportdir, testdir)
  end
  execute(os_ascii .. ">" .. testdir .. "/ascii.tcx")
  return checkinit_hook()
end

---Apply the `translator` to the content at `path_in`
---and save the result to `path_out`.
---@param path_in string
---@param path_out string
---@param translator fun(content: string, ...): string
---@vararg any
local function rewrite(path_in, path_out, translator, ...)
  local fh = assert(open(path_in, "rb")) -- "b" for pdf files
  local content = gsub(fh:read("a") .. "\n", "\r\n", "\n")
  fh:close()
  content = translator(content, ...)
  fh = open(path_out, "w")
  fh:write(content)
  fh:close()
end

---Convert the raw log file into one for comparison/storage: keeps only
---the 'business' part from the tests and removes system-dependent stuff
---@param content string
---@param engine string
---@param errlevels table
---@return string
local function normalize_log(content, engine, errlevels)
  local max_print_line = maxprintline
  if match(engine, "^lua") or match(engine, "^harf") then
    max_print_line = max_print_line + 1 -- Deal with an out-by-one error
  end
  local function killcheck(line)
      -- Skip \openin/\openout lines in web2c 7.x
      -- As Lua doesn't allow "(in|out)", a slightly complex approach:
      -- do a substitution to check the line is exactly what is required!
    if match(gsub(line, "^\\openin", "\\openout"), "^\\openout%d%d? = ") then
      return true
    end
    return false
  end
    -- Substitutions to remove some non-useful changes
  local function normalize(line, lastline, drop_fd)
    if drop_fd then
      if match(line, " *%)") then
        return "", ""
      else
        return "", "", true
      end
    end
    -- Zap line numbers from \show, \showbox, \box_show and the like:
    -- do this before wrapping lines
    line = gsub(line, "^l%.%d+ ", "l. ...")
    -- Also from lua stack traces.
    line = gsub(line, "lua:%d+: in function", "lua:...: in function")
    -- Allow for wrapped lines: preserve the content and wrap
    -- Skip lines that have an explicit marker for truncation
    if len(line) == max_print_line
      and not match(line, "%.%.%.$")
    then
      return "", (lastline or "") .. line
    end
    line = (lastline or "") .. line
    lastline = ""
    -- Zap ./ at begin of filename
    line = gsub(line, "%(%.%/", "(")
    -- Zap paths
    -- The pattern excludes < and > as the image part can have
    -- several entries on one line
    local pattern = "%w?:?/[^ %<%>]*/([^/%(%)]*%.%w*)"
    -- Files loaded from TeX: all start ( -- )
    line = gsub(line, "%(" .. pattern, "(../%1")
    -- Images
    line = gsub(line, "<" .. pattern .. ">", "<../%1>")
    -- luaotfload files start with keywords
    line = gsub(line, "from " .. pattern .. "%(", "from. ./%1(")
    line = gsub(line, ": " .. pattern .. "%)", ": ../%1)")
    -- Deal with XeTeX specials
    if match(line, "^%.+\\XeTeX.?.?.?file") then
      line = gsub(line, pattern, "../%1")
    end
    -- Deal with dates
    if match(line, "[^<]%d%d%d%d[/%-]%d%d[/%-]%d%d") then
      line = gsub(line, "%d%d%d%d[/%-]%d%d[/%-]%d%d", "....-..-..")
      line = gsub(line, "v%d+%.?%d?%d?%w?", "v...")
    end
    -- Deal with leading spaces for file and page number lines
    line = gsub(line, "^ *%[(%d)", "[%1")
    line = gsub(line, "^ *%(", "(")
    -- Zap .fd lines: drop the first part, and skip to the end
    if match(line, "^ *%([%.%/%w]+%.fd[^%)]*$") then
      return "", "", true
    end
    -- TeX90/XeTeX knows only the smaller set of dimension units
    line = gsub(line,
      "cm, mm, dd, cc, bp, or sp",
      "cm, mm, dd, cc, nd, nc, bp, or sp")
    -- On the other hand, (u)pTeX has some new units!
    line = gsub(line,
      "em, ex, zw, zh, in, pt, pc,",
      "em, ex, in, pt, pc,")
    line = gsub(line,
      "cm, mm, dd, cc, bp, H, Q, or sp;",
      "cm, mm, dd, cc, nd, nc, bp, or sp;")
    -- Normalise a case where fixing a TeX bug changes the message text
    line = gsub(line, "\\csname\\endcsname ", "\\csname\\endcsname")
    -- Zap "on line <num>" and replace with "on line ..."
    -- Two similar cases, Lua patterns mean we need to do them separately
    line = gsub(line, "on line %d*", "on line ...")
    line = gsub(line, "on input line %d*", "on input line ...")
    -- Tidy up to ^^ notation
    for i = 0, 31 do
      line = gsub(line, char(i), "^^" .. char(64 + i))
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
    if register_types[match(line, "^\\[^%]]+=\\([a-z]+)%d+$")] then
      line = gsub(line, "%d+$", "...")
    end
    -- Also deal with showing boxes
    if match(line, "^> \\box%d+=$") or match(line, "^> \\box%d+=(void)$") then
      line = gsub(line, "%d+=", "...=")
    end
    if not match(stdengine, "^e?u?ptex$") then
      -- Remove 'normal' direction information on boxes with (u)pTeX
      line = gsub(line, ",? yoko direction,?", "")
      line = gsub(line, ",? yoko%(math%) direction,?", "")
      -- Remove '\displace 0.0' lines in (u)pTeX
      if match(line, "^%.*\\displace 0%.0$") then
        return ""
      end
    end
    -- Deal with Lua function calls
    if match(line, "^Lua function") then
      line = gsub(line, "= %d+$", "= ...")
    end
    -- Remove the \special line that in DVI mode keeps PDFs comparable
    if match(line, "^%.*\\special%{pdf: docinfo << /Creator")
    or match(line, "^%.*\\special%{ps: /setdistillerparams")
    or match(line, "^%.*\\special%{! <</........UUID") then
      return ""
    end
    -- Remove \special lines for DVI .pro files
    if match(line, "^%.*\\special%{header=") then
      return ""
    end
    if match(line, "^%.*\\special%{dvipdfmx:config") then
      return ""
    end
    -- Remove the \special line possibly present in DVI mode for paper size
    if match(line, "^%.*\\special%{papersize") then
      return ""
    end
    -- Remove ConTeXt stuff
    if match(line, "^backend         >")
    or match(line, "^close source    >")
    or match(line, "^mkiv lua stats  >")
    or match(line, "^pages           >")
    or match(line, "^system          >")
    or match(line, "^used file       >")
    or match(line, "^used option     >")
    or match(line, "^used structure  >")
    then
      return ""
    end
    -- The first time a new font is used by LuaTeX, it shows up
    -- as being cached: make it appear loaded every time
    line = gsub(line, "save cache:", "load cache:")
    -- A tidy-up to keep LuaTeX and other engines in sync
    line = gsub(line, utf8_char(127), "^^?")
    -- Remove lua data reference ids
    line = gsub(line, "<lua data reference [0-9]+>",
                      "<lua data reference ...>")
    -- Unicode engines display chars in the upper half of the 8-bit range:
    -- tidy up to match pdfTeX if an ASCII engine is in use
    if next(asciiengines) then
      for i = 128, 255 do
        line = gsub(line, utf8_char(i), "^^" .. str_format("%02x", i))
      end
    end
    return line, lastline
  end
  local lastline = ""
  local drop_fd = false
  local new_content = ""
  local prestart = true
  local skipping = false
  for line in gmatch(content, "([^\n]*)\n") do
    if line == "START-TEST-LOG" then
      prestart = false
    elseif line == "END-TEST-LOG"
    or match(line, "^Here is how much of .?.?.?TeX\'s memory you used:")
    then
      break
    elseif line == "OMIT" then
      skipping = true
    elseif match(line, "^%)?TIMO$") then
      skipping = false
    elseif not prestart and not skipping then
      line, lastline, drop_fd = normalize(line, lastline, drop_fd)
      if not match(line, "^ *$") and not killcheck(line) then
        new_content = new_content .. line .. os_newline
      end
    end
  end
  if recordstatus then
    new_content = new_content .. '***************' .. os_newline
    for i = 1, checkruns do
      if errlevels[i] == nil then
        new_content = new_content
          .. 'Compilation ' .. i .. ' of test file skipped ' .. os_newline
      else
        new_content = new_content ..
          'Compilation ' .. i .. ' of test file completed with exit status ' ..
          errlevels[i] .. os_newline
      end
    end
  end
  return new_content
end

-- Additional normalization for LuaTeX
---comment
---@param content string
---@param is_luatex boolean
---@return string
local function normalize_lua_log(content, is_luatex)
  ---comment
  ---@param line string
  ---@param last_line string
  ---@param dropping boolean
  ---@return string
  ---@return string
  ---@return boolean
  local function normalize(line, last_line, dropping)
    -- Find \discretionary or \whatsit lines:
    -- These may come back later
    if match(line, "^%.+\\discretionary$")
    or match(line, "^%.+\\discretionary %(penalty 50%)$")
    or match(line, "^%.+\\discretionary50%|$")
    or match(line, "^%.+\\discretionary50%| replacing $")
    or match(line, "^%.+\\whatsit$")
    then
      return "", line
    end
    -- For \mathon, we always need this line but the next
    -- may be affected
    if match(line, "^%.+\\mathon$") then
      return line, line
    end
    -- LuaTeX has a flexible output box
    line = gsub(line, "\\box\\outputbox", "\\box255")
    -- LuaTeX identifies spaceskip glue
    line = gsub(line, "%(\\spaceskip%) ", " ")
    -- Remove 'display' at end of display math boxes:
    -- LuaTeX omits this as it includes direction in all cases
    line = gsub(line, "(\\hbox%(.*), display$", "%1")
    -- Remove 'normal' direction information on boxes:
    -- any bidi/vertical stuff will still show
    line = gsub(line, ", direction TLT", "")
    -- Find glue setting and round out the last place
    local function round_digits(l, m)
      return (gsub(
        l,
        m .. " (%-?)%d+%.%d+",
        m .. " %1"
          .. str_format(
            "%.3f",
            match(line, m .. " %-?(%d+%.%d+)") or 0
          )
      ))
    end
    if match(line, "glue set %-?%d+%.%d+") then
      line = round_digits(line, "glue set")
    end
    if match(line,
      "glue %-?%d+%.%d+ plus %-?%d+%.%d+ minus %-?%d+%.%d+$"
    ) then
      line = round_digits(line, "glue")
      line = round_digits(line, "plus")
      line = round_digits(line, "minus")
    end
    -- LuaTeX writes ^^M as a new line, which we lose
    line = gsub(line, "%^%^M", "")
    -- Remove U+ notation in the "Missing character" message
    line = gsub(
        line,
        "Missing character: There is no (%^%^..) %(U%+(....)%)",
        "Missing character: There is no %1"
      )
    -- LuaTeX from v1.07 logs kerns differently ...
    -- This block only applies to the output of LuaTeX itself,
    -- hence needing a flag to skip the case of the reference log
    if  is_luatex
    and tonumber(luatex_version) >= 107
    and match(line, "^%.*\\kern")
    then
      -- Re-insert the space in explicit kerns
      if match(line, "kern%-?%d+%.%d+ *$") then
        line = gsub(line, "kern", "kern ")
      elseif match(line, "%(accent%)$") then
        line = gsub(line, "kern", "kern ")
        line = gsub(line, "%(accent%)$", "(for accent)")
      elseif match(line, "%(italic%)$") then
        line = gsub(line, "kern", "kern ")
        line = gsub(line, " %(italic%)$", "")
      else
        line = gsub(line, " %(font%)$", "")
      end
    end
    -- Changes in PDF specials
    line = gsub(line, "\\pdfliteral origin", "\\pdfliteral")
    -- A function to handle the box prefix part
    local function boxprefix(s)
      return (gsub(match(s, "^(%.+)"), "%.", "%%."))
    end
    -- 'Recover' some discretionary data
    if  match(last_line, "^%.+\\discretionary %(penalty 50%)$")
    and match(line, boxprefix(last_line) .. "%.= ")
    then
      line = gsub(line, " %(font%)$", "")
      return gsub(line, "%.= ", ""), ""
    end
    -- Where the last line was a discretionary, looks for the
    -- info one level in about what it represents
    if match(last_line, "^%.+\\discretionary$")
    or match(last_line, "^%.+\\discretionary %(penalty 50%)$")
    or match(last_line, "^%.+\\discretionary50%|$")
    or match(last_line, "^%.+\\discretionary50%| replacing $")
    then
      local prefix = boxprefix(last_line)
      if match(line, prefix .. "%.")
      or match(line, prefix .. "%|") then
        if match(last_line, " replacing $") and not dropping then
          -- Modify the return line
          return gsub(line, "^%.", ""), last_line, true
        else
          return "", last_line, true
        end
      elseif dropping then
        -- End of a \discretionary block
        return line, ""
      else
        -- Not quite a normal discretionary
        if match(last_line, "^%.+\\discretionary50%|$") then
          last_line = gsub(last_line, "50%|$", "")
        end
        -- Remove some info that TeX90 lacks
        last_line = gsub(last_line, " %(penalty 50%)$", "")
        -- A normal (TeX90) discretionary:
        -- add with the line break reintroduced
        return last_line .. os_newline .. line, ""
      end
    end
    -- Look for another form of \discretionary, replacing a "-"
    local pattern = "^%.+\\discretionary replacing *$"
    if match(line, pattern) then
      return "", line
    elseif match(last_line, pattern) then
      local prefix = boxprefix(last_line)
      if match(line, prefix .. "%.\\kern") then
        return gsub(line, "^%.", ""), last_line, true
      elseif dropping then
        return "", ""
      else
        return last_line .. os_newline .. line, ""
      end
    end
    -- For \mathon, if the current line is an empty \hbox then
    -- drop it
    if match(last_line, "^%.+\\mathon$") then
      local prefix = boxprefix(last_line)
      if match(line, prefix .. "\\hbox%(0%.0%+0%.0%)x0%.0$") then
        return "", ""
      end
    end
    -- Various \local... things that other engines do not do:
    -- Only remove the no-op versions
    if match(line, "^%.+\\localpar$")
    or match(line, "^%.+\\localinterlinepenalty=0$")
    or match(line, "^%.+\\localbrokenpenalty=0$")
    or match(line, "^%.+\\localleftbox=null$")
    or match(line, "^%.+\\localrightbox=null$")
    then
      return "", ""
    end
    -- Older LuaTeX versions set the above up as a whatsit
    -- (at some stage this can therefore go)
    if match(last_line, "^%.+\\whatsit$") then
      local prefix = boxprefix(last_line)
      if match(line, prefix .. "%.") then
        return "", last_line, true
      else
        -- End of a \whatsit block
        return line, ""
      end
    end
    -- Wrap some cases that can be picked out
    -- In some places LuaTeX does use max_print_line, then we
    -- get into issues with different wrapping approaches
    local max_print_line = maxprintline
    if len(line) == max_print_line then
      return "", last_line .. line
    elseif len(last_line) == max_print_line then
      if match(line, "\\ETC%.%}$") then
        -- If the line wrapped at \ETC we might have lost a space
        return last_line
          .. ((match(line, "^\\ETC%.%}$") and " ") or "")
          .. line, ""
      elseif match(line, "^%}%}%}$") then
        return last_line .. line, ""
      else
        return last_line .. os_newline .. line, ""
      end
    -- Return all of the text for a wrapped (multi)line
    elseif len(last_line) > max_print_line then
      return last_line .. line, ""
    end
    -- Remove spaces at the start of lines: deals with the fact that LuaTeX
    -- uses a different number to the other engines
    return gsub(line, "^%s+", ""), ""
  end
  local new_content = ""
  local lastline = ""
  local dropping = false
  for line in gmatch(content, "([^\n]*)\n") do
    line, lastline, dropping = normalize(line, lastline, dropping)
    if not match(line, "^ *$") then
      new_content = new_content .. line .. os_newline
    end
  end
  return new_content
end

---Translator
---@param content string
---@return string
local function normalize_pdf(content)
  local new_content = ""
  local stream_content = ""
  local is_binary = false
  local is_stream = false
  for line in gmatch(content, "([^\n]*)\n") do
    if is_stream then
      if match(line, "endstream") then
        is_stream = false
        if is_binary then
          new_content = new_content .. "[BINARY STREAM]" .. os_newline
        else
          new_content = new_content .. stream_content .. line .. os_newline
        end
        is_binary = false
      else
        for i = 0, 31 do
          if match(line, char(i)) then
            is_binary = true
            break
          end
        end
        if not is_binary and not match(line, "^ *$") then
          stream_content = stream_content .. line .. os_newline
        end
      end
    elseif match(line, "^stream$") then
      is_binary = false
      is_stream = true
      stream_content = "stream" .. os_newline
    elseif  not match(line, "^ *$")
        and not match(line, "^%%%%Invocation")
        and not match(line, "^%%%%%+")
    then
      line = gsub(line, "%/ID( ?)%[<[^>]+><[^>]+>]", "/ID%1[<ID-STRING><ID-STRING>]")
      new_content = new_content .. line .. os_newline
    end
  end
  return new_content
end

---Rewrite the log
---@param path_in string
---@param path_out string
---@param engine string
---@param errlevels table
function rewrite_log(path_in, path_out, engine, errlevels)
  rewrite(path_in, path_out, normalize_log, engine, errlevels)
end

---Rewrite the pdf
---@param path_in string
---@param path_out string
---@param engine string
---@param err_levels table
function rewrite_pdf(path_in, path_out, engine, err_levels)
  rewrite(path_in, path_out, normalize_pdf, engine, err_levels)
end

-- Look for a test: could be in the testfiledir or the unpackdir
---comment
---@param test string
---@return string
---@return string
local function test_exists(test)
  local file_names = {}
  for i, kind in ipairs(test_order) do
    file_names[i] = test .. test_types[kind].test
  end
  local found = locate({ testfiledir, unpackdir }, file_names)
  if found then
    for i, kind in ipairs(test_order) do
      local file_name = file_names[i]
      if found:sub(-#file_name) == file_name then
        return found, kind
      end
    end
  end
end

---comment
---@param test_type table
---@param name string
---@param engine string
---@param cleanup boolean
---@return integer
local function base_compare(test_type, name, engine, cleanup)
  local test_name = name .. "." .. engine
  local diff_file = testdir .. "/" .. test_name .. test_type.generated .. os_diffext
  local gen_file  = testdir .. "/" .. test_name .. test_type.generated
  local ref_file  = locate({ testdir }, {
    test_name .. test_type.reference,
    name .. test_type.reference })
  if not ref_file then
    return 1
  end
  local compare = test_type.compare
  if compare then
    return compare(diff_file, ref_file, gen_file, cleanup, name, engine)
  end
  local error_level = execute(os_diffexe .. " "
    .. to_host(ref_file .. " " .. gen_file .. " > " .. diff_file))
  if error_level == 0 or cleanup then
    remove(diff_file)
  end
  return error_level
end

local function showfailedlog(name)
  print("\nCheck failed with log file")
  for i in all_files(testdir, name..".log") do
    print("  - " .. testdir .. "/" .. i)
    print("")
    local f = open(testdir .. "/" .. i, "r")
    local content = f:read("a")
    close(f)
    print("-----------------------------------------------------------------------------------")
    print(content)
    print("-----------------------------------------------------------------------------------")
  end
end

local function showfaileddiff()
  print("\nCheck failed with difference file")
  for i in all_files(testdir, "*" .. os_diffext) do
    print("  - " .. testdir .. "/" .. i)
    print("")
    local fh = open(testdir .. "/" .. i, "r")
    local content = fh:read("a")
    fh:close()
    print("-----------------------------------------------------------------------------------")
    print(content)
    print("-----------------------------------------------------------------------------------")
  end
end

-- Run one of the test files: doesn't check the result so suitable for
-- both creating and verifying
---comment
---@param name string
---@param engine string
---@param hide boolean
---@param ext string
---@param test_type table
---@param breakout any
---@return integer
local function run_test(name, engine, hide, ext, test_type, breakout)
  local lvt_file = name .. (ext or lvtext)
  copy_tree(lvt_file,
    file_exists(testfiledir .. "/" .. lvt_file)
      and testfiledir
      or unpackdir,
    testdir)
  local check_opts = checkopts
  engine = engine or stdengine
  local binary = engine
  local format = gsub(engine, "tex$", checkformat)
  -- Special binary/format combos
  local special_check = specialformats[checkformat]
  if special_check and next(special_check) then
    local engine_info = special_check[engine]
    if engine_info then
      binary      = engine_info.binary  or binary
      format      = engine_info.format  or format
      check_opts  = engine_info.options or check_opts
    end
  end
  -- Finalise format string
  if format ~= "" then
    format = " --fmt=" .. format
  end
  -- Special casing for XeTeX engine
  if match(engine, "xetex") and test_type.generated ~= pdfext then
    check_opts = check_opts .. " -no-pdf"
  end
  -- Special casing for ConTeXt
  local setup
  if match(checkformat, "^context$") then
    function setup(file) return ' "' .. file .. '" '  end
  else
    function setup(file)
      return " -jobname=" .. name .. " " .. ' "\\input ' .. file .. '" '
    end
  end

  local base_name = testdir .. "/" .. name
  local gen_file = base_name .. test_type.generated
  local new_file = base_name .. "." .. engine .. test_type.generated
  local ascii_opt = ""
  for i in entries(asciiengines) do
    if binary == i then
      ascii_opt = "-translate-file ./ascii.tcx "
      break
    end
  end
  -- Clean out any dynamic files
  for filetype in entries(dynamicfiles) do
    remove_tree(testdir, filetype)
  end
  -- Ensure there is no stray .log file
  remove_file(testdir, name .. logext)
  local errlevels = {}
  local localtexmf = ""
  if texmfdir and texmfdir ~= "" and directory_exists(texmfdir) then
    localtexmf = os_pathsep .. absolute_path(texmfdir) .. "//"
  end
  for i = 1, checkruns do
    errlevels[i] = run(
      testdir, cmd_concat(
        -- No use of localdir here as the files get copied to testdir:
        -- avoids any paths in the logs
        os_setenv .. " TEXINPUTS=." .. localtexmf
          .. (checksearch and os_pathsep or ""),
        os_setenv .. " LUAINPUTS=." .. localtexmf
          .. (checksearch and os_pathsep or ""),
        -- Avoid spurious output from (u)pTeX
        os_setenv .. " GUESS_INPUT_KANJI_ENCODING=0",
        -- Allow for local texmf files
        os_setenv .. " TEXMFCNF=." .. os_pathsep,
        set_epoch_cmd(epoch, forcecheckepoch),
        -- Ensure lines are of a known length
        os_setenv .. " max_print_line=" .. maxprintline,
        binary .. format
          .. " " .. ascii_opt .. " " .. check_opts
          .. setup(lvt_file)
          .. (hide and (" > " .. os_null) or ""),
        runtest_tasks(job_name(lvt_file), i)
      )
    )
    -- Break the loop if the result is stable
    if breakout and i < checkruns then
      if test_type.generated == pdfext then
        if file_exists(testdir .. "/" .. name .. dviext) then
          dvitopdf(name, testdir, engine, hide)
        end
      end
      test_type.rewrite(gen_file, new_file, engine, errlevels)
      if base_compare(test_type, name, engine, true) == 0 then
        break
      end
    end
  end
  if test_type.generated == pdfext then
    if file_exists(testdir .. "/" .. name .. dviext) then
      dvitopdf(name, testdir, engine, hide)
    end
    copy_tree(name .. pdfext, testdir, resultdir)
    rename(resultdir, name .. pdfext, name .. "." .. engine .. pdfext)
  end
  test_type.rewrite(gen_file, new_file, engine, errlevels)
  -- Store secondary files for this engine
  for filetype in entries(auxfiles) do
    for file in all_files(testdir, filetype) do
      if match(file, "^" .. name .. "%.[^.]+$") then
        local newname = gsub(file, "(%.[^.]+)$", "." .. engine .. "%1")
        if file_exists(testdir .. "/" .. newname) then
          remove_file(testdir, newname)
        end
        rename(testdir, file, newname)
      end
    end
  end
  return 0
end

---Used by run_check
---@param name string
---@param engine string
local function setup_check(name, engine)
  local test_name = name .. "." .. engine
  local found
  for kind in entries(test_order) do
    local reference_ext = test_types[kind].reference
    local reference_file = locate(
      { testfiledir, unpackdir },
      { test_name .. reference_ext, name .. reference_ext }
    )
    if reference_file then
      found = true
      -- Install comparison file found
      copy_tree(
        match(reference_file, ".*/(.*)"),
        match(reference_file, "(.*)/.*"),
        testdir
      )
    end
  end
  if found then
     return
  end
  -- Attempt to generate missing reference file from expectation
  for kind in entries(test_order) do
    local test_type = test_types[kind]
    local exp_ext = test_type.expectation
    local expectation_file = exp_ext and locate(
      { testfiledir, unpackdir },
      { name .. exp_ext }
    )
    if expectation_file then
      found = true
      run_test(name, engine, true, exp_ext, test_type)
      rename(testdir,
        test_name .. test_type.generated,
        test_name .. test_type.reference)
    end
  end
  if found then
     return
  end
  print(
    "Error: failed to find any reference or expectation file for "
      .. name .. "!"
  )
  exit(1)
end

---Used by run_check
---@param name string test name
---@param engine string
---@param hide boolean
---@param ext string extension
---@param type string test type
---@return integer
local function check_and_diff(name, engine, hide, ext, type)
  run_test(name, engine, hide, ext, type, true)
  local error_level = base_compare(type, name, engine)
  if error_level == 0 then
    return error_level
  end
  if options["show-log-on-error"] then
    showfailedlog(name)
  end
  if options["halt-on-error"] then
    showfaileddiff()
  end
  return error_level
end

---Run one test which may have multiple engine-dependent comparisons
---Should create a difference file for each failed test
---@param test_name string
---@param hide boolean
---@return integer
local function run_check(test_name, hide)
  local file_name, kind = test_exists(test_name)
  if not file_name then
    print("Failed to find input for test " .. test_name)
    return 1
  end
  local check_engines = checkengines
  if options["engine"] then
    check_engines = options["engine"]
  end
  -- Used for both .lvt and .pvt tests
  local test_type = test_types[kind]
  local error_level = 0
  for engine in entries(check_engines) do
    setup_check(test_name, engine)
    local errlevel = check_and_diff(test_name, engine, hide, test_type.test, test_type)
    if errlevel ~= 0 and options["halt-on-error"] then
      return 1
    end
    if errlevel > error_level then
      error_level = errlevel
    end
  end
  -- Return everything
  return error_level
end

---Comparator for tlg
---@param diff_file string
---@param tlg_file string
---@param log_file string
---@param cleanup boolean
---@param name string
---@param engine string
---@return integer
function compare_tlg(diff_file, tlg_file, log_file, cleanup, name, engine)
  local error_level
  local test_name = name .. "." .. engine
  -- Do additional log formatting if the engine is LuaTeX, there is no
  -- LuaTeX-specific .tlg file and the default engine is not LuaTeX
  if (match(engine, "^lua") or match(engine, "^harf"))
  and not match(tlg_file, "%.luatex" .. "%" .. tlgext)
  and not match(stdengine, "^lua")
  then
    local lua_log_file
    if cleanup then
      lua_log_file = testdir .. "/" .. test_name .. ".tmp" .. logext
    else
      lua_log_file = log_file
    end
    local lua_tlg_file = testdir .. "/" .. test_name .. tlgext
    rewrite(tlg_file, lua_tlg_file, normalize_lua_log)
    rewrite(log_file, lua_log_file, normalize_lua_log, true)
    error_level = execute(os_diffexe .. " "
      .. to_host(lua_tlg_file .. " " .. lua_log_file .. " > " .. diff_file))
    if cleanup then
      remove(lua_log_file)
      remove(lua_tlg_file)
    end
  else
    error_level = execute(os_diffexe .. " "
      .. to_host(tlg_file .. " " .. log_file .. " > " .. diff_file))
  end
  if error_level == 0 or cleanup then
    remove(diff_file)
  end
  return error_level
end

-- A hook to allow additional tasks to run for the tests
runtest_tasks = runtest_tasks or function(name, run)
  return ""
end

-- A short auxiliary to print the list of differences for check
local function checkdiff()
  print("\n  Check failed with difference files")
  for i in all_files(testdir, "*" .. os_diffext) do
    print("  - " .. testdir .. "/" .. i)
  end
  print("")
end

function check(names)
  local errorlevel = 0
  if testfiledir ~= "" and directory_exists(testfiledir) then
    if not options["rerun"] then
      checkinit()
    end
    local hide = true
    if names and next(names) then
      hide = false
    end
    names = names or {}
    -- No names passed: find all test files
    if not next(names) then
      for kind in entries(test_order) do
        local ext = test_types[kind].test
        local excludepatterns = {}
        local num_exclude = 0
        for glob in entries(excludetests) do
          num_exclude = num_exclude+1
          excludepatterns[num_exclude] = glob_to_pattern(glob .. ext)
        end
        for glob in entries(includetests) do
          for name in all_files(testfiledir, glob .. ext) do
            local exclude
            for i = 1, num_exclude do
              if match(name, excludepatterns[i]) then
                exclude = true
                break
              end
            end
            if not exclude then
              insert(names, job_name(name))
            end
          end
          for name in all_files(unpackdir, glob .. ext) do
            local exclude
            for i = 1, num_exclude do
              if not match(name, excludepatterns[i]) then
                exclude = true
                break
              end
            end
            if not exclude then
              if file_exists(testfiledir .. "/" .. name) then
                return 1
              end
              insert(names, job_name(name))
            end
          end
        end
      end
      sort(names)
      -- Deal limiting range of names
      local firstname = options["first"]
      if firstname then
        local allnames = names
        names = {}
        for i, name in ipairs(allnames) do
          if name == firstname then
            names = { tbl_unpack(allnames, i) }
            break
          end
        end
      end
      local lastname = options["last"]
      if lastname then
        local allnames = names
        names = {}
        for i, name in ipairs(allnames) do
          if name == lastname then
            names = { tbl_unpack(allnames, 1, i) }
            break
          end
        end
      end
    end
    if options["shuffle"] then
      -- https://stackoverflow.com/a/32167188
      for i = #names, 2, -1 do
        local j = rnd(1, i)
        names[i], names[j] = names[j], names[i]
      end
    end
    -- Actually run the tests
    print("Running checks on")
    for i, name in ipairs(names) do
      print("  " .. name .. " (" ..  i .. "/" .. #names ..")")
      local errlevel = run_check(name, hide)
      -- Return value must be 1 not errlevel
      if errlevel ~= 0 then
        if options["halt-on-error"] then
          return 1
        else
          errorlevel = 1
          -- visually show that something has failed
          print("          --> failed\n")
        end
      end
    end
    if errorlevel ~= 0 then
      checkdiff()
    else
      print("\n  All checks passed\n")
    end
  end
  return errorlevel
end

function save(names)
  checkinit()
  local engines = options["engine"] or { stdengine }
  if names == nil then
    print("Arguments are required for the save command")
    return 1
  end
  for name in entries(names) do
    local test_filename, kind = test_exists(name)
    if not test_filename then
      print('Test "' .. name .. '" not found')
      return 1
    end
    local test_type = test_types[kind]
    if locate({ unpackdir, testfiledir }, { name .. test_type.expectation }) then
      print("Saved " .. test_type.test .. " file would override a "
        .. test_type.expectation .. " file of the same name")
      return 1
    end
    for engine in entries(engines) do
      local testengine = engine == stdengine and "" or ("." .. engine)
      local out_file = name .. testengine .. test_type.reference
      local gen_file = name .. "." .. engine .. test_type.generated
      print("Creating and copying " .. out_file)
      run_test(name, engine, false, test_type.test, test_type)
      rename(testdir, gen_file, out_file)
      copy_tree(out_file, testdir, testfiledir)
      if file_exists(unpackdir .. "/" .. test_type.reference) then
        print("Saved " .. test_type.reference
          .. " file overrides unpacked version of the same name")
        return 1
      end
    end
  end
  return 0
end
