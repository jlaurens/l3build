local append = table.insert

local unicode   = require("unicode")
local sln_utf8  = unicode.utf8

local expect  = _ENV.expect

local lpeg  = require("lpeg")
local P     = lpeg.P
local B     = lpeg.B
local V     = lpeg.V
local Cmt   = lpeg.Cmt
local C     = lpeg.C
local Cg    = lpeg.Cg
local Cc    = lpeg.Cc

---@type lpeglib_t
local lpeglib = require("l3b-lpeglib")

---Utf8 character sample iterator
---@param factor number @ 0 for 1 by 1, > 1 for exponential steps 
---@param i integer
---@return fun(): string
local function get_utf8_sample(factor, i)
  i = i or 32
  factor = factor or 1.01
  local di = 1
  return factor > 0
    and function ()
          local j = i + di - 1
          local code = math.random(i, j)
          i = j + 1
          di = math.max(math.floor(factor * di), di + 1)
          if code < 65536 then
            return utf8.char(code)
          end
        end
    or  function ()
          local code = i
          if code < 65536 then
            i = i + 1
            return utf8.char(code)
          end
        end
end

local function test_base()
  expect(lpeglib).NOT(nil)
end

local test_lpeg = {
  test_white_p = function(self)
    ---@type lpeg_t
    local p = lpeglib.white_p
    expect(p).NOT(nil)
    expect(p:match("")).is(nil)
    expect(p:match("a")).is(nil)
    expect(p:match(" ")).is(2)
    expect(p:match("\t")).is(2)
  end,
  test_black_p = function(self)
    ---@type lpeg_t
    local p = lpeglib.black_p
    expect(p).NOT(nil)
    expect(p:match("")).is(nil)
    expect(p:match("a")).is(2)
    expect(p:match(" ")).is(nil)
    expect(p:match("\t")).is(nil)
  end,
  test_eol_p = function(self)
    ---@type lpeg_t
    local p = lpeglib.eol_p
    expect(p).NOT(nil)
    expect(p:match("")).is(1)
    expect(p:match("a")).is(1)
    expect(p:match("\n")).is(2)
    expect(p:match("\n\n")).is(2)
  end,
  test_alt_ascii_p = function(self)
    ---@type lpeg_t
    local p = lpeglib.alt_ascii_p
    expect(p).NOT(nil)
    expect(p:match("")).is(nil)
    expect(p:match("a")).is(2)
    expect(p:match("\129")).is(nil)
    expect(p:match("\n")).is(nil)
  end,
  test_alt_utf8_p = function(self)
    ---@type lpeg_t
    local p = lpeglib.alt_utf8_p
    expect(p).NOT(nil)
    expect(p:match("\019")).is(2)
    expect(p:match("\xC2\xA9")).is(3)
    expect(p:match("\xE2\x88\x92")).is(4)
    expect(p:match("\xF0\x9D\x90\x80")).is(5)
    expect(p:match("a-z")).is(2)
  end,
  test_get_spaced_p = function(self)
    ---@type lpeg_t
    local p = lpeglib.get_spaced_p
    expect(p).NOT(nil)
    expect(p("abc"):match("abc")).is(4)
    expect(p("abc"):match("   abc")).is(7)
    expect(p("abc"):match("abc   ")).is(7)
    expect(p("abc"):match("   abc   ")).is(10)
  end,
  test_spaced_colon_p = function(self)
    ---@type lpeg_t
    local p = lpeglib.spaced_colon_p
    expect(p).NOT(nil)
    expect(p:match(":")).is(2)
    expect(p:match("  :")).is(4)
    expect(p:match(":  ")).is(4)
    expect(p:match("  :  ")).is(6)
    expect(p:match("  :  abc")).is(6)
  end,
  test_spaced_comma_p = function(self)
    ---@type lpeg_t
    local p = lpeglib.spaced_comma_p
    expect(p).NOT(nil)
    expect(p:match(',')).is(2)
    expect(p:match("  ,")).is(4)
    expect(p:match(",  ")).is(4)
    expect(p:match("  ,  ")).is(6)
  end,
  test_variable_p = function(self)
    ---@type lpeg_t
    local p = lpeglib.variable_p
    expect(p).NOT(nil)
    expect(p:match("abc foo")).is(4)
    expect(p:match("abc123 foo")).is(7)
    expect(p:match("abc123_ foo")).is(8)
    expect(p:match("0bc123_ foo")).is(nil)
  end,
  test_identifier_p = function(self)
    ---@type lpeg_t
    local p = lpeglib.identifier_p
    expect(p).NOT(nil)
    expect(p:match("abc foo")).is(4)
    expect(p:match("abc.def foo")).is(8)
    expect(p:match(".abc.def foo")).is(nil)
  end,
  test_function_name_p = function(self)
    ---@type lpeg_t
    local p = lpeglib.function_name_p
    expect(p).NOT(nil)
    expect(p:match("abc foo")).is(4)
    expect(p:match("abc.def foo")).is(8)
    expect(p:match(".abc.def foo")).is(nil)
    expect(p:match("abc foo")).is(4)
    expect(p:match("abc:def foo")).is(8)
    expect(p:match("a.c:def foo")).is(8)
    expect(p:match("a:c:def foo")).is(4)
  end,
  test_POC = function (self)
    local s = "\xF0\x9F\x98\x80"
    -- a path character is anything but a path separator
    ---@type lpeg_t
    local path_char_p = lpeglib.__path_char_p
    expect(path_char_p:match("/")).is(nil)
    expect(path_char_p:match(s)).is(5)
    -- in default mode (not dotglob), the leading dot is special
    ---@type lpeg_t
    local path_char_no_dot_p = lpeglib.__path_char_no_dot_p
    expect(path_char_no_dot_p:match("/")).is(nil)
    expect(path_char_no_dot_p:match(".")).is(nil)
    expect(path_char_no_dot_p:match(s)).is(5)
    -- whether we are at the beginning of a path component
    ---@type lpeg_t
    local is_leading_p = lpeglib.__is_leading_p
    expect(is_leading_p:match("")).is(1)
    expect(is_leading_p:match("a", 2)).is(nil)
    expect(is_leading_p:match("/", 2)).is(2)
    -- in default mode, match any character in a path component
    ---@type lpeg_t
    local path_char_no_dotglob_p = lpeglib.__path_char_no_dotglob_p
    expect(path_char_no_dotglob_p:match("/")).is(nil)
    expect(path_char_no_dotglob_p:match("/.", 2)).is(nil)
    expect(path_char_no_dotglob_p:match(".")).is(nil)
    expect(path_char_no_dotglob_p:match(" .", 2)).is(3)
    expect(path_char_no_dotglob_p:match(s)).is(5)
    ---@type lpeg_t
    local path_comp_no_dotglob_p = lpeglib.__path_comp_no_dotglob_p
    expect(path_comp_no_dotglob_p:match("/")).is(nil)
    expect(path_comp_no_dotglob_p:match("/a", 2)).is(3)
    expect(path_comp_no_dotglob_p:match("/.", 2)).is(nil)
    expect(path_comp_no_dotglob_p:match(".")).is(nil)
    expect(path_comp_no_dotglob_p:match(" .", 2)).is(3)
    expect(path_comp_no_dotglob_p:match(s)).is(5)
    expect(path_comp_no_dotglob_p:match("/")).is(nil)
    expect(path_comp_no_dotglob_p:match("/a.", 2)).is(4)
    expect(path_comp_no_dotglob_p:match(s .. s)).is(9)
  end,
}

