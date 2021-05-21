#!/usr/bin/env texlua
--[[
  This is a test file for l3build package.
  It is only intended for development and should appear in any distribution of the l3build package.
  For help, run `texlua l3build.lua test -h`
--]]

local push   = table.insert

local expect  = _ENV.expect

local unicode = require("unicode")
local sln_utf8 = unicode.utf8

---@type pathlib_t
local pathlib
---@type __pathlib_t
local __

pathlib, __ = _ENV.loadlib("l3b-pathlib")

local Path = __.Path

expect(Path).NOT(nil)

local lpeg = require("lpeg")
local Ct  = lpeg.Ct
local Cs  = lpeg.Cs
local P   = lpeg.P
local V   = lpeg.V

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

local function test_split ()
  local split = pathlib.split
  expect(function () split() end).error()
  expect(function () split("") end).error()
  expect(function () split(nil, "") end).error()
  expect(split("abc", "")).equals({ "a", "b", "c" })
  expect(split("abc", "a")).equals({ "", "bc" })
  expect(split("abc", "b")).equals({ "a", "c" })
  expect(split("abc", "c")).equals({ "ab", "" })
  expect(split("aabc", "a")).equals({ "", "", "bc" })
  expect(split("abbc", "b")).equals({ "a", "", "c" })
  expect(split("abcc", "c")).equals({ "ab", "", "" })
  expect(split("aabc", P("a")^1)).equals({ "", "bc" })
  expect(split("abbc", P("b")^1)).equals({ "a", "c" })
  expect(split("abcc", P("c")^1)).equals({ "ab", "" })
end

local function test_base_extension()
  local test = function (s, expected)
    expect(s:get_base_extension()).equals(expected)
  end
  test("", {
    base = "",
    extension = ""
  })
  test("abc", {
    base = "abc",
    extension = ""
  })
  for _, base in ipairs({
    "",
    "a",
    ".",
    ".a",
    "a.",
    "..",
    "..a",
    ".a.",
    "a..",
    "a.b",
    ".a.b",
    "a.b.",
  }) do
    for _, extension in ipairs({"", "ext"}) do
      test(base ..".".. extension, {
        base = base,
        extension = extension
      })
    end
  end
end

local test_file_path_gmr = {
  test_basic = function (self)
    expect(__.get_file_path_gmr).NOT(nil)
    expect(__.get_file_path_gmr()).NOT(nil)
  end,
  test_1st_part = function (self)
    local gmr = __.get_file_path_gmr()
    gmr[1] = V("1st part")
    local p = P(gmr)
    local function test(s, length)
      local m = p:match(s)
      if length ~= nil then
        expect(m).is(length)
      else
        expect(m).is(nil)
      end
    end
    test("/", 1)
    test("/./", 1)
    test("/././", 1)
    test("", 1)
    test("./", 2)
    test("1/..", 5)
    test("1/3/../..", 10)
  end,
  test_is_absolute = function (self)
    local gmr = __.get_file_path_gmr()
    gmr[1] = V("is_absolute")
    local p = P(gmr)
    local function test(s, flag)
      local m = p:match(s)
      if flag ~= nil then
        expect(m).is(flag)
      else
        expect(m).is(nil)
      end
    end
    test("/", true)
    test("/./", true)
    test("/././", true)
    test("", false)
    test("./", false)
    test("././", false)
    test("./././", false)
    test("a/..", false)
    test("a/b/../..", false)
  end,
  test_component = function (self)
    local gmr = __.get_file_path_gmr()
    gmr[1] = V("component")
    local p = P(gmr)
    expect(p:match("abc")).is("abc")
    expect(p:match("abc/")).is("abc")
    expect(p:match("/")).is(nil)
    expect(p:match(".")).is(2)
    expect(p:match("..")).is("..")
    expect(p:match("...")).is("...")
  end,
  test_down_up = function (self)
    local gmr = __.get_file_path_gmr()
    gmr[1] = V("component/..")
    local p = P(gmr)
    expect(p:match("a")).is(nil)
    expect(p:match("a/")).is(nil)
    expect(p:match("a/...")).is(nil)
    expect(p:match("/..")).is(nil)
    expect(p:match("a/..")).is(5)
    expect(p:match(".../..")).is(7)
    expect(p:match("a/../")).is(5)
    expect(p:match("a/b/../..")).is(10)
    expect(p:match("a/b/../../")).is(10)
  end,
  test_separator = function (self)
    local gmr = __.get_file_path_gmr()
    gmr[1] = V("separator")
    local p = P(gmr)
    expect(p:match("a")).is(nil)
    expect(p:match("/")).is(2)
    expect(p:match("//")).is(3)
    expect(p:match("/./")).is(4)
    expect(p:match("/23/../")).is(8)
  end,
  test_full = function (self)
    local gmr = __.get_file_path_gmr()
    local p = P(gmr)
    expect(p:match("a")).is(false)
    gmr = __.get_file_path_gmr()
    p = Ct( P(gmr) )
    local function test(s, ...)
      local m = p:match(s)
      expect(m).equals( {...} )
    end
    test("", false)
    test("a", false, "a")
    test("a/", false, "a", "")
    test("a/b", false, "a", "b")
    test("a/b/", false, "a", "b", "")
    test("/", true)
    test("/a", true, "a")
    test("/a/", true, "a", "")
    test("/a/b", true, "a", "b")
    test("/a/b/", true, "a", "b", "")
  end,
}

