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

local print           = print
local not_empty       = next
local open            = io.open
local rnd             = math.random
local status          = require("status")
local luatex_version  = status.luatex_version
local len             = string.len
local char            = string.char
local str_format      = string.format
local gsub            = string.gsub
local match           = string.match

local append          = table.insert
local sort            = table.sort
local tbl_unpack      = table.unpack

local unicode         = require("unicode")
local utf8_char       = unicode.utf8.char

local exit            = os.exit
local execute         = os.execute
local remove          = os.remove

---@type utlib_t
local utlib           = require("l3b-utillib")
local deep_copy       = utlib.deep_copy
local chooser         = utlib.chooser
local entries         = utlib.entries
local first_of        = utlib.first_of
local extend_with     = utlib.extend_with
local read_content    = utlib.read_content
local write_content   = utlib.write_content

---@type gblib_t
local gblib           = require("l3b-globlib")
local to_glob_match = gblib.to_glob_match

---@type wklib_t
local wklib     = require("l3b-walklib")
local job_name  = wklib.job_name

---@type oslib_t
local oslib       = require("l3b-oslib")
local cmd_concat  = oslib.cmd_concat
local run         = oslib.run

---@type fslib_t
local fslib       = require("l3b-fslib")
local all_names   = fslib.all_names
local copy_file   = fslib.copy_file
local copy_tree   = fslib.copy_tree
local file_exists = fslib.file_exists
local locate      = fslib.locate
local rename      = fslib.rename
local to_host     = fslib.to_host
local remove_tree = fslib.remove_tree
local remove_name = fslib.remove_name
local directory_exists      = fslib.directory_exists
local absolute_path         = fslib.absolute_path
local make_clean_directory  = fslib.make_clean_directory

---@type l3build_t
local l3build = require("l3build")

---@type l3b_aux_t
local l3b_aux   = require("l3build-aux")
local call      = l3b_aux.call

---@type l3b_help_t
local l3b_help  = require("l3build-help")
local help      = l3b_help.help

---@type l3b_vars_t
local l3b_vars  = require("l3build-variables")
---@type Main_t
local Main      = l3b_vars.Main
---@type Xtn_t
local Xtn       = l3b_vars.Xtn
---@type Dir_t
local Dir       = l3b_vars.Dir
---@type Files_t
local Files     = l3b_vars.Files
---@type Deps_t
local Deps      = l3b_vars.Deps
---@type Opts_t
local Opts      = l3b_vars.Opts

---@type l3b_aux_t
local l3b_aux       = require("l3build-aux")
local set_epoch_cmd = l3b_aux.set_epoch_cmd
local deps_install  = l3b_aux.deps_install

---@type l3b_unpk_t
local l3b_unpk    = require("l3build-unpack")
local bundleunpack  = l3b_unpk.Vars.bundleunpack

-- Variables

---@class test_types_t
---@field log table<string, string|function>
---@field pdf table<string, string|function>

---@class l3b_check_vars_t
---@field checkengines  string_list_t Engines to check with \texttt{check} by default
---@field stdengine     string  Engine to generate \texttt{.tlg} file from
---@field checkformat   string  Format to use for tests
---@field specialformats table  Non-standard engine/format combinations
---@field test_types    test_types_t  Custom test variants
---@field test_order    string_list_t Which kinds of tests to evaluate
-- Configs for testing
---@field checkconfigs  table   Configurations to use for tests
---@field includetests  string_list_t Test names to include when checking
---@field excludetests  string_list_t Test names to exclude when checking
---@field recordstatus  boolean Switch to include error level from test runs in \texttt{.tlg} files
---@field forcecheckepoch boolean Force epoch when running tests
---@field asciiengines  string_list_t Engines which should log as pure ASCII
---@field checkruns     integer Number of runs to complete for a test before comparing the log
---@field checksearch   boolean Switch to search the system \texttt{texmf} for during checking
---@field maxprintline  integer Length of line to use in log files
---@field runtest_tasks fun(test_name: string, run_number: integer): string
---@field checkinit_hook fun(): error_level_n
---@field ps2pdfopt     string  Options for \texttt{ps2pdf}

---@type l3b_check_vars_t
local dflt = {} -- define below