local test_consume_1_character_p = {
  setup = function(self)
    _G.UFT8_DECODING_ERROR = false
    self.done = nil
    _ENV.push_print(function (x)
      self.done = x
    end)
  end,
  teardown = function(self)
    _ENV.pop_print()
  end,
  test = function(self)
    ---@type lpeg_t
    local p = lpeglib.consume_1_character_p
    expect(p).NOT(nil)
    expect(p:match("a")).is(2)
    expect(p:match("\xC2")).is(nil)
    expect(_G.UFT8_DECODING_ERROR).is(true)
    expect(self.done).contains("UTF8 problem")
  end
}

local test___grammar = {
  test_1_char = function (self)
    local G = lpeglib.__get_path_grammar()
    G["content"] = G["1 path char"] * G["$"]
    ---@type lpeg_t
    local p = P(G)
    ---@type lpeg_t
    local q = p:match("a")
    expect(lpeg.type(q)).is("pattern")
    expect(q:match("a")).is(2)
    expect(q:match("aa")).is(nil)
    expect(q:match("b")).is(nil)

    G = lpeglib.__get_path_grammar({
      -- verbose = 3,
    })
    p = P(G)
    q = p:match("a")

    expect(lpeg.type(q)).is("pattern")
    expect(q:match("a")).is(2)
    expect(q:match("aa")).is(nil)
    expect(q:match("b")).is(nil)
    expect(q:match("")).is(nil)

    G = lpeglib.__get_path_grammar()
    p = P(G)
    for i = 32, 65535 do
      local s = utf8.char(i)
      q = p:match(s)
      expect(q:match(s)).is(#s + 1)
    end

    local match = lpeglib.path_matcher
    for i = 32, 65535, 32 do
      local s = utf8.char(math.random(i, i + 31))
      local yorn = match(s)(s)
      if not yorn then
        print("FAILURE", i, s)
      end
      expect(yorn).is(true)
    end

  end,
  test_end = function (self)
    local G = lpeglib.__get_path_grammar({
      -- verbose = 4,
    })
    G["content"] = V("$")
    local p = P(G)
    local q = p:match("")
    expect(q).NOT(nil)
    expect(q:match("")).is(1)
    expect(q:match(".")).is(2)
    expect(q:match("/")).is(2)
    expect(q:match("//")).is(3)
    expect(q:match("/./")).is(4)
    expect(q:match("//.")).is(4)
    expect(q:match("/./.")).is(5)
  end,
  test_class = function (self)
    -- create a test grammar for each class name
    local function get_class_P(name)
      local G = lpeglib.__get_path_grammar({
        -- verbose = 4,
      })
      local class = "[:".. name ..":]"
      G["content"] =
        ( G[class] or  G["[:...:]"] )
        * G["$"]
      local result = P(G):match(class)
      expect(result).NOT(nil)
      return result
    end
    local function get_set_P(name)
      local G = lpeglib.__get_path_grammar({
        -- verbose = 4,
      })
      local class = "[:".. name ..":]"
      G["content"] = G["set"] * G["$"]
      local result = P(G):match(class)
      expect(result).NOT(nil)
      return result
    end
    local function get_delimited_P(name)
      local G = lpeglib.__get_path_grammar({
        -- verbose = 4,
      })
      local class = "[:".. name ..":]"
      G["content"] = G["[...]"] * G["$"]
      local result = P(G):match('['.. class ..']')
      expect(result).NOT(nil)
      return result
    end
    local function get_P(name)
      local G = lpeglib.__get_path_grammar({
        -- verbose = 4,
      })
      local class = "[:".. name ..":]"
      local result = P(G):match('['.. class ..']')
      expect(result).NOT(nil)
      return result
    end

    local classes = {}
    for _,name in ipairs({
      "alnum",
      "alpha",
      "ascii",
      "blank",
      "cntrl",
      "digit",
      "graph",
      "lower",
      "print",
      "punct",
      "space",
      "upper",
      "word",
      "xdigit",
    }) do
      append(
        classes,
        {
          name,
          get_class_P(name),
          get_set_P(name),
          get_delimited_P(name),
          get_P(name),
        }
      )
    end
    ---@type table<integer[],integer>
    -- keys are range of letter codepoints
    -- values are 1 for match, 0 for no match
    local xpct = {
      [{ 'a-f' }] = {
        alnum = 1,
        alpha = 1,
        ascii = 1,
        blank = 0,
        cntrl = 0,
        digit = 0,
        graph = 1,
        lower = 1,
        print = 1,
        punct = 0,
        space = 0,
        upper = 0,
        word  = 1,
        xdigit = 1,
      },
      [{ 'A-F' }] = {
        alnum = 1,
        alpha = 1,
        ascii = 1,
        blank = 0,
        cntrl = 0,
        digit = 0,
        graph = 1,
        lower = 0,
        print = 1,
        punct = 0,
        space = 0,
        upper = 1,
        word  = 1,
        xdigit = 1,
      },
      [{ 'g-z' }] = {
        alnum = 1,
        alpha = 1,
        ascii = 1,
        blank = 0,
        cntrl = 0,
        digit = 0,
        graph = 1,
        lower = 1,
        print = 1,
        punct = 0,
        space = 0,
        upper = 0,
        word  = 1,
        xdigit = 0,
      },
      [{ 'G-Z' }] = {
        alnum = 1,
        alpha = 1,
        ascii = 1,
        blank = 0,
        cntrl = 0,
        digit = 0,
        graph = 1,
        lower = 0,
        print = 1,
        punct = 0,
        space = 0,
        upper = 1,
        word  = 1,
        xdigit = 0,
      },
      [{ '0-9' }] = {
        alnum = 1,
        alpha = 0,
        ascii = 1,
        blank = 0,
        cntrl = 0,
        digit = 1,
        graph = 1,
        lower = 0,
        print = 1,
        punct = 0,
        space = 0,
        upper = 0,
        word  = 1,
        xdigit = 1,
      },
      [{ ' ' }] = {
        alnum = 0,
        alpha = 0,
        ascii = 1,
        blank = 1,
        cntrl = 0,
        digit = 0,
        graph = 0,
        lower = 0,
        print = 1,
        punct = 0,
        space = 1,
        upper = 0,
        word  = 0,
        xdigit = 0,
      },
      [{ '_' }] = {
        alnum = 0,
        alpha = 0,
        ascii = 1,
        blank = 0,
        cntrl = 0,
        digit = 0,
        graph = 1,
        lower = 0,
        print = 1,
        punct = 1,
        space = 0,
        upper = 0,
        word  = 1,
        xdigit = 0,
      },
      [{ '!-#', '%-*', ',-/' }] = {
        alnum = 0,
        alpha = 0,
        ascii = 1,
        blank = 0,
        cntrl = 0,
        digit = 0,
        graph = 1,
        lower = 0,
        print = 1,
        punct = 1,
        space = 0,
        upper = 0,
        word  = 0,
        xdigit = 0,
      },
      [{ '$', '+' }] = {
        alnum = 0,
        alpha = 0,
        ascii = 1,
        blank = 0,
        cntrl = 0,
        digit = 0,
        graph = 1,
        lower = 0,
        print = 1,
        punct = 0,
        space = 0,
        upper = 0,
        word  = 0,
        xdigit = 0,
      },
      [{ ':-;', '?-@', '[-]'}] = {
        alnum = 0,
        alpha = 0,
        ascii = 1,
        blank = 0,
        cntrl = 0,
        digit = 0,
        graph = 1,
        lower = 0,
        print = 1,
        punct = 1,
        space = 0,
        upper = 0,
        word  = 0,
        xdigit = 0,
      },
      [{ '<->', '^', '`', '|', '~' }] = {
        alnum = 0,
        alpha = 0,
        ascii = 1,
        blank = 0,
        cntrl = 0,
        digit = 0,
        graph = 1,
        lower = 0,
        print = 1,
        punct = 0,
        space = 0,
        upper = 0,
        word  = 0,
        xdigit = 0,
      },
      [{ '{', '}' }] = {
        alnum = 0,
        alpha = 0,
        ascii = 1,
        blank = 0,
        cntrl = 0,
        digit = 0,
        graph = 1,
        lower = 0,
        print = 1,
        punct = 1,
        space = 0,
        upper = 0,
        word  = 0,
        xdigit = 0,
      },
      [{ '\x7F' }] = {
        alnum = 0,
        alpha = 0,
        ascii = 1,
        blank = 0,
        cntrl = 1,
        digit = 0,
        graph = 1,
        lower = 0,
        print = 1,
        punct = 0,
        space = 0,
        upper = 0,
        word  = 0,
        xdigit = 0,
      },
      [{ '¡' }] = {
        alnum = 0,
        alpha = 0,
        ascii = 0,
        blank = 0,
        cntrl = 0,
        digit = 0,
        graph = 1,
        lower = 0,
        print = 1,
        punct = 1,
        space = 0,
        upper = 0,
        word  = 0,
        xdigit = 0,
      },
      [{ '\xC2\x80' }] = {
        alnum = 0,
        alpha = 0,
        ascii = 0,
        blank = 0,
        cntrl = 1,
        digit = 0,
        graph = 1,
        lower = 0,
        print = 1,
        punct = 0,
        space = 0,
        upper = 0,
        word  = 0,
        xdigit = 0,
      },
    }
    for r, xx in pairs(xpct) do
      for _, s in ipairs(r) do
        local s_1 = sln_utf8.sub(s, 1, 1)
        local s_2 = sln_utf8.sub(s, sln_utf8.len(s))
        for i = utf8.codepoint(s_1), utf8.codepoint(s_2) do
          for _, class_P in ipairs(classes) do
            local ss = utf8.char(i)
            local expected = xx[class_P[1]]
            if expected ~= nil then
              expected = expected > 0 and #ss + 1 or nil
              expect(class_P[2]:match(ss)).is(expected)
              expect(class_P[3]:match(ss)).is(expected)
              expect(class_P[4]:match(ss)).is(expected)
              expect(class_P[5]:match(ss)).is(expected)
            end
          end
        end
      end
    end
  end,
  test_range = function (self)
    local G = lpeglib.__get_path_grammar({
      -- verbose = 4,
    })
    G["content"] = G[".-."] * G["$"]
    local p = P(G)
    local q = p:match("b-y")
    expect(q:match("a")).is(nil)
    expect(q:match("b")).is(2)
    expect(q:match("c")).is(2)
    expect(q:match("x")).is(2)
    expect(q:match("y")).is(2)
    expect(q:match("z")).is(nil)
    q = p:match("\xF0\x9D\x90\x9B-\xF0\x9D\x90\xB2")
    expect(q:match("\xF0\x9D\x90\x9A")).is(nil)
    expect(q:match("\xF0\x9D\x90\x9B")).is(5)
    expect(q:match("\xF0\x9D\x90\x9C")).is(5)
    expect(q:match("\xF0\x9D\x90\xB1")).is(5)
    expect(q:match("\xF0\x9D\x90\xB2")).is(5)
    expect(q:match("\xF0\x9D\x90\xB3")).is(nil)
  end,
  test_set = function (self)
    local G = lpeglib.__get_path_grammar({
      -- verbose = 4,
    })
    G["content"] = G["set"] * G["$"]
    local p = P(G)
    local q = p:match("a")
    expect(q:match("a")).is(2)
    expect(q:match("b")).is(nil)
    expect(q:match("c")).is(nil)
    q = p:match("ab")
    expect(q:match("a")).is(2)
    expect(q:match("b")).is(2)
    expect(q:match("c")).is(nil)
    q = p:match("abc")
    expect(q:match("a")).is(2)
    expect(q:match("b")).is(2)
    expect(q:match("c")).is(2)
    q = p:match("]")
    expect(q:match("]")).is(2)
    q = p:match("-")
    expect(q:match("-")).is(2)
  end,
  test_globstar = function (self)
    -- globstar is true by default
    local G = lpeglib.__get_path_grammar({
      -- verbose = 4,
    })
    G["content"] = G["**"] * G["$"]
    local p = P(G)
    local q = p:match("**")
    expect(q:match("")).is(1)
    expect(q:match(".")).is(2)
    expect(q:match(" .")).is(3)
    expect(q:match("/.")).is(3)
    expect(q:match("/ .")).is(4)
    expect(q:match("/a/.")).is(5)
    expect(q:match("/a/ .")).is(6)
    G["content"] = G["/**/"] * G["$"]
    p = P(G)
    q = p:match("/**/")
    expect(q:match("")).is(nil)
    expect(q:match(".")).is(nil)
    expect(q:match("/")).is(2)
    expect(q:match("//")).is(3)
    expect(q:match("/./")).is(4)
    expect(q:match("/a/")).is(4)
    expect(q:match("/ ./")).is(5)
    expect(q:match("/a/.")).is(5)
    expect(q:match("/a/ ./")).is(7)
    -- globstar is true by default
    G = lpeglib.__get_path_grammar({
      globstar = false,
    })
    G["content"] = G["**"] * G["$"]
    p = P(G)
    q = p:match("**")
    expect(q).is(nil)
  end,
  test_extglob = function (self)
    local G = lpeglib.__get_path_grammar({
      extglob = true,
    })
    local p = P(G)
    local q = p:match("?(a)")
    expect(q:match("")).is(1)
    expect(q:match("a")).is(2)
    expect(q:match("b")).is(nil)
    q = p:match("?(a|b)")
    expect(q:match("")).is(1)
    expect(q:match("a")).is(2)
    expect(q:match("b")).is(2)
    q = p:match("*(a|b)")
    expect(q:match("")).is(1)
    expect(q:match("a")).is(2)
    expect(q:match("b")).is(2)
    expect(q:match("aa")).is(3)
    expect(q:match("ab")).is(3)
    expect(q:match("ba")).is(3)
    expect(q:match("bb")).is(3)
    q = p:match("+(a|b)")
    expect(q:match("")).is(nil)
    expect(q:match("a")).is(2)
    expect(q:match("b")).is(2)
    expect(q:match("aa")).is(3)
    expect(q:match("ab")).is(3)
    expect(q:match("ba")).is(3)
    expect(q:match("bb")).is(3)
    q = p:match("@(a|b)")
    expect(q:match("")).is(nil)
    expect(q:match("a")).is(2)
    expect(q:match("b")).is(2)
    expect(q:match("aa")).is(nil)
    expect(q:match("ab")).is(nil)
    expect(q:match("ba")).is(nil)
    expect(q:match("bb")).is(nil)
    q = p:match("!(a|b)")
    expect(q:match("")).is(nil)
    expect(q:match("a")).is(nil)
    expect(q:match("b")).is(nil)
    expect(q:match("aa")).is(nil)
    expect(q:match("ab")).is(nil)
    expect(q:match("ba")).is(nil)
    expect(q:match("bb")).is(nil)
    expect(q:match("c")).is(2)
  end,
}

local test_path_matcher = {
  do_test = function (glob, target, yorn, opts)
    opts = opts or {}
    local match = lpeglib.path_matcher(glob, opts)
    expect(match).NOT(nil)
    local m = match(target)
    if opts.verbose or not m ~= not yorn then
      print(glob, target, yorn, m)
    end
    expect(not m).is(not yorn)
  end,
  test_1_char = function (self)
    self.do_test("a", "a", true)
    self.do_test("a", "aa", false)
    self.do_test("a", "b", false)
    self.do_test("ab", "ab", true)
    self.do_test("ab", "a", false)
    self.do_test(".", ".", true)
    for s in get_utf8_sample() do
      self.do_test(s, s, true)
    end
  end,
  test_wildcard_2 = function (self)
    for _, glob in ipairs({"*", "**"}) do
      self.do_test(glob, "", true)
      self.do_test(glob, "a", true)
      self.do_test(glob, "abc", true)
      self.do_test(glob, "a.c", true)
      self.do_test(glob, ".", true)
      self.do_test(glob, ".bc", false)
    end
    self.do_test("*", "/", true)
    self.do_test("*", "/b", false)
    self.do_test("*", "a/", true)
    self.do_test("*", "a/b", false)
    self.do_test("**", "/", true)
    self.do_test("**", "a/b", true)
    self.do_test("**", "/", true, {
      globstar = false,
    })
    self.do_test("**", "a/b", false, {
      globstar = false,
    })
    for _, glob in ipairs({"*", "**"}) do
      self.do_test(glob, ".", true, {
        dotglob = true,
      })
      self.do_test(glob, ".bc", true, {
        dotglob = true,
      })
    end
  end,
  test_wildcard_1 = function (self)
    self.do_test("?", "a", true)
    self.do_test("?", "b", true)

    self.do_test("?", ".", false)
    self.do_test("?", "", false)
    self.do_test("?", "ab", false)

    self.do_test("?x", "ax", true)
    self.do_test("?x", "bx", true)

    self.do_test("?a", ".a", false)
    self.do_test("?", "", false)
    self.do_test("?", "ab", false)

    for s in get_utf8_sample() do
      if s ~= "." and s ~= "/" then
        self.do_test("?", s, true)
        self.do_test("?a", s .."a", true)
        self.do_test("a?", "a".. s, true)
      end
    end
  end,
  test_parent = function (self)
    local function do_test(glob)
      expect(function ()
        lpeglib.path_matcher(glob)
      end).error()
    end
    do_test("..")
    do_test("../")
    do_test("a/..")
    do_test("a/../b")
  end,
}

return {
  test_base         = test_base,
  test_lpeg         = test_lpeg,
  test_path_matcher = test_path_matcher,
  test_consume_1_character_p  = test_consume_1_character_p,
  test___grammar    = test___grammar,
}