local function test_Path()
  local p = Path({ str = "" })
  expect(p).equals(Path())
  expect(p).equals(Path({ data = {
    is_absolute = false,
    down        = {},
    up          = {},
  } }))
  expect(p.as_string).is(".")
  local function test(str, down, normalized, is_absolute)
    local pp = Path({ str = str, })
    expect(pp).equals(Path({ data = {
      down = down,
      is_absolute = is_absolute or false,
    }, }))
    expect(pp.as_string).is(normalized or str)
    return
  end
  test("a", { "a" }, "./a")
  test("a/", { "a", "" }, "./a/")
  test("a/b", { "a", "b" }, "./a/b")
  test("a///b", { "a", "b" }, "./a/b")
  test("a/./b", { "a", "b" }, "./a/b")
  test("a//./b", { "a", "b" }, "./a/b")
  test("a/.//b", { "a", "b" }, "./a/b")
  test("a//.//b", { "a", "b" }, "./a/b")
  test("a//././b", { "a", "b" }, "./a/b")
  test("a/././/b", { "a", "b" }, "./a/b")
  test("a/./././b", { "a", "b" }, "./a/b")
  test("a/..", { }, ".")
  test("a/b/../..", { }, ".")
  test("a/..b", { "a", "..b" }, "./a/..b")
  test("a/../b", { "b" }, "./b")
  test("a/b/../../c", { "c" }, "./c")
  test("a/b/c/../..", { "a", "" }, "./a/")
  test("a/b/c/../../d", { "a", "d" }, "./a/d")

  test("/a/b/c/..", { "a", "b", "" }, "/a/b/", true)

  p = Path({ str = "/" })
  expect(p).equals(Path({ data = {
    is_absolute = true,
  } }))
  expect(p.as_string).is("/")
  p = Path({ str = "/a" })
  expect(p).equals(Path({ data = {
    is_absolute = true,
    down = { "a" },
  } }))
  expect(p.as_string).is("/a")
  p = Path({ str = "/a/b" })
  expect(p).equals(Path({ data = {
    is_absolute = true,
    down = { "a", "b" },
  }, }))
  expect(p.as_string).is("/a/b")
  expect(function ()
    Path({ str = "/..", })
  end).error()
  p = Path({ str = "..", })
  expect(p).equals(Path({ data = {
    up = { ".." },
  }, }))
  expect(p.as_string).is("..")
  p = Path({ str = "../..", })
  expect(p).equals(Path({ data = {
    up = { "..", ".." },
  }, }))
  expect(p.as_string).is("../..")
  p = Path({ str = "a/..", })
  expect(p).equals(Path())
  expect(p.as_string).is(".")
  p = Path({ str = "a/b/..", })
  expect(p).equals(Path({ data = {
    down = { "a", "" },
  }, }))
  expect(p.as_string).is("./a/")
  local p_1 = Path({ str = "a/b", })
  local p_2 = Path({ str = "..", })
  expect(p_2).equals(Path({ data = {
    up = { ".." },
  }, }))
  p = p_1 / p_2
  expect(p).equals(Path({ data = {
    down = { "a" },
  }, }))

