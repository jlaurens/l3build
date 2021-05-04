--[[

File l3b-lpeglib.lua Copyright (C) 2018-2020 The LaTeX Project

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

local print   = print

local codepoint = utf8.codepoint

local unicode   = require("unicode")
local sln_utf8  = unicode.utf8

local lpeg    = require("lpeg")
local locale  = lpeg.locale()
local P       = lpeg.P
local V       = lpeg.V
local Cg      = lpeg.Cg
local Cc      = lpeg.Cc
local Cs      = lpeg.Cs
local Cf      = lpeg.Cf
local Cmt     = lpeg.Cmt
local B       = lpeg.B
local C       = lpeg.C
local S       = lpeg.S
local R       = lpeg.R

---@type corelib_t
local corelib = require("l3b-corelib")
local bridge  = corelib.bridge

---@class lpeg_t @ convenient type for lpeg patterns

---@type lpeg_t
local white_p = S(" \t")          -- exclude "\n", no unicode space neither.

---@type lpeg_t
local eol_p   = (
  P("\n") -- consume an eol
)^-1      -- 0 or 1 end of line

local ascii_p     = R("\x00\x7F") -- one ascii char

local more_utf8   = R("\x80\xBF")

local strict_utf8_p =
    R("\xC2\xDF") * more_utf8
  + P("\xE0")     * R("\xA0\xBF") * more_utf8
  + P("\xED")     * R("\x80\x9F") * more_utf8
  + R("\xE1\xEF") * more_utf8     * more_utf8
  + P("\xF0")     * R("\x90\xBF") * more_utf8 * more_utf8
  + P("\xF4")     * R("\x80\x8F") * more_utf8 * more_utf8
  + R("\xF1\xF3") * more_utf8     * more_utf8 * more_utf8

local utf8_p      = ascii_p + strict_utf8_p
local alt_ascii_p = R("\x00\x7F") - P("\n") -- one ascii char but a newline
local alt_utf8_p  = alt_ascii_p + strict_utf8_p

---@type lpeg_t
local black_p = utf8_p - S(" \t\n") -- non horizontal space, non LF

local consume_1_character_p =
    alt_utf8_p
  + Cmt(
    1 - P("\n"),   -- and consume one byte for an erroneous UTF8 character
    function (s, i)
      _G.UFT8_DECODING_ERROR = true
      print("UTF8 problem ".. s:sub(i-1, i-1))
    end
  )

---Pattern with horizontal spaces before and after
---@param del string|number|table|lpeg_t
---@return lpeg_t
local function get_spaced_p(del)
  return white_p^0 * del * white_p^0
end

---@type lpeg_t
local spaced_colon_p = get_spaced_p(":")

---@type lpeg_t
local spaced_comma_p = get_spaced_p(",")

local variable_p =
    ("_" + locale.alpha)      -- ascii letter, or "_"
  * ("_" + locale.alnum)^0    -- ascii letter, or "_" or digit

-- for a class, type name
local identifier_p =
  variable_p * ("." * variable_p)^0

-- for a function
local function_name_p =
    variable_p
  * ( P(".") * variable_p )^0
  * ( P(":") * variable_p )^-1

---@class path_matcher_opts_t
---Matching leading dots
--[===[
By default, the character ''.'' at the start of a name
or immediately following a slash must be matched explicitly.
When `dotglob` is true or `GLOBIGNORED` is not `nil`,
this leading character ''.'' can either be matched explicitly or
by *, ? and other wildcard patterns.
--]===]
---@field public dotglob    boolean @ Ignored when global GLOBIGNORE is nil.
---@field public globstar   boolean @ defaults to global GLOBSTAR when defined, true otherwise
---@field public nocaseglob boolean
---@field public extglob    boolean @ defaults to global GLOBEXT
---@field public verbose    integer @ default to 0, the bigger the more verbose

--[===[
A colon-separated list of patterns defining
the set of filenames to be ignored by pathname expansion.
If a filename matched by a pathname expansion pattern
also matches one of the patterns in GLOBIGNORE,
it is removed from the list of matches.
--]===]
---@global GLOBIGNORE
_G.GLOBIGNORE = nil

---comment
--[==[
After word splitting, unless the -f option has been set,
bash scans each word for the characters *, ?, and [.
If one of these characters appears,
then the word is regarded as a pattern,
and replaced with an alphabetically sorted list of file names matching the pattern.
If no matching file names are found,
and the shell option nullglob is not enabled,
the word is left unchanged.
If the nullglob option is set,
and no matches are found, the word is removed.
If the failglob shell option is set,
and no matches are found,
an error message is printed and the command is not executed.
If the shell option nocaseglob is enabled,
the match is performed without regard to the case of alphabetic characters.


When matching a pathname,
the slash character must always be matched explicitly.
In other cases, the ''.'' character is not treated specially.
See the description of shopt below under SHELL BUILTIN COMMANDS for a description of the
nocaseglob, nullglob, failglob, and dotglob shell options.

The GLOBIGNORE shell variable may be used to restrict the set of file names matching a pattern. If GLOBIGNORE is set, each matching file name that also matches one of the patterns in GLOBIGNORE is removed from the list of matches. The file names ''.'' and ''..'' are always ignored when GLOBIGNORE is set and not null. However, setting GLOBIGNORE to a non-null value has the effect of enabling the dotglob shell option, so all other file names beginning with a ''.'' will match. To get the old behavior of ignoring file names beginning with a ''.'', make ''.*'' one of the patterns in GLOBIGNORE. The dotglob option is disabled when GLOBIGNORE is unset.


Pattern Matching

Any character that appears in a pattern,
other than the special pattern characters described below,
matches itself.

The NUL character may not occur in a pattern.
A backslash escapes the following character;
the escaping backslash is discarded when matching.

The special pattern characters must be quoted if they are to be matched literally.

The special pattern characters have the following meanings:

*
Matches any string, including the null string.
When the globstar shell option is enabled,
and * is used in a pathname expansion context,
two adjacent *s used as a single pattern will match all files and zero or more directories and subdirectories.
If followed by a /, two adjacent *s will match only directories and subdirectories.

?
Matches any single character.

[...]
Matches any one of the enclosed characters.
A pair of characters separated by a hyphen denotes a range expression;
any character that sorts between those two characters,
inclusive, using the current locale's collating sequence and character set, is matched.
If the first character following the [ is a ! or a ^ then any character not enclosed is matched.
The sorting order of characters in range expressions is determined by the current locale
and the value of the LC_COLLATE shell variable, if set.
A - may be matched by including it as the first or last character in the set.
A ] may be matched by including it as the first character in the set.

Within [ and ], character classes can be specified using the syntax [:class:],
where class is one of the following classes defined in the POSIX standard:
alnum alpha ascii blank cntrl digit graph lower print punct space upper word xdigit.
A character class matches any character belonging to that class.
The word character class matches letters, digits, and the character _.
Within [ and ], an equivalence class can be specified using the syntax [=c=], which matches all characters with the same collation weight (as defined by the current locale) as the character c.

Within [ and ], the syntax [.symbol.] matches the collating symbol symbol.

If the extglob shell option is enabled using the shopt builtin,
several extended pattern matching operators are recognized.
In the following description, a pattern-list is a list of one or more patterns separated by a |.
Composite patterns may be formed using one or more of the following sub-patterns:
?(pattern-list)
Matches zero or one occurrence of the given patterns

*(pattern-list)
Matches zero or more occurrences of the given patterns

+(pattern-list)
Matches one or more occurrences of the given patterns

@(pattern-list)
Matches one of the given patterns

!(pattern-list)
Matches anything except one of the given patterns

Quote Removal

After the preceding expansions, all unquoted occurrences of the characters \, ', and " that did not result from one of the above expansions are removed.
--]==]

-- we normalize path separators, just in case
---@type lpeg_t
local path_sep_p = P("/")^1 * ( P(".") * P("/")^1 )^0
-- a path character is anything but a path separator
---@type lpeg_t
local path_char_p = utf8_p - "/"
-- a path component is a non void list of path characters
---@type lpeg_t
local path_comp_p = path_char_p^1
-- in default mode (not dotglob), the leading dot is special
---@type lpeg_t
local path_char_no_dot_p = path_char_p - P(".")
---@type lpeg_t
local no_dot_p = utf8_p - P(".")
-- whether we are at the beginning of a path component
---@type lpeg_t
local is_leading_p = -B(1) + B("/") -- first character or following a "/"
-- in default mode, match any character in a path component
---@type lpeg_t
local path_char_no_dotglob_p =
      is_leading_p * path_char_no_dot_p
  + - is_leading_p * path_char_p
---@type lpeg_t
local path_comp_no_dotglob_p =
  path_char_no_dotglob_p * path_char_p^0

---@type lpeg_t
-- catch an ending "/."
local end_p =
  ( path_sep_p^1 * P(".")^-1
  + is_leading_p * P(".")^-1
  + P(true)
  ) * P(-1)

  ---@param opts path_matcher_opts_t
local function get_path_grammar(opts)
  opts = bridge({
    primary = opts or {},
    secondary = {
      globstar  = _G.GLOBSTAR == nil or _G.GLOBSTAR and true or false,
      dotglob   = _G.GLOBIGNORE ~= nil,
      extglob   = _G.GLOBEXT ~= nil and _G.GLOBEXT and true or false,
      verbose   = 0,
    },
  })

  ---comment
  ---@param what string|integer
  ---@return lpeg_t
  local function raw_P(what)
    local p = P(what)
    return p
      / function ()
          if opts.verbose > 2 then
            print("matched raw_P", what)
          end
          return p
        end
  end

  local function product_folder(a, b)
    return a * b
  end

  local function sum_folder(a, b)
    return a + b
  end


  local function verbose_p(p, verbose, msg)
    if opts.verbose > verbose then
      return p * Cmt(
        P(true),
        function (_, i)
          print(msg)
          return i
        end
      )
    else
      return p
    end
  end

  -- define the grammar then define the peg pattern,
  -- this grammar is recursive in extended mode.
  
  -- The glob is parsed as a sequence of patterns.
  -- These patterns are themselves converted to other patterns
  -- The resulting sequence is then folded into a product of lpeg patterns
  local G = {}

  -- the main rule
  G[1] =
    Cf(
      V("content"),
      product_folder
    )
  G["content"] = V("pattern")^1 * V("$")
  -- A pattern is an alteration, the key is self explanatory
  G["pattern"] =
          V("extglob")  -- extended patterns are defined below
        + V("..")       -- prevent parent reference
        + V("?")        -- wildcard patterns are defined below
        + V("/**/")
        + V("**")
        + V("*")
        + V("/")        -- smart path separator
        + V("[...]")    -- character classes
        + V("1 path char")   -- consume 1 raw utf8 char
        + V("forbidden /")
  -- anchor at the end of the string
  -- (path_sep_p^1 * P(".")^-1 * P(-1) + leading_p) * P(".")
  G["$"] = verbose_p(
    raw_P( end_p ),
    3,
    "matched $"
  )
  -- extension
  if opts.extglob then
    local function get_p(switch, f)
      return
          P(switch)
        * P("(")
        * V("pattern-list")
        * P(")")
      / (f or 1)
    end
    G["extglob"] = (
        get_p(
          "?",
          function (p)
            return verbose_p(
              p^-1,
              3,
              "matched ?(...)"
            )
          end
        )
      + get_p(
          "*",
          function (p)
            return verbose_p(
              p^0,
              3,
              "matched *(...)"
            )
          end
        )
      + get_p(
          "+",
          function (p)
            return verbose_p(
              p^1,
              3,
              "matched +(...)"
            )
          end
        )
      + get_p(
        "@",
        function (p)
          return verbose_p(
            p,
            3,
            "matched +(...)"
          )
        end
      )
      + get_p(
        "!",
        function (p)
          return verbose_p(
            path_char_p - p,
            3,
            "matched +(...)"
          )
        end
      )
    )
    G["pattern-list"] =
      Cf(
        V("pattern") * ( '|' * V("pattern") )^0,
        sum_folder
      )
  else
    G["extglob"] = P(false)
  end
  G[".."] =
      is_leading_p
    * ( P("..") * ( path_sep_p + P(-1) ) )^1
    / function ()
        error("No parent reference in glob")
      end
  G["/"] =
      path_sep_p
    / function ()
        return verbose_p(
          path_sep_p,
          3,
          "matched /"
        )
    end
  G["forbidden /"] =
    P("/")
  / function ()
      error("/ forbidden in glob set")
  end
-- the wildcards may treat the leading . in a special way
  if opts.dotglob then
    G["?"] =
      P("?")
    / function ()
        return verbose_p(
          path_char_p,
          3,
          "matched: ? (dotglob)"
        )
      end
    if opts.globstar then
      G["/**/"] =
          path_sep_p
        * P("*")^2
        * path_sep_p
        / function ()
            return verbose_p(
              path_sep_p * ( path_comp_p * path_sep_p )^0,
              3,
              "matched: /**/ (dotglob, globstar)"
            )
          end
      G["**"] =
            P("*")^2
          / function ()
              return verbose_p(
                utf8_p^0,
                3,
                "matched: ** (dotglob, globstar)"
              )
            end
    else
      G["/**/"] = P(false) -- never match, fallback to "*" rule below
      G["**"]   = P(false) -- never match, fallback to "*" rule below
    end
    G["*"] =
        P("*")^1
      / function ()
          return verbose_p(
            path_char_p^0,
            3,
            "matched: * (dotglob)"
          )
        end
  else
    -- default mode: the first dot must be matched explicitly
    G["?"] =
        P("?")
      / function ()
          return verbose_p(
            path_char_no_dotglob_p,
            3,
            "matched ? (no dotglob)")
        -- catch 1 char but . or /
        end
    -- The ** may be special as well
    if opts.globstar then
      G["/**/"] = -- catched here because only one "/" is accepted
          path_sep_p
        * P("*")^2
        * path_sep_p
        / function ()
            return verbose_p(
                path_sep_p
              * ( path_comp_no_dotglob_p
                  * path_sep_p
              )^0,
              3,
              "matched /**/ (no dotglob, globstar)"
            )
          end
      G["**"] =
        P("*")^2
        / function ()
            return verbose_p(
              (
                    is_leading_p * no_dot_p
                + - is_leading_p * utf8_p  -- catch 1 char but . or /
              )^0,
              3,
              "matched: ** (no dotglob, globstar)"
            )
          end
    else
      G["/**/"] = P(false) -- never match, fallback to "**" rule
      G["**"]   = P(false) -- never match, fallback to "**" rule
    end
    G["*"] =
        P("*")^1
      / function ()
          return verbose_p(
            path_comp_no_dotglob_p^-1,
            3,
            "matched: * (no dotglob)"
          )
        end
  end
  -- Parsing sets
  G["[...]"] =
      P("[")
    * ( S("^!") -- negated set
      / function ()
          return verbose_p(
            P(true),
            3,
            "matched ^!"
          )
        end
      * V("set")
      / function (p)
          return
            path_char_p - p
          end
      + V("set")
    )
    * ( P("]")
      + Cmt(
        P(-1),
        function (_, i)
          print("Missing closing ]", _, i)
        end
      )
    )
  G["set"] = Cf(
      V("1st element")
    * V("element")^0
    -- A - may be matched by including it as the last character in the set.
    * V("last element")^-1
    + V("element")^1
    -- A - may be matched by including it as the last character in the set.
    * V("last element")^-1,
    sum_folder
  )
  -- A - may be matched by including it as the first character in the set.
  -- A ] may be matched by including it as the first character in the set
  G["1st element"]  = V(".-.") + V("-")       + V("]")
  G["element"]      = V(".-.") + V("[:...:]") + V("1 path char") - P("]")
  G["last element"] = V("-")   + V("^")       + V("!")
  G["-"]    = raw_P("-")
  G["]"]    = raw_P("]")
  G["^"]    = raw_P("^")
  G["!"]    = raw_P("!")
  G[".-."]  =
        C(path_char_p)
      * P("-")
      * C(path_char_p)
      / function (l, r)
         local l_code = codepoint(l)
          local r_code = codepoint(r)
          return Cmt(
            utf8_p,
            function (_, i, u)
              if u ~= "/" then
                local u_code = codepoint(u)
                if l_code <= u_code and u_code <= r_code then
                  if opts.verbose > 3 then
                    print("matched ".. l .."-".. r)
                  end
                  return i
                end
              end
            end
          )
        end
  G["1 path char"]  =
      path_char_p
    / function (u)
        if opts.verbose > 2 then
          print("static match:", u)      
        end
        return P(u)
      end
  -- classes
  -- All the POSIX classes are implemented
  -- However, the implementation is sometimes rough
  G["[:...:]"] =
      V("[:ascii:]")
    + V("[:blank:]")
    + V("[:print:]")
    + V("[:graph:]")
    + V("[:word:]")
    + P("[:")
    -- sln classes https://github.com/LuaDist/slnunicode/blob/e8abd35c5f0f5a9084442d8665cbc9c3d169b5fd/unitest#L38
    --	%a L* (Lu+Ll+Lt+Lm+Lo)
    --	%c Cc
    --	%d 0-9
    --	%l Ll
    --	%n N* (Nd+Nl+No, new)
    --	%p P* (Pc+Pd+Ps+Pe+Pi+Pf+Po)
    --	%s Z* (Zs+Zl+Zp) plus the controls 9-13 (HT,LF,VT,FF,CR)
    --	%u Lu (also Lt ?)
    --	%w %a+%n+Pc (e.g. '_')
    --	%x 0-9A-Za-z -- JL: ERROR!!! 0-9A-Fa-f
    --	%z the 0 byte

    * Cg(
        C("alnum")  * Cc("w") -- alphanumeric characters without _
      + C("alpha")  * Cc("a") -- letters
      + C("cntrl")  * Cc("c") -- control characters
      + C("digit")  * Cc("d") -- digits
      + C("lower")  * Cc("l") -- lowercase letters
      + C("punct")  * Cc("p") -- punctuation characters
      + C("space")  * Cc("s") -- space characters
      + C("upper")  * Cc("u") -- uppercase letters
      + C("xdigit") * Cc("x") -- hexadecimal digits
    )
    / function (x, y)
        return verbose_p(
          Cmt(
            C(utf8_p),
            function (_, i, u)
              if sln_utf8.match(u, "^%".. y) then
                if opts.verbose > 3 then
                  print("u", u)
                end
                return i
              end
            end
          ),
          3,
          "matched [:".. x ..":]"
        )
      end
    * P(":]")
  G["[:blank:]"] =
    P("[:blank:]")
  / function ()
      return verbose_p(
        S("\t "),
        3,
        "matched [:blank:]"
      )
    end
  G["[:cntrl:]"] =
    P("[:cntrl:]")
    / function ()
      return verbose_p(
        Cmt(
          C(utf8_p),
          function (_, i, u)
            if sln_utf8.match(u, "^%c") then
              if opts.verbose > 0 then
                print("u", u)
              end
              return i
            end
          end
        ),
        3,
        "matched [:cntrl:]"
      )
    end
  G["[:ascii:]"] =
      P("[:ascii:]")
    / function ()
        return verbose_p(
          Cmt(
            C(utf8_p),
            function (_, i, u)
              if codepoint(u) <= 0x7F then
                return i
              end
            end
          ),
          3,
          "matched [:ascii:]"
        )
      end
  G["[:print:]"] =
      P("[:print:]")
    / function ()
        return verbose_p(
          Cmt(
            C(utf8_p),
            function (_, i, u)
              if codepoint(u) >= 0x20 then
                return i
              end
            end
          ),
          3,
          "matched [:print:]"
        )
      end
  G["[:graph:]"] =
      P("[:graph:]")
    / function ()
        return verbose_p(
          Cmt(
            C(utf8_p),
            function (_, i, u)
              if codepoint(u) > 0x20 then
                return i
              end
            end
          ),
          3,
          "matched [:graph:]"
        )
      end
  G["[:word:]"] =
      P("[:word:]")
    / function ()
        return verbose_p(
          Cmt(
            C(utf8_p),
            function (_, i, u)
              if u == "_" or sln_utf8.match(u, "%w") then
                return i
              end
            end
          ),
          3,
          "matched [:word:]"
        )
      end
  return G
end

---Path matcher
---@param glob string
---@param opts path_matcher_opts_t
---@return function?
---@usage local accept = path_matcher(...); if accept(...) then ... end
local function path_matcher(glob, opts)
  if glob then
    local G = get_path_grammar(opts)
    local pattern = P(G):match(glob)
    if pattern then
      return function (str)
        if opts and opts.verbose and opts.verbose > 4 then
          print("path_matcher", str, pattern:match(str))
        end
        return pattern:match(str) ~= nil
      end
    end
  end
end

---@alias glob_match_f fun(name: string): boolean

---@class lpeglib_t
---@field public path_matcher           fun(glob: string): glob_match_f
---@field public white_p                lpeg_t
---@field public black_p                lpeg_t
---@field public eol_p                  lpeg_t
---@field public alt_ascii_p            lpeg_t
---@field public alt_utf8_p             lpeg_t
---@field public consume_1_character_p  lpeg_t
---@field public get_spaced_p           fun(p: lpeg_t): lpeg_t
---@field public spaced_colon_p         lpeg_t
---@field public spaced_comma_p         lpeg_t
---@field public variable_p             lpeg_t
---@field public identifier_p           lpeg_t
---@field public function_name_p        lpeg_t

return {
  path_matcher          = path_matcher,
  white_p               = white_p,
  black_p               = black_p,
  eol_p                 = eol_p,
  ascii_p               = ascii_p,
  utf8_p                = utf8_p,
  alt_ascii_p           = alt_ascii_p,
  alt_utf8_p            = alt_utf8_p,
  get_spaced_p          = get_spaced_p,
  spaced_colon_p        = spaced_colon_p,
  spaced_comma_p        = spaced_comma_p,
  consume_1_character_p = consume_1_character_p,
  variable_p            = variable_p,
  identifier_p          = identifier_p,
  function_name_p       = function_name_p,
  -- next are implementation details
  -- these are exported for testing purposes only
  __get_path_grammar        = get_path_grammar,
  __path_sep_p              = path_sep_p,
  __path_char_p             = path_char_p,
  __path_comp_p             = path_comp_p,
  __path_char_no_dot_p      = path_char_no_dot_p,
  __is_leading_p            = is_leading_p,
  __no_dot_p                = no_dot_p,
  __path_char_no_dotglob_p  = path_char_no_dotglob_p,
  __path_comp_no_dotglob_p  = path_comp_no_dotglob_p,
  __end_p                   = end_p,
}
