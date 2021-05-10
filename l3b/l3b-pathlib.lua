--[[

File l3b-pathlib.lua Copyright (C) 2018-2020 The LaTeX Project

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

---Path utilities
--[===[
This module implements path facilities over strings.
It only depends on the  `object` module.

# Forbidden characters in file paths

From [micrososft documentation](https://docs.microsoft.com/en-us/windows/win32/fileio/naming-a-file)

* < (less than)
* > (greater than)
* : (colon)
* " (double quote)
* / (forward slash)
* \ (backslash)
* | (vertical bar or pipe)
* ? (question mark)
* * (asterisk)

---]===]
---@module pathlib

-- Safeguards and shortcuts

local push      = table.insert
local pop       = table.remove
local concat    = table.concat
local move      = table.move
local max       = math.max

local codepoint = utf8.codepoint

local unicode   = require("unicode")
local sln_utf8  = unicode.utf8

local lpeg    = require("lpeg")
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
local Ct    = lpeg.Ct

local Object = require("l3b-object")

---@type corelib_t
local corelib = require("l3b-corelib")
local bridge  = corelib.bridge

---@type lpeglib_t
local lpeglib = require("l3b-lpeglib")
local utf8_p = lpeglib.utf8_p

--[=[ Package implementation ]=]

---Split the given string according to the given separator
---@param str string
---@param sep string | lpeg_t | nil @ 
local function split(str, sep)
  if sep == "" then
    return Ct(C(utf8_p)^0):match(str)
  end
  local p = P(sep)
  local q = 1-p
  local r =
    ( C(q^0) * p )^1
    * C(q^0)
    + C(q^1)
  return Ct(r):match(str) or { str }
end

local dot_p = P(".")
---@type lpeg_t
local no_dot_p = utf8_p - dot_p

if not string.get_base_extension then
  local base_extension_p = Ct(
      C( no_dot_p^0) * ( dot_p * C( no_dot_p^0 ) )^0
    ) / function (t)
      local last = max(1, #t - 1) -- last index of the base part
      return {
        base = concat({ unpack(t, 1, last) }, "."),
        extension = unpack(t, last + 1, #t) or "",
      }
    end

  string.get_base_extension = function (self)
    return base_extension_p:match(self)
  end
end


-- The Path objects are implementation details
-- private to this module
---@class Path: Object
---@field public up           string[]
---@field public down         string[]
---@field public is_absolute  boolean
---@field public is_void      boolean
---@field public as_string    string
---@field public copy         fun(self: Path): Path
---@field public append_component fun(self: Path, component: string)

local Path = Object:make_subclass("Path")

---comment
---@param self Path
---@param component string
function Path:append_component(component)
  if component == ".." then
    if not pop(self.down) then
      push(self.up, component)
    end
  else
    if self.down[#self.down] == "" then
      pop(self.down)
    end
    push(self.down, component)
  end
end

local path_p = P({
    V("is_absolute")
  * ( V("component")
    * ( V("separator")
      * V("component") -- expect the ending dot
    )^0
    + P(0)
  )
  * V("suffix"),
  is_absolute =
      P("/")^1  * Cc(true)    -- leading '/', true means absolute
    + P("./")^0 * Cc(false),  -- leading './'
  component = C( ( P(1) - "/" )^1 ) - dot_p * P(-1), -- a non void string with no "/" but the last "." component if any
  separator = ( P("/") * P("./")^0 )^1,
  suffix = ( P("/")^1 * Cc("") + dot_p )^-1,
})

---Initialize a newly created Path object with a given string.
---@param str any
function Path:__initialize(str)
  self.is_absolute  = self.is_absolute or false
  self.up           = self.up or {}   -- ".." path components
  self.down         = self.down or {} -- down components
  if not str then
    return
  end
  local m = Ct(path_p):match(str)
  if not m then
    return
  end
  self.is_absolute  = m[1]
  for i = 2, #m do
    self:append_component(m[i])
  end
  assert(not self.is_absolute or #self.up == 0, "Unexpected path ".. str )
end

function Path:__tostring()
  return self.as_string
end

function Path.__instance_table:is_void()
  return #self.up + #self.down == 0
end

function Path.__instance_table:extension()
  return self.base_name:match("%.([^%.])$")
end

function Path.__instance_table:as_string()
  local result
  if self.is_absolute then
    result = '/' .. concat(self.down, '/')
  else
    local t = {}
    if #self.up > 0 then
      move(self.up, 1, #self.up, 1, t)
    else
      t[1] = "."
    end
    move(self.down, 1, #self.down, #t + 1, t)
    result = concat(t, '/')
  end
  self.as_string = result -- now this is a property of self
  return result
end

function Path.__instance_table:base_name()
  local result =
        self.down[#self.down]
    or  self.up[#self.up]
    or ""
  self.base_name = result
  return result
end

function Path.__instance_table:core_name()
  local result = self.base_name
  result = result:match("^(.*)%.") or result
  self.core_name = result
  return result
end

function Path.__instance_table:dir_name()
  local function no_tail(t)
    return #t>0 and { unpack(t, 1, #t - 1) } or nil
  end
  local down = no_tail(self.down)
  local up = down and self.up or no_tail(self.up)
  local result
  if self.is_absolute then
    result = '/' .. concat(down, '/')
  elseif down then
    local t = { unpack(up or {}) }
    move(down, 1, #down, #t + 1, t)
    result = concat(t, "/")
  elseif up then
    result = concat( up, "/")
  else
    result = "."
  end
  if result == "" then
    result = "."
  end
  self.dir_name = result
  return result
end

function Path:copy()
  return Path(self.as_string)
end

---Concatenate paths.
---@param self Path
---@param r Path
---@return Path
function Path:__div(r)
  assert(
    not r.is_absolute or self.is_void,
    "Unable to merge with an absolute path ".. r.as_string
  )
  if self.is_void then
    ---@type Path
    local result = r:copy()
    if self.is_absolute or r.is_void then
      result.is_absolute = true
    end
    return result
  end
  if r.is_void then
    ---@type Path
    local result = self:copy()
    if result.down[#result.down] ~= "" then
      push(result.down, "")
    end
    return result
  end
  ---@type Path
  local result = self:copy()
  for i = 1, #r.up do
    result:append_component(r.up[i])
  end
  for i = 1, #r.down do
    result:append_component(r.down[i])
  end
  assert(not result.is_absolute or #result.up == 0)
  return result
end

---Split the given string into its path components
---@function path_components
---@param str string
local path_properties = setmetatable({}, {
  __mode = "k",
  __call = function (self, k)
    local result = self[k]
    if result then
      return result
    end
    result = Path(k)
    self[k] = result
    local normalized = result.as_string
    if k ~= normalized then
      self[normalized] = result
    end
    return result
  end,
})

do
  -- implement the / operator for string as path merger
  local string_MT = getmetatable("")

  function string_MT.__div(a, b)
    local path_a = path_properties(a)
    local path_b = path_properties(b)
    local result = path_a / path_b
    local normalized = result.as_string
    path_properties[normalized] = result
    return normalized
  end

end

---Split a path into its base and directory components.
---The base part includes the file extension if any.
---The dir part does not contain the trailing '/'.
---@param path string
---@return string @dir is the part before the last '/' if any, "." otherwise.
---@return string
local function dir_base(path)
  local p = path_properties(path)
  return p.dir_name, p.base_name
end

---Arguably clearer names
---@param path string
---@return string
local function base_name(path)
  return path_properties(path).base_name
end

---Arguably clearer names
---@param path string
---@return string
local function dir_name(path)
  return path_properties(path).dir_name
end

---Strip the extension from a file name (if present)
---@param file string
---@return string
local function core_name(file)
  return path_properties(file).core_name
end

---Return the extension, may be nil.
---@param path string
---@return string | nil
local function extension(path)
  return path_properties(path).extension
end

---Sanitize the path by removing unecessary parts.
---@param path string
---@param is_glob boolean|nil
---@return string | nil
local function sanitize(path, is_glob)
  local result = path_properties(path).as_string
  return is_glob and result:match("^%./(.+)$") or result
end

--- Convert a file glob into a pattern for use by e.g. string.gub
local function get_glob_to_pattern_gmr()
  return {
    Cs( Cc('^') * V("item")^0 * Cc('$') ),
    item = Cg(
        V('?')
      + V('*')
      + V('\\')
    )
    + V('[...]')
    + V('%'),
    ['?']   = P('?') * Cc('.'),
    ['*']   = P('*') * Cc('.*'), -- should be '[^/]*'
    ['\\']  = P('\\') * ( P(-1) + V('%') ),
    ['[...]']   = C('[') * C('^')^-1 * (
        V("set") * C(']')
      + P(0) / function () error("Missing ']' in glob.") end
    ),
    set = V('head') * V('tail')^0 * V("-")^-1,
    ["-"] = Cc('%') * P('-'),
    head = V('.-.') + V('%'),
    tail = V(".-.") + ( V('%') - P("-") - P("]") ),
    ['.-.'] = Cs( V('%') * C("-") * ( V('%') - P("]") ) ),
    ["%"] = Cs( Cc('%') * S('^$()%.[]*+-?') + P(1) ),
  }
end

local glob_to_pattern_p = P(get_glob_to_pattern_gmr())

local function glob_to_pattern(glob)
  return glob_to_pattern_p:match(glob)
end

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
local path_sep_p = P("/")^1 * ( dot_p * P("/")^1 )^0
-- a path character is anything but a path separator
---@type lpeg_t
local path_char_p = utf8_p - "/"
-- a path component is a non void list of path characters
---@type lpeg_t
local path_comp_p = path_char_p^1
-- in default mode (not dotglob), the leading dot is special
---@type lpeg_t
local path_char_no_dot_p = path_char_p - dot_p
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
  ( path_sep_p^1 * dot_p^-1
  + is_leading_p * dot_p^-1
  + P(true)
  ) * P(-1)

  ---@param opts path_matcher_opts_t
local function get_path_gmr(opts)
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

  local function product_folder(a, b)
    if a.star then
      if b.star then
        return a
      end
      local result = P({
        verbose_p(
          b + a.star * V(1),
          3,
          a.msg
        )
      })
      return a.before and a.before * result or result
    end
    if b.star then
      b.before = a
      return b
    end
    return a * b
  end

  local function sum_folder(a, b)
    return a + b
  end

  -- define the grammar then define the peg pattern,
  -- this grammar is recursive in extended mode.
  
  -- The glob is parsed as a sequence of patterns.
  -- These patterns are themselves converted to other patterns
  -- The resulting sequence is then folded into a product of lpeg patterns
  local gmr = {}

  -- the main rule
  gmr[1] =
    Cf(
      V("content"),
      product_folder
    )
  gmr["content"] = V("pattern")^1 * V("$")
  -- A pattern is an alteration, the key is self explanatory
  gmr["pattern"] =
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
  -- (path_sep_p^1 * dot_p^-1 * P(-1) + leading_p) * dot_p
  gmr["$"] = verbose_p(
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
    gmr["extglob"] = (
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
    gmr["pattern-list"] =
      Cf(
        V("pattern") * ( '|' * V("pattern") )^0,
        sum_folder
      )
  else
    gmr["extglob"] = P(false)
  end
  gmr[".."] =
      is_leading_p
    * ( P("..") * ( path_sep_p + P(-1) ) )^1
    / function ()
        error("No parent reference in glob")
      end
  gmr["/"] =
      path_sep_p
    / function ()
        return verbose_p(
          path_sep_p,
          3,
          "matched /"
        )
    end
  gmr["forbidden /"] =
    P("/")
  / function ()
      error("/ forbidden in glob set")
  end
-- the wildcards may treat the leading . in a special way
  if opts.dotglob then
    gmr["?"] =
      P("?")
    / function ()
        return verbose_p(
          path_char_p,
          3,
          "matched: ? (dotglob)"
        )
      end
    if opts.globstar then
      gmr["/**/"] =
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
      gmr["**"] =
            P("*")^2
          / function ()
              return verbose_p(
                utf8_p^0,
                3,
                "matched: ** (dotglob, globstar)"
              )
            end
    else
      gmr["/**/"] = P(false) -- never match, fallback to "*" rule below
      gmr["**"]   = P(false) -- never match, fallback to "*" rule below
    end
    gmr["*"] =
        P("*")^1
      / function ()
          return {
            star = path_char_p,
            msg = "matched: * (dotglob)",
          }
        end
  else
    -- default mode: the first dot must be matched explicitly
    gmr["?"] =
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
      gmr["/**/"] = -- catched here because only one "/" is accepted
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
      gmr["**"] =
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
      gmr["/**/"] = P(false) -- never match, fallback to "**" rule
      gmr["**"]   = P(false) -- never match, fallback to "**" rule
    end
    gmr["*"] =
        P("*")^1
      / function ()
          return {
            star = path_char_no_dotglob_p,
            msg = "matched: * (no dotglob)",
          }
        end
  end
  -- Parsing sets
  gmr["[...]"] =
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
  gmr["set"] = Cf(
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
  gmr["1st element"]  = V(".-.") + V("-")       + V("]")
  gmr["element"]      = V(".-.") + V("[:...:]") + V("1 path char") - P("]")
  gmr["last element"] = V("-")   + V("^")       + V("!")
  gmr["-"]    = raw_P("-")
  gmr["]"]    = raw_P("]")
  gmr["^"]    = raw_P("^")
  gmr["!"]    = raw_P("!")
  gmr[".-."]  =
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
  gmr["1 path char"]  =
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
  gmr["[:...:]"] =
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
  gmr["[:blank:]"] =
    P("[:blank:]")
  / function ()
      return verbose_p(
        S("\t "),
        3,
        "matched [:blank:]"
      )
    end
  gmr["[:cntrl:]"] =
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
  gmr["[:ascii:]"] =
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
  gmr["[:print:]"] =
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
  gmr["[:graph:]"] =
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
  gmr["[:word:]"] =
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
  return gmr
end

---Path matcher
---@param glob string
---@param opts path_matcher_opts_t
---@return function?
---@usage local accept = path_matcher(...); if accept(...) then ... end
local function path_matcher(glob, opts)
  if glob then
    local gmr = get_path_gmr(opts)
    local pattern = P(gmr):match(glob)
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

---@class pathlib_t
---@field public split        fun(str: string, sep: string|lpeg_t|nil): string[]
---@field public dir_base     fun(path: string): string, string
---@field public dir_name     fun(path: string): string
---@field public base_name    fun(path: string): string
---@field public job_name     fun(path: string): string
---@field public core_name    fun(path: string): string
---@field public extension    fun(path: string): string
---@field public path_matcher fun(glob: string): glob_match_f

return {
  split           = split,
  dir_base        = dir_base,
  dir_name        = dir_name,
  base_name       = base_name,
  core_name       = core_name,
  extension       = extension,
  job_name        = core_name,
  sanitize        = sanitize,
  glob_to_pattern = glob_to_pattern,
  path_matcher    = path_matcher,
},
---@class __pathlib_t
---@field private Path                    Path
---@field private get_path_gmr            fun(opts: path_matcher_opts_t): table<string|integer,lpeg_t>
---@field private path_sep_p              lpeg_t
---@field private path_char_p             lpeg_t
---@field private path_comp_p             lpeg_t
---@field private path_char_no_dot_p      lpeg_t
---@field private is_leading_p            lpeg_t
---@field private no_dot_p                lpeg_t
---@field private path_char_no_dotglob_p  lpeg_t
---@field private path_comp_no_dotglob_p  lpeg_t
---@field private end_p                   lpeg_t
---@field private get_glob_to_pattern_gmr fun(): table<string|integer,lpeg_t>
_ENV.during_unit_testing and {
  -- next are implementation details
  -- these are exported for testing purposes only
  Path                    = Path,
  get_path_gmr            = get_path_gmr,
  path_sep_p              = path_sep_p,
  path_char_p             = path_char_p,
  path_comp_p             = path_comp_p,
  path_char_no_dot_p      = path_char_no_dot_p,
  is_leading_p            = is_leading_p,
  no_dot_p                = no_dot_p,
  path_char_no_dotglob_p  = path_char_no_dotglob_p,
  path_comp_no_dotglob_p  = path_comp_no_dotglob_p,
  end_p                   = end_p,
  get_glob_to_pattern_gmr = get_glob_to_pattern_gmr,
}