end

local function test_copy()
  expect(Path(""):copy().as_string).is(".")
  expect(Path({ str = "/", }):copy().as_string).is("/")
  expect(Path({ str = "/", }):copy().is_absolute).is(true)
end

local function test_Path_forward_slash()
  local function test(l, r, lr)
    local actual = Path(l) / Path(r)
    local expected = Path(lr)
    expect(actual).equals(expected)
  end
  test("", "", ".")
  test("a", "", "a/")
  test("", "a", "./a")
  test("/", "a", "/a")
  test("a", "b", "a/b")
  test("a/b", "..", "./a")
  test("a/..", "b", "./b")
end

local function test_POC_parts()
  local p = ( P("/.")^0 * P("/") )^1
  expect(p:match("/")).is(2)
  expect(p:match("//")).is(3)
  expect(p:match("/./")).is(4)
  expect(p:match("/.//")).is(5)
  expect(p:match("//./")).is(5)
  expect(p:match("//.//")).is(6)
  expect(p:match("/././/")).is(7)
  expect(p:match("/.//./")).is(7)
  expect(p:match("//././")).is(7)
  expect(p:match("/./././")).is(8)
end

local function test_string_forward_slash()
  expect("" / "").is(".")
  expect("a" / "").is("./a/")
  expect("" / "a").is("./a")
  expect("a" / "b").is("./a/b")
  expect("a/" / "b").is("./a/b")
  expect(function () print("a" / "/b") end).error()
  expect("/" / "").is("/")
  expect("" / "/").is("/")
  expect("/" / "/").is("/")
  expect("/" / "a").is("/a")
  expect("/" / "a").is("/a")
  expect("/" / "./a").is("/a")
  expect("a" / "..").is(".")
  expect("a" / "../").is("./")
  expect("/a" / "..").is("/")
  expect("/a" / "../").is("/")
  expect(function () print("/a" / "../..") end).error()
  expect("a/" / ".").is("./a/")
end

local function test_dir_name()
  local dir_name = pathlib.dir_name
  expect(dir_name("")).is(".")
  expect(dir_name("abc")).is(".")
  expect(dir_name("a/c")).is("a")
  expect(dir_name("/a/c")).is("/a")
  expect(dir_name("..")).is(".")
  expect(dir_name("../..")).is("..")
end

local function test_base_name()
  local base_name = pathlib.base_name
  expect(base_name("")).is("")
  expect(base_name("abc")).is("abc")
  expect(base_name("a/c")).is("c")
  expect(base_name("..")).is("..")
  expect(base_name("../..")).is("..")
end

local function test_core_name()
  local core_name = pathlib.core_name
  expect(core_name("")).is("")
  expect(core_name("abc.d")).is("abc")
  expect(core_name("a/c.d")).is("c")
  expect(core_name("a/.d")).is("")
  expect(core_name("..")).is(".")
  expect(core_name("../..")).is(".")
end

local function test_extension()
  local extension = pathlib.extension
  expect(extension("")).is(nil)
  expect(extension("abc.d")).is("d")
  expect(extension("a/c.d")).is("d")
  expect(extension("a/.d")).is("d")
  expect(extension("..")).is(nil)
end

local function test_sanitize()
  local sanitize = pathlib.sanitize
  expect(sanitize("")).is(".")
  expect(sanitize("a/..")).is(".")
  expect(sanitize("a/./.")).is("./a")
  expect(sanitize("a/./.", true)).is("a")
end