---@type l3b_check_vars_t
local Vars = chooser({
  global = _G,
  default = dflt,
  computed = {
    unique_config = function (t, k, dflt_k)
      local configs = t.checkconfigs
      if #configs == 1 then
        local result = configs[1]
        if result ~= "build" then
          return result
        end
      end
    end,
    forcecheckepoch = function (t, k, dflt_k)
      local options = l3build.options
      if options.epoch then
        return true
      end
    end,
  },
  complete = function (t, k, result)
    -- No trailing /
    -- What about the leading "./"
    local options = l3build.options
    if k == "checkconfigs" then
      -- When we have specific files to deal with, only use explicit configs
      -- (or just the std one)
      -- TODO: Justify this...
      if options.names then
        return options.config or { _G.stdconfig }
      else
        return options.config or result
      end
    elseif k == "forcecheckepoch" then
      if options.epoch then
        return true -- overwrite any global setting
      end
    end
    return result
  end,
})

---dvi2pdf, used while checking
---@param name string
---@param dir string
---@param engine string
---@param hide boolean
---@return error_level_n
local function dvi2pdf(name, dir, engine, hide)
  return run(
    dir, cmd_concat(
      set_epoch_cmd(Main.epoch, Vars.forcecheckepoch),
      "dvips " .. name .. Xtn.dvi
        .. (hide and (" > " .. _G.os_null) or ""),
      "ps2pdf " .. Vars.ps2pdfopt .. name .. Xtn.ps
        .. (hide and (" > " .. _G.os_null) or "")
    ) and 0 or 1
  )
end

--
-- Auxiliary functions which are used by more than one main function
--

---Default function that can be overwritten
---@return error_level_n
local function checkinit_hook()
  return 0
end

-- Set up the check system files: needed for checking one or more tests and
-- for saving the test files
local function checkinit()
  local options = l3build.options
  if not options.dirty then
    make_clean_directory(Dir.test)
    make_clean_directory(Dir.result)
  end
  deps_install(Deps.check)
  -- Copy dependencies to the test directory itself: this makes the paths
  -- a lot easier to manage, and is important for dealing with the log and
  -- with file input/output tests
  for i in all_names(Dir[l3b_vars.LOCAL]) do
    copy_tree(i, Dir[l3b_vars.LOCAL], Dir.test)
  end
  bundleunpack({ Dir.sourcefile, Dir.testfile })
  for i in entries(Files.install) do
    copy_tree(i, Dir.unpack, Dir.test)
  end
  for i in entries(Files.check) do
    copy_tree(i, Dir.unpack, Dir.test)
  end
  if directory_exists(Dir.testsupp) then
    for i in all_names(Dir.testsupp) do
      copy_tree(i, Dir.testsupp, Dir.test)
    end
  end
  for i in entries(Files.checksupp) do
    copy_tree(i, Dir.support, Dir.test)
  end
  execute(_G.os_ascii .. ">" .. Dir.test .. "/ascii.tcx")
  return Vars.checkinit_hook()
end

---Apply the `translator` to the content at `path_in`
---and save the result to `path_out`.
---@param path_in string
---@param path_out string
---@param translator fun(content: string, ...): string
---@vararg any
local function rewrite(path_in, path_out, translator, ...)
  local content = read_content(path_in, true)
  if not content then
    --[===[ DEBUG CODE TO BE REMOVED ]===]
    local file_path = path_in
    local is_binary = true
    if file_path then
      local fh = open(file_path, is_binary and "rb" or "r")
      if fh then
        local content = fh:read("a")
        fh:close()
        print(not is_binary and os["type"] == "windows"
          and content:gsub("\r\n?", "\n")
          or  content)
      end
    end
    --[===[ END OF DEBUG CODE ]===]
    error("No content available at ".. path_in)
  end
  content = gsub(content .. "\n", "\r\n", "\n")
  content = translator(content, ...)
  write_content(path_out, content)
end