local function test_relative()
  local relative = pathlib.relative
  expect(relative).type("function")
  local function test(a, b, c)
    local result = relative(a, b)
    expect(result).is(c)
  end
  test(".", "/", nil)
  test("..", "/", nil)
  test("a", "/", nil)
  test("a", "../b", nil)
  test("..", "../..", nil)
  function test(a, b, c)
    local result = relative(a, b)
    expect(result).is(c)
    expect(a / ".").is(b / result / ".")
  end
  -- both are relative paths
  test("", "", ".")
  test("", ".", ".")
  test("", "a", "..")
  test("", "a/", "..")
  test("..", "", "..")
  test("../", "", "../")
  test("..", ".", "..")
  test("../", ".", "../")
  test("..", "./", "..")
  test("../", "./", "../")
  test("..", "..", ".")
  test("../", "..", "./")
  test("../a", "..", "./a")
  test("../a/", "..", "./a/")
  test("../a/b", "..", "./a/b")
  test("../..", "..", "..")
  test("../../", "..", "../")
  test("../../a", "..", "../a")
  test("../..", "../..", ".")
  test("../..", "../a", "../..")
  test("../..", "../a/b", "../../..")
  test("../../c/d/", "../a/b", "../../../c/d/")
  -- both are absolute paths
  -- common components = 0
  test("/", "/", ".")
  test("/a", "/", "./a")
  test("/a/", "/", "./a/")
  test("/a/b", "/", "./a/b")
  test("/a/b/", "/", "./a/b/")
  -- common components = 1
  test("/a", "/a", ".")
  test("/a", "/a/", ".")
  test("/a/", "/a", "./")
  test("/a/b", "/a", "./b")
  test("/a/b/", "/a", "./b/")
  test("/a/", "/a/", "./")
  test("/a/b", "/a/", "./b")
  test("/a/b/", "/a/", "./b/")
  test("/a", "/b", "../a")
  test("/a/", "/b", "../a/")
  test("/a/b", "/b", "../a/b")
  test("/a/b/", "/b", "../a/b/")
  -- common components = 2
  test("/a/b", "/a/b", ".")
  test("/a/b/", "/a/b", "./")
  test("/a", "/a/b", "..")
  test("/a/", "/a/b", "../")
  test("/a", "/a/b/c", "../..")
  test("/a/", "/a/b/c", "../../")
  test("/a/b", "/a/b/c", "..")
  test("/a/b/", "/a/b/c", "../")
  test("/a/b/d", "/a/b/c", "../d")
  test("/a/b/d/", "/a/b/c", "../d/")
  test("/a/b/d/e", "/a/b/c", "../d/e")
  test("/a/b/d/e/", "/a/b/c", "../d/e/")
  test("/a/b/c", "/a/b", "./c")
  test("/a/b/c/", "/a/b", "./c/")
  test("/a/b/c/d", "/a/b", "./c/d")
  test("/a/b/c/d/", "/a/b", "./c/d/")
end

local test___grammar = {
  test_POC = function (self)
    local s = "\xF0\x9F\x98\x80"
    -- a path character is anything but a path separator
    ---@type lpeg_t
    local path_char_p = __.path_char_p
    expect(path_char_p:match("/")).is(nil)
    expect(path_char_p:match(s)).is(5)
    -- in default mode (not dotglob), the leading dot is special
    ---@type lpeg_t
    local path_char_no_dot_p = __.path_char_no_dot_p
    expect(path_char_no_dot_p:match("/")).is(nil)
    expect(path_char_no_dot_p:match(".")).is(nil)
    expect(path_char_no_dot_p:match(s)).is(5)
    -- whether we are at the beginning of a path component
    ---@type lpeg_t
    local is_leading_p = __.is_leading_p
    expect(is_leading_p:match("")).is(1)
    expect(is_leading_p:match("a", 2)).is(nil)
    expect(is_leading_p:match("/", 2)).is(2)
    -- in default mode, match any character in a path component
    ---@type lpeg_t
    local path_char_no_dotglob_p = __.path_char_no_dotglob_p
    expect(path_char_no_dotglob_p:match("/")).is(nil)
    expect(path_char_no_dotglob_p:match("/.", 2)).is(nil)
    expect(path_char_no_dotglob_p:match(".")).is(nil)
    expect(path_char_no_dotglob_p:match(" .", 2)).is(3)
    expect(path_char_no_dotglob_p:match(s)).is(5)
    ---@type lpeg_t
    local path_comp_no_dotglob_p = __.path_comp_no_dotglob_p
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
  test_1_char = function (self)
    local gmr = __.get_path_gmr()
    gmr["content"] = gmr["1 path char"] * gmr["$"]
    ---@type lpeg_t
    local p = P(gmr)
    ---@type lpeg_t
    local q = p:match("a")
    expect(lpeg.type(q)).is("pattern")
    expect(q:match("a")).is(2)
    expect(q:match("aa")).is(nil)
    expect(q:match("b")).is(nil)

    gmr = __.get_path_gmr({
      -- verbose = 3,
    })
    p = P(gmr)
    q = p:match("a")

    expect(lpeg.type(q)).is("pattern")
    expect(q:match("a")).is(2)
    expect(q:match("aa")).is(nil)
    expect(q:match("b")).is(nil)
    expect(q:match("")).is(nil)

    gmr = __.get_path_gmr()
    p = P(gmr)
    for i = 32, 65535 do
      local s = utf8.char(i)
      q = p:match(s)
      expect(q:match(s)).is(#s + 1)
    end

    local match = pathlib.path_matcher
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
    local gmr = __.get_path_gmr({
      -- verbose = 4,
    })
    gmr["content"] = V("$")
    local p = P(gmr)
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
      local gmr = __.get_path_gmr({
        -- verbose = 4,
      })
      local class = "[:".. name ..":]"
      gmr["content"] =
        ( gmr[class] or  gmr["[:...:]"] )
        * gmr["$"]
      local result = P(gmr):match(class)
      expect(result).NOT(nil)
      return result
    end
    local function get_set_P(name)
      local gmr = __.get_path_gmr({
        -- verbose = 4,
      })
      local class = "[:".. name ..":]"
      gmr["content"] = gmr["set"] * gmr["$"]
      local result = P(gmr):match(class)
      expect(result).NOT(nil)
      return result
    end
    local function get_delimited_P(name)
      local gmr = __.get_path_gmr({
        -- verbose = 4,
      })
      local class = "[:".. name ..":]"
      gmr["content"] = gmr["[...]"] * gmr["$"]
      local result = P(gmr):match('['.. class ..']')
      expect(result).NOT(nil)
      return result
    end
    local function get_P(name)
      local gmr = __.get_path_gmr({
        -- verbose = 4,
      })
      local class = "[:".. name ..":]"
      local result = P(gmr):match('['.. class ..']')
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
      push(
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
      [{ 'gmr-Z' }] = {
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
    local gmr = __.get_path_gmr({
      -- verbose = 4,
    })
    gmr["content"] = gmr[".-."] * gmr["$"]
    local p = P(gmr)
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
    local gmr = __.get_path_gmr({
      -- verbose = 4,
    })
    gmr["content"] = gmr["set"] * gmr["$"]
    local p = P(gmr)
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
    local gmr = __.get_path_gmr({
      -- verbose = 4,
    })
    gmr["content"] = gmr["**"] * gmr["$"]
    local p = P(gmr)
    local q = p:match("**")
    expect(q:match("")).is(1)
    expect(q:match(".")).is(2)
    expect(q:match(" .")).is(3)
    expect(q:match("/.")).is(3)
    expect(q:match("/ .")).is(4)
    expect(q:match("/a/.")).is(5)
    expect(q:match("/a/ .")).is(6)
    gmr["content"] = gmr["/**/"] * gmr["$"]
    p = P(gmr)
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
    gmr = __.get_path_gmr({
      globstar = false,
    })
    gmr["content"] = gmr["**"] * gmr["$"]
    p = P(gmr)
    q = p:match("**")
    expect(q).is(nil)
  end,
  test_extglob = function (self)
    local gmr = __.get_path_gmr({
      extglob = true,
    })
    local p = P(gmr)
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
    local match = pathlib.path_matcher(glob, opts)
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

    self.do_test("*", "abc", true)
    self.do_test("a*", "abc", true)
    self.do_test("*c", "abc", true)
    self.do_test("*b", "abc", false)
    self.do_test("*b*", "abc", true)
    self.do_test("b*", "abc", false)
  end,
  test_parent = function (self)
    local function do_test(glob)
      expect(function ()
        pathlib.path_matcher(glob)
      end).error()
    end
    do_test("..")
    do_test("../")
    do_test("a/..")
    do_test("a/../b")
  end,
}
local test_glob_to_pattern = {
  test_grammar = function (self)
    local gmr = __.get_glob_to_pattern_gmr()
    gmr[1] = gmr['?']
    local p = P(gmr)
    expect(p:match("?")).is(".")
    gmr[1] = gmr['*']
    p = P(gmr)
    expect(p:match("*")).is(".*")
    gmr[1] = gmr['*']
    p = P(gmr)
    expect(p:match("*")).is(".*")
    gmr[1] = gmr['.-.']
    p = P(gmr)
    expect(p:match("a-b")).is("a-b")
    expect(p:match("a-]")).is(nil)
    expect(p:match("[-b")).is('%[-b')
    expect(p:match("---")).is("%--%-")
    gmr[1] = gmr.head
    p = P(gmr)
    expect(p:match("a")).is("a")
    expect(p:match("]")).is("%]")
    expect(p:match("-")).is("%-")
    gmr[1] = gmr.tail
    p = P(gmr)
    expect(p:match("a")).is("a")
    expect(p:match("]")).is(nil)
    expect(p:match("-")).is(nil)
    
    gmr[1] = Cs( gmr.set )
    p = P(gmr)
    expect(p:match("a")).is("a")
    expect(p:match("a-b")).is("a-b")
    expect(p:match("---")).is("%--%-")
    expect(p:match("]--")).is("%]-%-")
    expect(p:match("[--")).is("%[-%-")
    expect(p:match("-")).is("%-")
    expect(p:match("]")).is("%]")
    expect(p:match("ab")).is("ab")
    expect(p:match("a-")).is("a%-")

    gmr[1] = Cs( gmr['[...]'] )
    p = P(gmr)
    expect(p:match("[a]")).is("[a]")
    expect(p:match("[a-]]")).is("[a%-]")
    expect(p:match("[a-z-]]")).is("[a-z%-]")
  end,
  test = function (self)
    local glob_to_pattern = pathlib.glob_to_pattern
    local function test(source, pattern, expected)
      return expect(
          source:match( glob_to_pattern(pattern) )
      ).is(expected or source)
    end
    local function no_test(source, pattern)
      return expect(
          source:match( glob_to_pattern(pattern) )
      ).is(nil)
    end
    test("a", "a")
    no_test("b", "a")
    test("a", "?")
    no_test("", "?")
    no_test("aa", "?")
    test("", "*")
    test("a", "*")
    test("abc", "*")
    test("a", "\\a")
    no_test("b", "\\a")
    test("a", "[a]")
    no_test("b", "[a]")
    test("b", "[^a]")
    no_test("a", "[^a]")
    test("-", "[-]")
    test("-", "[-a]")
    test("-", "[a-]")
    test("5", "[0-9]")
    test("5", "[a-z0-9]")
    test("5", "[^a-z]")
  end,
}

--[[
  local function get_glob_to_pattern_gmr()
  return {
    Cs( Cc('^') * V("item")^0 * Cc('$') ),
    item = Cg(
        V('?')
      + V('*')
      + V('\\')
    )
    + V('[')
    + V("%"),
    ['?']   = P('?') * Cc('.'),
    ['*']   = P('*') * Cc('.*'), -- should be '[^/]*'
    ['\\']  = P('\\') * ( P(-1) + C( V("escaped_char") ) ),
    ['[']   = P('[')
      / function()
          print("[...] syntax not supported in globs!")
          return ''
        end,
    ["%"] = Cc('%') * S('^$()%.[]*+-?') + P(1),
  }
end

]]

return {
  test_split                = test_split,
  test_dir_name             = test_dir_name,
  test_base_name            = test_base_name,
  test_core_name            = test_core_name,
  test_extension            = test_extension,
  test_sanitize             = test_sanitize,
  test_relative             = test_relative,
  test_base_extension       = test_base_extension,
  test_file_path_gmr        = test_file_path_gmr,
  test_Path                 = test_Path,
  test_copy                 = test_copy,
  test_Path_forward_slash   = test_Path_forward_slash,
  test_POC_parts            = test_POC_parts,
  test_string_forward_slash = test_string_forward_slash,
  test_glob_to_pattern      = test_glob_to_pattern,
  test___grammar            = test___grammar,
  test_path_matcher         = test_path_matcher,
}