---Convert the raw log file into one for comparison/storage: keeps only
---the 'business' part from the tests and removes system-dependent stuff
---@param content string
---@param engine string
---@param errlevels table
---@return string
local function normalize_log(content, engine, errlevels)
  local max_print_line = Vars.maxprintline
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
    if not match(Vars.stdengine, "^e?u?ptex$") then
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
    if not_empty(Vars.asciiengines) then
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
  for line in content:gmatch("([^\n]*)\n") do
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
        new_content = new_content .. line .. _G.os_newline
      end
    end
  end
  if Vars.recordstatus then
    new_content = new_content .. '***************' .. _G.os_newline
    for i = 1, Vars.checkruns do
      if errlevels[i] == nil then
        new_content = new_content
          .. 'Compilation ' .. i .. ' of test file skipped ' .. _G.os_newline
      else
        new_content = new_content ..
          'Compilation ' .. i .. ' of test file completed with exit status ' ..
          errlevels[i] .. _G.os_newline
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
      return first_of(gsub(
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
      return first_of(gsub(match(s, "^(%.+)"), "%.", "%%."))
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
        return last_line .. _G.os_newline .. line, ""
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
        return last_line .. _G.os_newline .. line, ""
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
    local max_print_line = Vars.maxprintline
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
        return last_line .. _G.os_newline .. line, ""
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
  for line in content:gmatch("([^\n]*)\n") do
    line, lastline, dropping = normalize(line, lastline, dropping)
    if not match(line, "^ *$") then
      new_content = new_content .. line .. _G.os_newline
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
  for line in content:gmatch("([^\n]*)\n") do
    if is_stream then
      if match(line, "endstream") then
        is_stream = false
        if is_binary then
          new_content = new_content .. "[BINARY STREAM]" .. _G.os_newline
        else
          new_content = new_content .. stream_content .. line .. _G.os_newline
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
          stream_content = stream_content .. line .. _G.os_newline
        end
      end
    elseif match(line, "^stream$") then
      is_binary = false
      is_stream = true
      stream_content = "stream" .. _G.os_newline
    elseif  not match(line, "^ *$")
        and not match(line, "^%%%%Invocation")
        and not match(line, "^%%%%%+")
    then
      line = gsub(line, "%/ID( ?)%[<[^>]+><[^>]+>]", "/ID%1[<ID-STRING><ID-STRING>]")
      new_content = new_content .. line .. _G.os_newline
    end
  end
  return new_content
end

---Rewrite the log
---@param path_in string
---@param path_out string
---@param engine string
---@param err_levels table<integer, error_level_n>
local function rewrite_log(path_in, path_out, engine, err_levels)
  rewrite(path_in, path_out, normalize_log, engine, err_levels)
end

---Rewrite the pdf
---@param path_in string
---@param path_out string
---@param engine string
---@param err_levels table<integer, error_level_n>
local function rewrite_pdf(path_in, path_out, engine, err_levels)
  rewrite(path_in, path_out, normalize_pdf, engine, err_levels)
end

-- Look for a test: could be in the Dir.testfile or the Dir.unpack
---comment
---@param test string
---@return string
---@return string
local function test_exists(test)
  ---@type string_list_t
  local file_names = {}
  for i, kind in ipairs(Vars.test_order) do
    file_names[i] = test .. Vars.test_types[kind].test
  end
  local found = locate({ Dir.testfile, Dir.unpack }, file_names)
  if found then
    for i, kind in ipairs(Vars.test_order) do
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
---@return error_level_n
local function base_compare(test_type, name, engine, cleanup)
  local test_name = name .. "." .. engine
  local diff_file = Dir.test .. "/" .. test_name .. test_type.generated .. _G.os_diffext
  local gen_file  = Dir.test .. "/" .. test_name .. test_type.generated
  local ref_file  = locate({ Dir.test }, {
    test_name .. test_type.reference,
    name .. test_type.reference })
  if not ref_file then
    return 1
  end
  local compare = test_type.compare
  if compare then
    return compare(diff_file, ref_file, gen_file, cleanup, name, engine)
  end
  local error_level = execute(_G.os_diffexe .. " "
    .. to_host(ref_file .. " " .. gen_file .. " > " .. diff_file))
  if error_level == 0 or cleanup then
    remove(diff_file)
  end
  return error_level
end

local function show_failed_log(name)
  print("\nCheck failed with log file")
  for i in all_names(Dir.test, name..".log") do
    print("  - " .. Dir.test .. "/" .. i)
    print("")
    print("-----------------------------------------------------------------------------------")
    print(read_content(Dir.test .. "/" .. i))
    print("-----------------------------------------------------------------------------------")
  end
end

local function show_failed_diff()
  print("\nCheck failed with difference file")
  for i in all_names(Dir.test, "*" .. _G.os_diffext) do
    print("  - " .. Dir.test .. "/" .. i)
    print("")
    print("-----------------------------------------------------------------------------------")
    print(read_content(Dir.test .. "/" .. i))
    print("-----------------------------------------------------------------------------------")
  end
end

-- A hook to allow additional tasks to run for the tests
---comment
---@param test_name string
---@param run_number integer
---@return string
local function runtest_tasks(test_name, run_number)
  return ""
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
---@return error_level_n
local function run_test(name, engine, hide, ext, test_type, breakout)
  local lvt_file = name .. (ext or Xtn.lvt)
  copy_tree(lvt_file,
    file_exists(Dir.testfile .. "/" .. lvt_file)
      and Dir.testfile
      or Dir.unpack,
    Dir.test)
  local check_opts = Opts.check
  engine = engine or Vars.stdengine
  local binary = engine
  local format = gsub(engine, "tex$", Vars.checkformat)
  -- Special binary/format combos
  local special_check = Vars.specialformats[Vars.checkformat]
  if special_check and not_empty(special_check) then
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
  if match(engine, "xetex") and test_type.generated ~= Xtn.pdf then
    check_opts = check_opts .. " -no-pdf"
  end
  -- Special casing for ConTeXt
  local setup
  if match(Vars.checkformat, "^context$") then
    function setup(file)
      return ' "' .. file .. '" '
    end
  else
    function setup(file)
      return " -jobname=" .. name .. " " .. ' "\\input ' .. file .. '" '
    end
  end

  local base_name = Dir.test .. "/" .. name
  local gen_file = base_name .. test_type.generated
  local new_file = base_name .. "." .. engine .. test_type.generated
  local ascii_opt = ""
  for i in entries(Vars.asciiengines) do
    if binary == i then
      ascii_opt = "-translate-file ./ascii.tcx "
      break
    end
  end
  -- Clean out any dynamic files
  for filetype in entries(Files.dynamic) do
    remove_tree(Dir.test, filetype)
  end
  -- Ensure there is no stray .log file
  remove_name(Dir.test, name .. Xtn.log)
  ---@type table<integer, error_level_n>
  local err_levels = {}
  local localtexmf = ""
  if Dir.texmf and Dir.texmf ~= "" and directory_exists(Dir.texmf) then
    localtexmf = _G.os_pathsep .. absolute_path(Dir.texmf) .. "//"
  end
  for run_number = 1, Vars.checkruns do
    err_levels[run_number] = run(
      Dir.test, cmd_concat(
        -- No use of Dir.local here as the files get copied to Dir.test:
        -- avoids any paths in the logs
        _G.os_setenv .. " TEXINPUTS=." .. localtexmf
          .. (Vars.checksearch and _G.os_pathsep or ""),
        _G.os_setenv .. " LUAINPUTS=." .. localtexmf
          .. (Vars.checksearch and _G.os_pathsep or ""),
        -- Avoid spurious output from (u)pTeX
        _G.os_setenv .. " GUESS_INPUT_KANJI_ENCODING=0",
        -- Allow for local texmf files
        _G.os_setenv .. " TEXMFCNF=." .. _G.os_pathsep,
        set_epoch_cmd(Main.epoch, Vars.forcecheckepoch),
        -- Ensure lines are of a known length
        _G.os_setenv .. " max_print_line=" .. Vars.maxprintline,
        binary .. format
          .. " " .. ascii_opt .. " " .. check_opts
          .. setup(lvt_file)
          .. (hide and (" > " .. _G.os_null) or ""),
        Vars.runtest_tasks(job_name(lvt_file), run_number)
      )
    )
    -- Break the loop if the result is stable
    if breakout and run_number < Vars.checkruns then
      if test_type.generated == Xtn.pdf then
        if file_exists(Dir.test .. "/" .. name .. Xtn.dvi) then
          dvi2pdf(name, Dir.test, engine, hide)
        end
      end
      test_type.rewrite(gen_file, new_file, engine, err_levels)
      if base_compare(test_type, name, engine, true) == 0 then
        break
      end
    end
  end
  if test_type.generated == Xtn.pdf then
    if file_exists(Dir.test .. "/" .. name .. Xtn.dvi) then
      dvi2pdf(name, Dir.test, engine, hide)
    end
    copy_tree(name .. Xtn.pdf, Dir.test, Dir.result)
    rename(Dir.result, name .. Xtn.pdf, name .. "." .. engine .. Xtn.pdf)
  end
  test_type.rewrite(gen_file, new_file, engine, err_levels)
  -- Store secondary files for this engine
  for filetype in entries(Files.aux) do
    for file in all_names(Dir.test, filetype) do
      if match(file, "^" .. name .. "%.[^.]+$") then
        local newname = gsub(file, "(%.[^.]+)$", "." .. engine .. "%1")
        if file_exists(Dir.test .. "/" .. newname) then
          remove_name(Dir.test, newname)
        end
        rename(Dir.test, file, newname)
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
  for kind in entries(Vars.test_order) do
    local reference_ext = Vars.test_types[kind].reference
    local reference_file = locate(
      { Dir.testfile, Dir.unpack },
      { test_name .. reference_ext, name .. reference_ext }
    )
    if reference_file then
      found = true
      -- Install comparison file found
      copy_tree(
        match(reference_file, ".*/(.*)"),
        match(reference_file, "(.*)/.*"),
        Dir.test
      )
    end
  end
  if found then
     return
  end
  -- Attempt to generate missing reference file from expectation
  for kind in entries(Vars.test_order) do
    local test_type = Vars.test_types[kind]
    local exp_ext = test_type.expectation
    local expectation_file = exp_ext and locate(
      { Dir.testfile, Dir.unpack },
      { name .. exp_ext }
    )
    if expectation_file then
      found = true
      run_test(name, engine, true, exp_ext, test_type)
      rename(Dir.test,
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
---@return error_level_n
local function check_and_diff(name, engine, hide, ext, type)
  run_test(name, engine, hide, ext, type, true)
  local error_level = base_compare(type, name, engine)
  if error_level == 0 then
    return error_level
  end
  local options = l3build.options
  if options["show-log-on-error"] then
    show_failed_log(name)
  end
  if options["halt-on-error"] then
    show_failed_diff()
  end
  return error_level
end

---Run one test which may have multiple engine-dependent comparisons
---Should create a difference file for each failed test
---@param test_name string
---@param hide boolean
---@return error_level_n
local function run_check(test_name, hide)
  local options = l3build.options
  local file_name, kind = test_exists(test_name)
  if not file_name then
    print("Failed to find input for test " .. test_name)
    return 1
  end
  local check_engines = Vars.checkengines
  if options.engine then
    check_engines = options.engine
  end
  -- Used for both .lvt and .pvt tests
  local test_type = Vars.test_types[kind]
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
---@return error_level_n
local function compare_tlg(diff_file, tlg_file, log_file, cleanup, name, engine)
  local error_level
  local test_name = name .. "." .. engine
  -- Do additional log formatting if the engine is LuaTeX, there is no
  -- LuaTeX-specific .tlg file and the default engine is not LuaTeX
  if (match(engine, "^lua") or match(engine, "^harf"))
  and not match(tlg_file, "%.luatex" .. "%" .. Xtn.tlg)
  and not match(Vars.stdengine, "^lua")
  then
    local lua_log_file
    if cleanup then
      lua_log_file = Dir.test .. "/" .. test_name .. ".tmp" .. Xtn.log
    else
      lua_log_file = log_file
    end
    local lua_tlg_file = Dir.test .. "/" .. test_name .. Xtn.tlg
    rewrite(tlg_file, lua_tlg_file, normalize_lua_log)
    rewrite(log_file, lua_log_file, normalize_lua_log, true)
    error_level = execute(_G.os_diffexe .. " "
      .. to_host(lua_tlg_file .. " " .. lua_log_file .. " > " .. diff_file))
    if cleanup then
      remove(lua_log_file)
      remove(lua_tlg_file)
    end
  else
    error_level = execute(_G.os_diffexe .. " "
      .. to_host(tlg_file .. " " .. log_file .. " > " .. diff_file))
  end
  if error_level == 0 or cleanup then
    remove(diff_file)
  end
  return error_level
end

-- A short auxiliary to print the list of differences for check
local function check_diff()
  print("\n  Check failed with difference files")
  for i in all_names(Dir.test, "*" .. _G.os_diffext) do
    print("  - " .. Dir.test .. "/" .. i)
  end
  print("")
end

-- define the default once the required object are properly defined
extend_with(dflt, {
  includetests  = { "*" },
  excludetests  = {},
  checkengines    = { "pdftex", "xetex", "luatex" },
  stdengine     = "pdftex",
  checkformat   = "latex",
  -- specialformats is defined below
  test_types = {
    log = {
      test = Xtn.lvt,
      generated = Xtn.log,
      reference = Xtn.tlg,
      expectation = Xtn.lve,
      compare = compare_tlg,
      rewrite = rewrite_log,
    },
    pdf = {
      test = Xtn.pvt,
      generated = Xtn.pdf,
      reference = Xtn.tpf,
      rewrite = rewrite_pdf,
    },
  },
  test_order    = { "log", "pdf" },
  checkconfigs  = { "build" },
  checksearch   = true,
  recordstatus  = false,
  forcecheckepoch = true,
  asciiengines  = { "pdftex" },
  checkruns     = 1,
  maxprintline  = 79,
  checkinit_hook  = checkinit_hook,
  runtest_tasks = runtest_tasks,
  ps2pdfopt     = "",
})

dflt.specialformats = {
  context = {
    luatex = { binary = "context", format = "" },
    pdftex = { binary = "texexec", format = "" },
    xetex  = { binary = "texexec", format = "", options = "--xetex" }
  },
  latex = {
    etex  = { format = "latex" },
    ptex  = { binary = "eptex" },
    uptex = { binary = "euptex" }
  }
}

if not string.find(status.banner," 2019") then
  dflt.specialformats.latex.luatex = {
    binary = "luahbtex",
    format = "lualatex"
  }
  dflt.specialformats["latex-dev"] = {
    luatex = {
      binary ="luahbtex",
      format = "lualatex-dev"
    }
  }
end

---Check
---@param names string_list_t
---@return error_level_n
local function check(names)
  local error_level = 0
  if Dir.testfile ~= "" and directory_exists(Dir.testfile) then
    local options = l3build.options
    if not options.rerun then
      checkinit()
    end
    local hide = true
    if names and not_empty(names) then
      hide = false
    end
    names = names or {}
    -- No names passed: find all test files
    if not not_empty(names) then
      for kind in entries(Vars.test_order) do
        local ext = Vars.test_types[kind].test
        ---@type table<integer, glob_match_f>
        local exclude_glob_matches = {}
        for glob in entries(Vars.excludetests) do
          append(exclude_glob_matches, to_glob_match(glob .. ext))
        end
        for glob in entries(Vars.includetests) do
          for name in all_names(Dir.testfile, glob .. ext) do
            local is_excluded
            for glob_match in entries(exclude_glob_matches) do
              if glob_match(name) then
                is_excluded = true
                break
              end
            end
            if not is_excluded then
              append(names, job_name(name))
            end
          end
          for name in all_names(Dir.unpack, glob .. ext) do
            local is_excluded
            for glob_match in entries(exclude_glob_matches) do
              if not glob_match(name) then
                is_excluded = true
                break
              end
            end
            if not is_excluded then
              if file_exists(Dir.testfile .. "/" .. name) then
                return 1
              end
              append(names, job_name(name))
            end
          end
        end
      end
      sort(names)
      -- Deal limiting range of names
      local firstname = options.first
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
      local lastname = options.last
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
    if options.shuffle then
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
          error_level = 1
          -- visually show that something has failed
          print("          --> failed\n")
        end
      end
    end
    if error_level ~= 0 then
      check_diff()
    else
      print("\n  All checks passed\n")
    end
  end
  return error_level
end

---Prepare material for a forthcoming check.
---@param names string_list_t
---@return error_level_n
local function save(names)
  if names == nil then
    print("Arguments are required for the save command")
    return 1
  end
  checkinit()
  local options = l3build.options
  local engines = options.engine or { Vars.stdengine }
  for name in entries(names) do
    local test_filename, kind = test_exists(name)
    if not test_filename then
      print('Test "' .. name .. '" not found')
      return 1
    end
    local test_type = Vars.test_types[kind]
    if locate({ Dir.unpack, Dir.testfile }, { name .. test_type.expectation }) then
      print("Saved " .. test_type.test .. " file would override a "
        .. test_type.expectation .. " file of the same name")
      return 1
    end
    for engine in entries(engines) do
      local test_engine = engine == Vars.stdengine and "" or ("." .. engine)
      local out_file = name .. test_engine .. test_type.reference
      local gen_file = name .. "." .. engine .. test_type.generated
      print("Creating and copying " .. out_file)
      run_test(name, engine, false, test_type.test, test_type)
      rename(Dir.test, gen_file, out_file)
      copy_file(out_file, Dir.test, Dir.testfile)
      if file_exists(Dir.unpack .. "/" .. test_type.reference) then
        print("Saved " .. test_type.reference
          .. " file overrides unpacked version of the same name")
        return 1
      end
    end
  end
  return 0
end

---Check at module level.
---@param names string_list_t
---@return error_level_n
local function module_check(names)
  if names and #names > 0 then
    print("Module checks should not list test names")
    help()
    exit(1)
  end
  return check(names)
end

---Shortcut when many configurations are given.
---Separate the check action for each configuration.
---@param options options_t
---@return error_level_n?
local function high_check(options)
  local check_configs = Vars.checkconfigs
  if #check_configs > 1 then
    local error_level = 0
    local opts = deep_copy(options)
    ---@type string_list_t
    local failed_configs = {}
    -- utlib.Vars.debug.chooser = true
    local halt_on_error = options["halt-on-error"]
    for config in entries(check_configs) do
      opts.config = { config }
      error_level = call({ "." }, "check", opts)
      if error_level ~= 0 then
        if halt_on_error then
          return error_level
        else
          append(failed_configs, config)
        end
      end
    end
    if not_empty(failed_configs) then
      for config in entries(failed_configs) do
        print("Failed tests for configuration " .. config .. ":")
        print("\n  Check failed with difference files")
        local test_dir = Dir.test
        if config ~= "build" then
          test_dir = test_dir .. "-" .. config
        end
        for name in all_names(test_dir, "*" .. _G.os_diffext) do
          print("  - " .. test_dir .. "/" .. name)
        end
        print("")
      end
      return 1
    end
    -- Avoid running the 'main' set of tests twice
    return 0
  end
end

---Sanity check
---@param options options_t
local function sanitize_engines(options)
  if options.engine and not options.force then
    -- Make a lookup table
    local t = {}
    for engine in entries(Vars.checkengines) do
      t[engine] = true
    end
    for opt_engine in entries(options.engine) do
      if not t[opt_engine] then
        print("\n! Error: Engine \"" .. opt_engine .. "\" not set up for testing!")
        print("\n  Valid values are:")
        for engine in entries(Vars.checkengines) do
          print("  - " .. engine)
        end
        print("")
        exit(1)
      end
    end
  end
end

---Run before the save operation
---@param options options_t
---@return error_level_n
local function prepare_save(options)
  sanitize_engines(options)
  return 0
end

---Run before the check operation
---@param options options_t
---@return error_level_n
local function prepare_check(options)
  sanitize_engines(options)
  return 0
end

---Load the config file, when unique and not "build".
---@return error_level_n
local function load_unique_config(options)
  local configs = Vars.checkconfigs
  if #configs ~= 1 then
    return 0
  end
  local config_1 = configs[1]
  if config_1 == "build" then
    return 0
  end
  local config_path = l3build.work_dir
    .. config_1:gsub( ".lua$", "") .. ".lua"
  if file_exists(config_path) then
    dofile(config_path)
    Dir._config = "-".. config_1
    if options.debug then
      print("DEBUG config: ", config_1)
    end
  else
    print("Error: Missing configuration " .. config_path)
    return 1
  end
  return 0
end

---Run before the save operation
---@param options options_t
---@return error_level_n
local function configure_save(options)
  return load_unique_config(options)
end

---Run before the check operation
---@param options options_t
---@return error_level_n
local function configure_check(options)
  return load_unique_config(options)
end

---@class l3b_check_t
---@field Vars              l3b_check_vars_t
---@field check_impl        target_impl_t
---@field module_check_impl target_impl_t
---@field save_impl         target_impl_t

return {
  Vars        = Vars,
  check_impl  = {
    prepare     = prepare_check,
    high_run    = high_check,
    configure   = configure_check,
    run         = check,
  },
  module_check_impl = {
    run = module_check,
  },
  save_impl = {
    prepare   = prepare_save,
    configure = configure_save,
    run       = save,
  },
}
