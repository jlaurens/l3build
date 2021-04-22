#!/usr/bin/env texlua

local lpeg    = require("lpeg")
local P       = lpeg.P
local Cg      = lpeg.Cg
local Ct      = lpeg.Ct
local Cc      = lpeg.Cc
local Cb      = lpeg.Cb
local V       = lpeg.V
local Cp      = lpeg.Cp

local LU      = require("l3b-test/luaunit")
local expect  = require("l3b-test/expect").expect

local l3build = require("l3build")

local AUTODOC_NAME = "l3b-autodoc"
local AUTODOC_PATH = l3build.work_dir .."l3b/".. AUTODOC_NAME ..".lua"

local pretty_print = _G.pretty_print

-- Next is an _ENV that will allow a module to export
-- more symbols than usually done in order to finegrain testing
local __ = setmetatable({
  during_unit_testing = true,
}, {
  __index = _G
})

local AD = loadfile(
  AUTODOC_PATH,
  "t",
  __
)()

local PEG_XTD = setmetatable({}, { __index = _G })

local PEG = loadfile(
  l3build.work_dir .."l3b/l3b-lpeg-autodoc.lua",
  "t",
  PEG_XTD
)()

local adata   = require("l3b-test/autodoc_data").expect
local Test    = adata.Test

_G.test_POC = Test({
  test_Ct = function ()
    local p_one = Cg(P(1), "one")
    local p_two = Cg(P(1), "two")
    local t = Ct(p_one*p_two):match("12")
    expect(t.one).is("1")
    expect(t.two).is("2")
  end,
  test_min_max = function(self)
    -- print("POC min <- max + 1")
    local p1 =
        Cg(Cc(421), "min")
      * Cg(Cc(123), "max")
    local m = Ct(p1):match("")
    expect(m.min).is(421)
    expect(m.max).is(123)
    local p2 = p1 * Cg(
      Cb("min") / function (min) return min + 1 end,
      "max"
    )
    m = Ct(p2):match("")
    expect(m.min).is(421)
    expect(m.max).is(422)
  end,
  test_table = function (self)
    local p = P({
      "type",
      type = V("table") + P("abc"),
      table =
        P("table")   -- table<foo,bar>
      * P( PEG.get_spaced("<")
        * V("type")
        * PEG.comma
        * V("type")
        * PEG.get_spaced(">")
      )^-1,
    })
    expect((p * Cp()):match("table<abc,abc>")).is(15)
  end
})

_G.test_Info = function ()
  expect(AD.Info).is.NOT(nil)
  expect(AD.Info.__Class).is(AD.Info)
end

-- unused yet
function Test:ad_test(target, expected, content, index)
  self:add_strip(1)
  local m = self.p:match(target, index)
  expect(m).contains(expected)
  expect(m:get_content(target)).is(content)
  self:add_strip(-1)
end

_G.test_ShortLiteral = Test({
  test_base = function ()
    local t = AD.ShortLiteral()
    expect(t).contains(AD.ShortLiteral({
      min         = 1,
      content_min = 1,
      content_max = 0,
      max         = 0,
    }))
  end,
  setup = function (self)
    self.p = AD.ShortLiteral:get_capture_p()
  end,
  test = function (self)
    local s, t
    expect(self.p).is.NOT(nil)
    s = '"234"  \n  '
    ---@type AD.ShortLiteral
    t = self.p:match(s)
    expect(t).contains(AD.ShortLiteral({
      min = 1,
      content_min = 2,
      content_max = 4,
      max = 8,
    }))

    s = "'234'  \n  "
    t = self.p:match(s)
    expect(t).contains(AD.ShortLiteral({
      min         = 1,
      content_min = 2,
      content_max = 4,
      max         = 8,
    }))
  end
})

_G.test_LongLiteral = Test({
  test_base = function ()
    local t = AD.LongLiteral()
    expect(t).contains(AD.LongLiteral({
      min         = 1,
      content_min = 1,
      content_max = 0,
      max         = 0,
      level       = 0,
    }))
  end,
  setup = function (self)
    self.p = AD.LongLiteral:get_capture_p()
  end,
  test = function (self)
    local s, t
    s = '[[345]]  \n  '
    t = self.p:match(s)
    expect(t).contains(AD.LongLiteral({
      min         = 1,
      content_min = 3,
      content_max = 5,
      max         = 10,
      level       = 0,
    }))
    s = '[===[678]===]  \n  '
    t = self.p:match(s)
    expect(t).contains(AD.LongLiteral({
      min         = 1,
      content_min = 6,
      content_max = 8,
      max         = 16,
      level       = 3,
    }))
  end
})

_G.test_LineComment = Test({
  test_base = function ()
    local t = AD.LineComment()
    expect(t).contains(AD.LineComment({
      min         = 1,
      content_min = 1,
      content_max = 0,
      max         = 0,
    }))
  end,
  setup = function (self)
    self.p = AD.LineComment:get_capture_p()
  end,
  test = function (self)
    local t
    ---@type AD.LineComment
    t = self.p:match('-  \n  ')
    expect(t).is(nil)
    t = self.p:match('---  \n  ')
    expect(t).is(nil)
    t = self.p:match('---  \n  ', 2)
    expect(t).is(nil)

    t = self.p:match('--  ')
    expect(t).contains(AD.LineComment({
      min         = 1,
      content_min = 5,
      content_max = 4,
      max         = 4,
    }))

    t = self.p:match('--  \n  ')
    expect(t).contains(AD.LineComment({
      min         = 1,
      content_min = 5,
      content_max = 4,
      max         = 5,
    }))

    t = self.p:match('----------')
    expect(t).contains(AD.LineComment({
      min         = 1,
      content_min = 11,
      content_max = 10,
      max         = 10,
    }))

    t = self.p:match('-- 456 89A \n  ')
    expect(t).contains(AD.LineComment({
      min         = 1,
      content_min = 4,
      content_max = 10,
      max         = 12,
    }))
  end
})

_G.test_LongComment = Test({
  test_base = function ()
    local t = AD.LongComment()
    expect(t).contains(AD.LongComment({
      min         = 1,
      content_min = 1,
      content_max = 0,
      max         = 0,
      level       = 0,
    }))
  end,
  setup = function (self)
    self.p = AD.LongComment:get_capture_p()
  end,
  test = function (self)
    local s, t
    ---@type AD.LongComment
    t = self.p:match('--  \n  ')
    expect(t).is(nil)

    t = self.p:match('--[[56 89A]]')
    expect(t).contains(AD.LongComment({
      min         = 1,
      content_min = 5,
      content_max = 10,
      max         = 12,
      level       = 0,
    }))

    t = self.p:match('--[[\n6 89A]]')
    expect(t).contains(AD.LongComment({
      min         = 1,
      content_min = 6,
      content_max = 10,
      max         = 12,
      level       = 0,
    }))

    t = self.p:match('--[[\n  8\nA  ]]')
    expect(t).contains(AD.LongComment({
      min         = 1,
      content_min = 6,
      content_max = 10,
      max         = 14,
      level       = 0,
    }))

    t = self.p:match('--[==[78]=] \n ]==] ')
    expect(t).contains(AD.LongComment({
      min         = 1,
      content_min = 7,
      content_max = 13,
      max         = 19,
      level       = 2,
    }))
  end
})

_G.test_LineDoc = Test({
  test_base = function ()
    local t = AD.LineDoc()
    expect(t).contains(AD.LineDoc({
      min         = 1,
      content_min = 1,
      content_max = 0,
      max         = 0,
    }))
  end,
  setup = function (self)
    self.p = AD.LineDoc:get_capture_p()
  end,
  test = function (self)
    local s, t
    t = self.p:match('-- ')
    expect(t).is(nil)
    t = self.p:match('---- ')
    expect(t).is(nil)
    t = self.p:match('---- ', 1)
    expect(t).is(nil)

    t = self.p:match('---')
    expect(t).contains(AD.LineDoc({
      min         = 1,
      content_min = 4,
      content_max = 3,
      max         = 3,
    }))

    t = self.p:match('---456789A')
    expect(t).contains(AD.LineDoc({
      min         = 1,
      content_min = 4,
      content_max = 10,
      max         = 10,
    }))

    t = self.p:match('--- 56 89 ')
    expect(t).contains(AD.LineDoc({
      min         = 1,
      content_min = 5,
      content_max = 9,
      max         = 10,
    }))

    t = self.p:match('--- 56 89 \n')
    expect(t).contains(AD.LineDoc({
      min         = 1,
      content_min = 5,
      content_max = 9,
      max         = 11,
    }))

    s = [=====[
---456789
---456789
---456789
]=====]
    expect(self.p:match(s,  1).max).is(10)
    expect(self.p:match(s, 11).max).is(20)
    expect(self.p:match(s, 21).max).is(30)
    expect((self.p^2):match(s, 1)).is.NOT(nil)
    expect((self.p^2):match(s, 11)).is.NOT(nil)

    local TD = self.get_LINE_DOC()
    t = self.p:match(TD.s)
    expect(t).contains(TD.m())
  end
})

_G.test_LongDoc = Test({
  test_base = function ()
    local t = AD.LongDoc()
    expect(t).contains(AD.LongDoc({
      min         = 1,
      content_min = 1,
      content_max = 0,
      max         = 0,
    }))
  end,
  setup = function (self)
    self.p = AD.LongDoc:get_capture_p()
  end,
  test = function (self)
    local s, t
    t = self.p:match('-- ')
    expect(t).is(nil)
    t = self.p:match('--- ')
    expect(t).is(nil)
    t = self.p:match('--- ', 1)
    expect(t).is(nil)

    t = self.p:match('--[===[]===]')
    expect(t).contains(AD.LongDoc({
      min         = 1,
      content_min = 8,
      content_max = 7,
      max         = 12,
    }))

    t = self.p:match('--[===[89AB]===]')
    expect(t).contains(AD.LongDoc({
      min         = 1,
      content_min = 8,
      content_max = 11,
      max         = 16,
    }))

    t = self.p:match('--[===[09 B]===]')
    expect(t).contains(AD.LongDoc({
      min         = 1,
      content_min = 8,
      content_max = 11,
      max         = 16,
    }))

    t = self.p:match('--[===[09 B]===]\n')
    expect(t).contains(AD.LongDoc({
      min         = 1,
      content_min = 8,
      content_max = 11,
      max         = 17,
    }))

    local TD = self.get_LONG_DOC()
    t = self.p:match(TD.s)
    expect(t).contains(TD.m())
  end
})

_G.test_Description = Test({
  test_base = function ()
    local t = AD.Description()
    expect(t.__Class).is(AD.Description)
  end,
  setup = function (self)
    self.p = AD.Description:get_capture_p()
  end,
  test = function (self)
    local s, t
    t = self.p:match("--")
    expect(t).is(nil)

    expect(self.p:match("---\n--[===[]===]")).is.NOT(nil)

    ---@type AD.Description
    t = self.p:match("---")
    expect(t).contains(AD.Description({
      min   = 1,
      max   = 3,
      long  = {},
      short = AD.LineDoc({
        min   = 1,
        max   = 3,
      }),
    }))

    t = self.p:match("---\n")
    expect(t).contains(AD.Description({
      min   = 1,
      max   = 4,
      long  = {},
    }))

    t = self.p:match("---\ns")
    expect(t).contains(AD.Description({
      min   = 1,
      max   = 4,
      long  = {},
    }))


    t = self.p:match("---\n\n")
    expect(t).contains(AD.Description({
      min   = 1,
      max   = 4,
      long  = {},
    }))

    t = self.p:match("-- \n---")
    expect(t).is(nil)

    s = "---\n---"
    t = self.p:match(s)
    expect(t).contains(AD.Description({
      min   = 1,
      max   = 7,
      short = AD.LineDoc({
        min         = 1,
        content_min = 4,
        content_max = 3,
        max         = 4,
      }),
      long  = { AD.LineDoc({
        min         = 5,
        content_min = 8,
        content_max = 7,
        max         = 7,
      }) },
    }))

----5----0----5----0----5----0----5----0----5
    s = [=====[
---
--[[]]
]=====]
    t = self.p:match(s)
    expect(t).contains(AD.Description({
      min   = 1,
      max   = 11,
      short = AD.LineDoc({
        min         = 1,
        content_min = 4,
        content_max = 3,
        max         = 4,
      }),
      long  = {},
    }))

----5----0----5----0----5----0----5----0----5
s = [=====[
---
--[===[]===]
]=====]
    t = self.p:match(s)
    expect(t).contains(AD.Description({
      min   = 1,
      max   = 17,
      short = AD.LineDoc({
        min         = 1,
        content_min = 4,
        content_max = 3,
        max         = 4,
      }),
      long  = { AD.LongDoc({
        min         = 5,
        content_min = 12,
        content_max = 11,
        max         = 17,
      }) }
    }))

----5----0----5----0----5----0----5----0----5
s = [=====[
---
--[===[]===]
--
---
s   s
]=====]
    t = self.p:match(s)
    expect(t).contains(AD.Description({
      min   = 1,
      max   = 24,
      short = AD.LineDoc({
        min   = 1,
        content_min = 4,
        content_max = 3,
        max   = 4,
      }),
      long  = {
        AD.LongDoc({
          min   = 5,
          content_min = 12,
          content_max = 11,
          max   = 17,
        }),
        AD.LineDoc({
          min   = 21,
          content_min = 24,
          content_max = 23,
          max   = 24,
        })
      },
    }))
  end
})

_G.test_At_Author = Test({
  test_base = function ()
    local t = AD.At.Author()
    expect(t).contains( AD.At.Author({
      min         = 1,
      content_min = 1,
      content_max = 0,
      max         = 0,
    }) )
  end,
  setup = function (self)
    self.p = AD.At.Author:get_capture_p()
  end,
  test = function (self)
    local s, t
    --   ----5----0----5----0----5----0----5----0----5
    s = "---@author 9hat do you want of 30  "
    ---@type AD.At.Author
    t = self.p:match(s)
    expect(t).contains( AD.At.Author({
      min         = 1,
      content_min = 12,
      content_max = 33,
      max         = 35,
    }) )
    expect(t:get_content(s)).is("9hat do you want of 30")
  end,
  test_complete = function (self)
    self:do_test_complete("Author")
  end
})

_G.test_At_Field = Test({
  test_base = function ()
    local t = AD.At.Field()
    expect(t).contains(AD.At.Field({
      min         = 1,
      content_min = 1,
      content_max = 0,
      max         = 0,
    }))
  end,
  setup = function (self)
    self.p = AD.At.Field:get_capture_p()
  end,
  test = function (self)
    local s, t
    expect(
      function ()
        self.p:match("--- @field public foo")
      end
    ).error()

    expect(
      function ()
        self.p:match("--- @field public foo \n bar")
      end
    ).error()

    --   ----5----0----5----0----5----0
    s = "--- @field public f21 b25"
    ---@type AD.At.Field
    t = self.p:match(s)
    expect(t).contains(AD.At.Field({
      min         = 1,
      content_min = 26,
      content_max = 25,
      max         = 25,
      visibility  = "public",
      name        = "f21",
      types       = { "b25" },
    }))

    --   ----5----0----5----0----5----0----5
    s = "--- @field private f22 b26\n   "
    ---@type AD.At.Field
    t = self.p:match(s)
    expect(t).contains( AD.At.Field({
      min         = 1,
      content_min = 27,
      content_max = 26,
      max         = 27,
      visibility  = "private",
      name        = "f22",
      types       = { "b26" },
    }) )

    --   ----5----0----5----0----5----0----5----0----5
    s = "--- @field private f22 b26 @ commentai40   "
    t = self.p:match(s)
    expect(t).contains( AD.At.Field({
      min         = 1,
      content_min = 30,
      content_max = 40,
      max         = 43,
      visibility  = "private",
      name        = "f22",
      types       = { "b26" },
    }) )

    --   ----5----0----5----0----5----0----5----0----5
    s = "--- @field private f22 b26\n   "
    t = self.p:match(s)
    expect(t).contains( AD.At.Field({
      min         = 1,
      content_min = 27,
      content_max = 26,
      max         = 27,
      visibility  = "private",
      name        = "f22",
      types       = { "b26" },
    }) )

    --   ----5----0----5----0----5----0----5----0----5
    s = "123456789--- @field private f22 b26\n   "
    t = self.p:match(s, 10)
    expect(t).contains( AD.At.Field({
      min         = 10,
      content_min = 36,
      content_max = 35,
      max         = 36,
      visibility  = "private",
      name        = "f22",
      types       = { "b26" },
    }) )
  end,
  test_complete = function (self)
    self:do_test_complete("Field")
  end
})

_G.test_At_See = Test({
  test_base = function ()
    local t = AD.At.See()
    expect(t).contains( AD.At.See({
      min         = 1,
      content_min = 1,
      content_max = 0,
      max         = 0,
    }) )
  end,
  setup = function (self)
    self.p = AD.At.See:get_capture_p()
  end,
  test = function (self)
    local s, t
    --   ----5----0----5----0----5----0----5----0----5
    s = "---@see 9hat do you want of 30  "
    ---@type AD.At.See
    t = self.p:match(s)
    expect(t).contains( AD.At.See({
      min         = 1,
      content_min = 9,
      content_max = 30,
      max         = 32,
    }) )
    expect(t:get_content(s)).is("9hat do you want of 30")
  end,
  test_complete = function (self)
    self:do_test_complete("See")
  end
})

-- @class MY_TYPE[:PARENT_TYPE] [@comment]
_G.test_At_Class = Test({
  test_base = function (self)
    local t = AD.At.Class()
    expect(t).contains( AD.At.Class({
      min         = 1,
      content_min = 1,
      content_max = 0,
      max         = 0,
    }) )
  end,
  setup = function (self)
    self.p = AD.At.Class:get_capture_p()
  end,
  test = function (self)
    local s, t
    --   ----5----0----5----0----5----0----5----0----5
    s = "---@class MY_TY17"
    ---@type AD.At.Class
    t = self.p:match(s)

    expect(t.__Class).is(AD.At.Class)
    expect(t).contains( AD.At.Class({
      min         = 1,
      content_min = 18,
      content_max = 17,
      max         = 17,
    }) )
    expect(t.parent).is(nil)

    --   ----5----0----5----0----5----0----5----0----5
    s = "---@class AY_TYPE: PARENT_TY30"
    ---@type AD.At.Class
    t = self.p:match(s)
    expect(t).contains( AD.At.Class({
      min         = 1,
      content_min = 31,
      content_max = 30,
      max         = 30,
      name        = "AY_TYPE",
      parent      = "PARENT_TY30",
    }) )

    local TD = self.get_CLASS()
    ---@type AD.At.Class
    t = self.p:match(TD.s)
    expect(t).contains(TD.m())
    expect(t:get_comment(TD.s)).is(TD.c)
  end,
  test_complete = function (self)
    self:do_test_complete("Class")

    local p = AD.At.Class:get_complete_p()

    local TD_CLASS = self:get_CLASS()
    local TD_FIELD = self:get_FIELD()
    local TD_AUTHOR = self:get_AUTHOR()
    local s = TD_CLASS.s .. TD_FIELD.s .. TD_AUTHOR.s
    local t = p:match(s)
    expect(t).is.NOT(nil)
    expect(t.fields).contains({
      TD_FIELD.m(1 + TD_CLASS.m().max)
    })
    expect(t.author).contains(
      TD_AUTHOR.m(
        1 + TD_FIELD.m(1 + TD_CLASS.m().max).max
      )
    )

    local TD = self.get_CLASS_COMPLETE()
    expect(p:match(TD.s)).contains(TD.m())
  end,

})

_G.test_At_Type = Test({
  test_base = function ()
    local t = AD.At.Type()
    expect(t).contains( AD.At.Type({
      min         = 1,
      content_min = 1,
      content_max = 0,
      max         = 0,
    }) )
  end,
  setup = function (self)
    self.p = AD.At.Type:get_capture_p()
  end,
  test = function (self)
    local s, t
----5----0----5----0----5----0----5----0
    s = [=====[
---@type MY_TYPE]=====]
    ---@type AD.At.Type
    t = self.p:match(s)
    expect(t).contains( AD.At.Type({
      min = 1,
      content_min = 17,
      content_max = 16,
      max = 16,
      types = { "MY_TYPE" },
    }) )

----5----0----5----0----5----0----5----0
    s = [=====[
---@type MY_TYPE|OTHER_TYPE]=====]
    ---@type AD.At.Type
    t = self.p:match(s)
    expect(t).contains( AD.At.Type({
      min = 1,
      content_min = 28,
      content_max = 27,
      max = 27,
      types = { "MY_TYPE", "OTHER_TYPE" },
    }) )

----5----0----5----0----5----0----5----0
    s = [=====[
---@type MY_TYPE|OTHER_TYPE @ COMMENT ]=====]
    ---@type AD.At.Type
    t = self.p:match(s)
    expect(t).contains( AD.At.Type({
      min = 1,
      content_min = 31,
      content_max = 37,
      max = 38,
      types = { "MY_TYPE", "OTHER_TYPE" },
    }) )
    expect(t:get_content(s)).is("COMMENT")

    local TD = self.get_TYPE()
    ---@type AD.At.Type
    t = self.p:match(TD.s)
    expect(t).contains(TD.m())
    expect(t:get_comment(TD.s)).is(TD.c)
  end,
  test_complete = function (self)
    self:do_test_complete("Type")
  end,
})

_G.test_At_Alias = Test({
  test_base = function ()
    local t = AD.At.Alias()
    expect(t).contains( AD.At.Alias({
      min         = 1,
      content_min = 1,
      content_max = 0,
      max         = 0,
    }) )
  end,
  setup = function (self)
    self.p = AD.At.Alias:get_capture_p()
  end,
  test = function (self)
    local s, t
----5----0----5----0----5----0----5----0
s = [=====[
---@alias NEW_NAME TYPE ]=====]
    ---@type AD.At.Alias
    t = self.p:match(s)
    expect(t).contains( AD.At.Alias({
      min         = 1,
      content_min = 24,
      content_max = 23,
      max         = 24,
      name        = "NEW_NAME",
      types       = { "TYPE" },
    }) )

----5----0----5----0----5----0----5----0
    s = [=====[
---@alias NEW_NAME TYPE | OTHER_TYPE ]=====]
    t = self.p:match(s)
    expect(t).contains( AD.At.Alias({
      min         = 1,
      content_min = 37,
      content_max = 36,
      max         = 37,
      name        = "NEW_NAME",
      types       = { "TYPE", "OTHER_TYPE" },
    }) )

    ----5----0----5----0----5----0----5----0----5----
    s = [=====[
---@alias     NAME TYPE @ SOME   COMMENT]=====]
    t = self.p:match(s)
    expect(t).contains( AD.At.Alias({
      min         = 1,
      content_min = 27,
      content_max = 40,
      max         = 40,
      name        = "NAME",
      types       = { "TYPE" },
    }) )
    expect(t:get_comment(s)).is("SOME   COMMENT")

----5----0----5----0----5----0----5----0----5----
    s = [=====[
---@alias     NAME TYPE @ SOME   COMMENT         
    SUITE                                        ]=====]
    t = self.p:match(s)
    expect(t).contains( AD.At.Alias({
      min         = 1,
      content_min = 27,
      content_max = 40,
      max         = 50,
      name        = "NAME",
      types       = { "TYPE" },
    }) )
    expect(t:get_comment(s)).is("SOME   COMMENT")
  end,
  test_TD = function (self)
    self:do_test_TD("Alias")
  end,
  test_complete = function (self)
    self:do_test_complete("Alias")
  end,
})

_G.test_At_Param = Test({
  test_base = function ()
    local t = AD.At.Param()
    expect(t).contains( AD.At.Param({
      min         = 1,
      content_min = 1,
      content_max = 0,
      max         = 0,
    }) )
  end,
  setup = function (self)
    self.p = AD.At.Param:get_capture_p()
  end,
  test = function (self)
    local s, t
----5----0----5----0----5----0----5----0----5----
    s = [=====[
---@param NAME TYPE]=====]
    ---@type AD.At.Param
    t = self.p:match(s)
    expect(t).contains( AD.At.Param({
      min         = 1,
      content_min = 20,
      content_max = 19,
      max         = 19,
      name        = "NAME",
      optional    = false,
      types       = { "TYPE" },
    }) )
    expect(t:get_comment(s)).is("")

----5----0----5----0----5----0----5----0----5----
    s = [=====[
---@param NAME ? TYPE]=====]
    ---@type AD.At.Param
    t = self.p:match(s)
    expect(t).contains( AD.At.Param({
      min         = 1,
      content_min = 22,
      content_max = 21,
      max         = 21,
      name        = "NAME",
      optional    = true,
      types       = { "TYPE" },
    }) )
    expect(t:get_comment(s)).is("")

----5----0----5----0----5----0----5----0----5----
    s = [=====[
---@param NAME TYPE
]=====]
    ---@type AD.At.Param
    t = self.p:match(s)
    expect(t).contains( AD.At.Param({
      min         = 1,
      content_min = 20,
      content_max = 19,
      max         = 20,
      name        = "NAME",
      optional    = false,
      types       = { "TYPE" },
    }) )
    expect(t:get_comment(s)).is("")

----5----0----5----0----5----0----5----0----5----
s = [=====[
---@param NAME ? TYPE
]=====]
  ---@type AD.At.Param
  t = self.p:match(s)
  expect(t).contains( AD.At.Param({
    min         = 1,
    content_min = 22,
    content_max = 21,
    max         = 22,
    name        = "NAME",
    optional    = true,
    types       = { "TYPE" },
  }) )
  expect(t:get_comment(s)).is("")

----5----0----5----0----5----0----5----0----5----
    s = [=====[
---@param NAME TYPE  |  OTHER
]=====]
    ---@type AD.At.Param
    t = self.p:match(s)
    expect(t).contains( AD.At.Param({
      min         = 1,
      content_min = 30,
      content_max = 29,
      max         = 30,
      name        = "NAME",
      optional    = false,
      types       = { "TYPE", "OTHER" },
    }) )
    expect(t:get_comment(s)).is("")

----5----0----5----0----5----0----5----0----5----
    s = [=====[
---@param NAME TYPE  |  OTHER@  COMMENT
]=====]
    ---@type AD.At.Param
    t = self.p:match(s)
    expect(t).contains( AD.At.Param({
      min         = 1,
      content_min = 33,
      content_max = 39,
      max         = 40,
      name        = "NAME",
      optional    = false,
      types       = { "TYPE", "OTHER" },
    }) )
    expect(t:get_comment(s)).is("COMMENT")
  end,
  test_TD = function (self)
    self:do_test_TD("Param")
  end,
  test_complete = function (self)
    self:do_test_complete("Param")
  end,
})

_G.test_At_Return = Test({
  test_base = function ()
    local t = AD.At.Return()
    expect(t.__Class).is(AD.At.Return)
    expect(t).contains({
      min         = 1,
      max         = 0,
      content_min = 1,
      content_max = 0,
    })
  end,
  setup = function (self)
    self.p = PEG.chunk_init
      * AD.At.Return:get_capture_p()
  end,
  test = function (self)
    local s, t
----5----0----5----0----5----0----5----0----5----
    s = [=====[
---   @return TYPE   |  OTHER @ COMMENT
]=====]
    t = self.p:match(s)
    expect(t).contains({
      min         = 1,
      max         = 40,
      content_min = 33,
      content_max = 39,
      types       = { "TYPE", "OTHER" },
    })
    expect(t:get_comment(s)).is("COMMENT")
----5----0----5----0----5----0----5----0----5----
    s = [=====[
---   @return TYPE? @ COMMENT
]=====]
    t = self.p:match(s)
    expect(t).contains({
      min         = 1,
      max         = 30,
      content_min = 23,
      content_max = 29,
      types       = { "TYPE" },
      optional    = true,
    })
    expect(t:get_comment(s)).is("COMMENT")
    end,
  test_TD = function (self)
    self:do_test_TD("Return")
  end,
  test_complete = function (self)
    self:do_test_complete("Return")
  end,
})

_G.test_At_Generic = Test({
  test_base = function ()
    local t = AD.At.Generic()
    expect(t.__Class).is(AD.At.Generic)
    expect(t).contains({
      min         = 1,
      max         = 0,
      content_min = 1,
      content_max = 0,
    })
  end,
  setup = function (self)
    self.p = PEG.chunk_init
      * AD.At.Generic:get_capture_p()
  end,
  test = function (self)
    local s, t
    s = [=====[
---@generic T1
]=====]
    ---@type AD.At.Generic
    t = self.p:match(s)
    expect(t.type_1).is.equal.to("T1")
    expect(t.parent_1).is(nil)
    expect(t.type_2).is(nil)
    expect(t.parent_2).is(nil)

    s = [=====[
---@generic T1: PARENT_TYPE_1
]=====]
    t = self.p:match(s)
    expect(t.type_1).is.equal.to("T1")
    expect(t.parent_1).is.equal.to("PARENT_TYPE_1")

    s = [=====[
---@generic T1, T2
]=====]
    t = self.p:match(s)
    expect(t.type_1).is.equal.to("T1")
    expect(t.parent_1).is(nil)
    expect(t.type_2).is.equal.to("T2")
    expect(t.parent_2).is(nil)

    s = [=====[
---@generic T1 : PARENT_TYPE, T2
]=====]
    t = self.p:match(s)
    expect(t.type_1).is.equal.to("T1")
    expect(t.parent_1).is("PARENT_TYPE")
    expect(t.type_2).is.equal.to("T2")
    expect(t.parent_2).is(nil)

    s = [=====[
---@generic T1, T2 : PARENT_TYPE
]=====]
    t = self.p:match(s)
    expect(t.type_1).is.equal.to("T1")
    expect(t.parent_1).is(nil)
    expect(t.type_2).is.equal.to("T2")
    expect(t.parent_2).is("PARENT_TYPE")

    s = [=====[
---@generic T1 : PARENT_TYPE, T2 : PARENT_TYPE
]=====]
    t = self.p:match(s)
    expect(t.type_1).is.equal.to("T1")
    expect(t.parent_1).is("PARENT_TYPE")
    expect(t.type_2).is.equal.to("T2")
    expect(t.parent_2).is("PARENT_TYPE")

    ----5----0----5----0----5----0----5----0----5----0----5----
    s = [=====[
---@generic   T1 : PARENT_TYPE, T2 : PARENT_TYPE @  COMMENT
]=====]
    t = self.p:match(s)
    expect(t.type_1).is.equal.to("T1")
    expect(t.parent_1).is("PARENT_TYPE")
    expect(t.type_2).is.equal.to("T2")
    expect(t.parent_2).is("PARENT_TYPE")
    expect(t:get_content(s)).is("COMMENT")
    expect(t.min).is(1)
    expect(t.max).is(60)
  end,
  test_TD = function (self)
    self:do_test_TD("Generic")
  end,
  test_complete = function (self)
    self:do_test_complete("Generic")
  end,
})

_G.test_At_Vararg = Test({
  test_base = function ()
    local t = AD.At.Vararg()
    expect(t).contains( AD.At.Vararg({
      min         = 1,
      content_min = 1,
      content_max = 0,
      max         = 0,
    }) )
  end,
  setup = function (self)
    self.p = AD.At.Vararg:get_capture_p()
  end,
  test = function (self)
    local s, t
----5----0----5----0----5----0----5----0----5----0----5----
    s = [=====[
---@vararg    TYPE_
]=====]
    ---@type AD.At.Vararg
    t = self.p:match(s)
    expect(t).contains( AD.At.Vararg({
      min         = 1,
      content_min = 20,
      content_max = 19,
      max         = 20,
      types       = { "TYPE_" },
    }) )
    expect(t:get_comment(s)).is("")

----5----0----5----0----5----0----5----0----5----0----5----
    s = [=====[
---@vararg    TYPE_|TYPE
]=====]
    ---@type AD.At.Vararg
    t = self.p:match(s)
    expect(t).contains( AD.At.Vararg({
      min         = 1,
      content_min = 25,
      content_max = 24,
      max         = 25,
      types       = { "TYPE_", "TYPE" },
    }) )
    expect(t:get_comment(s)).is("")

----5----0----5----0----5----0----5----0----5----0----5----
    s = [=====[
---@vararg    TYPE_|TYPE@CMT_
]=====]
    ---@ype AD.At.Vararg
    t = self.p:match(s)
    expect(t).contains( AD.At.Vararg({
      min         = 1,
      content_min = 26,
      content_max = 29,
      max         = 30,
      types       = { "TYPE_", "TYPE" },
    }) )
    expect(t:get_content(s)).is("CMT_")
  end,
  test_TD = function (self)
    self:do_test_TD("Vararg")
  end,
  test_complete = function (self)
    self:do_test_complete("Vararg")
  end,
})

_G.test_At_Module = Test({
  test_base = function ()
    local t = AD.At.Module()
    expect(t).contains( AD.At.Module({
      min         = 1,
      content_min = 1,
      content_max = 0,
      max         = 0,
    }) )
  end,
  setup = function (self)
    self.p = AD.At.Module:get_capture_p()
  end,
  test = function (self)
    local s, t
----5----0----5----0----5----0----5----0----5----0----5----
    s = [=====[
---   @module name_
]=====]
    ---@type AD.At.Module
    t = self.p:match(s)
    expect(t).contains( AD.At.Module({
      min         = 1,
      content_min = 20,
      content_max = 19,
      max         = 20,
      name        = "name_",
    }) )
    expect(t:get_comment(s)).is("")

----5----0----5----0----5----0----5----0----5----0----5----
    s = [=====[
---   @module name_ @ COMMENT
]=====]
    t = self.p:match(s)
    expect(t).contains( AD.At.Module({
      min         = 1,
      content_min = 23,
      content_max = 29,
      max         = 30,
      name        = "name_",
    }) )
    expect(t:get_comment(s)).is("COMMENT")

  end,
  test_TD = function (self)
    self:do_test_TD("Module")
  end,
  test_complete = function (self)
    self:do_test_complete("Module")

----5----0----5----0----5----0----5----0----5----0----5----
  local s = [=====[
---@module my_module
---@author my_pseudo
]=====]
    local p = AD.At.Module:get_complete_p()
    local t = p:match(s)
    expect(t).contains( AD.At.Module({
      min         = 1,
      content_min = 21,
      content_max = 20,
      max         = 42,
      name        = "my_module",
    }) )
    expect(t.author).contains( AD.At.Author({
      min         = 22,
      content_min = 33,
      content_max = 41,
      max         = 42,
    }) )
    expect(t:get_comment(s)).is("")
    expect(t.author:get_content(s)).is("my_pseudo")
    end,
})

_G.test_At_Function = Test({
  test_base = function ()
    local t = AD.At.Function()
    expect(t).contains( AD.At.Function({
      min         = 1,
      content_min = 1,
      content_max = 0,
      max         = 0,
    }) )
  end,
  setup = function (self)
    self.p = AD.At.Function:get_capture_p()
  end,
  test = function (self)
    local s, t
---5----0----5----0----5----0----5----0----5----0----5----
    s = [=====[
---@function  name_
]=====]
    t = self.p:match(s)
    expect(t).contains({
      min = 1,
      max = 20,
      name = "name_",
    })
---5----0----5----0----5----0----5----0----5----0----5----
    s = [=====[
---@function  name_ @ COMMENT
]=====]
    t = self.p:match(s)
    expect(t).contains({
      min         = 1,
      max         = 30,
      content_min = 23,
      content_max = 29,
      name        = "name_",
    })
    expect(t:get_comment(s)).is("COMMENT")
  end,
  test_TD = function (self)
    self:do_test_TD("Function")
  end,
  test_complete = function (self)
    self:do_test_complete("Function")

    local p = AD.At.Function:get_complete_p()

    local TD = self.get_PARAM()
    expect(p:match(TD.s)).contains({
      ID          = AD.At.Function.ID,
      max         = 46,
      params      = {
        {
          ID          = AD.At.Param.ID,
          min         = 1,
          content_min = 35,
          content_max = 45,
          max         = 46,
          name        = "NAME",
          optional    = false,
          types       = {
            "TYPE",
            "OTHER",
          },
        }
      },
    })

    TD = self.get_FUNCTION_COMPLETE()
    expect(p:match(TD.s)).contains(TD.m())
  end,
})

_G.test_At_Break = Test({
  test_base = function ()
    local t = AD.Break()
    expect(t).contains( AD.Break({
      min         = 1,
      max         = 0,
    }) )
  end,
  setup = function (self)
    self.p = AD.Break:get_capture_p()
  end,
  test = function (self)
    ---@type AD.Break
    local t = self.p:match("\n")
    self:p_test("", nil)
    expect(t).contains({
      min = 1,
      max = 1,
    })
    t = self.p:match(" \n ")
    expect(t).contains({
      min = 1,
      max = 3,
    })
    t = self.p:match(" \n \n")
    expect(t).contains({
      min = 1,
      max = 4,
    })
  end,
})

_G.test_At_Global = Test({
  test_base = function ()
    local t = AD.At.Global()
    expect(t).contains( AD.At.Global({
      min         = 1,
      content_min = 1,
      content_max = 0,
      max         = 0,
    }) )
  end,
  setup = function (self)
    self.p = AD.At.Global:get_capture_p()
  end,
  test = function (self)
----5----0----5----0----5----0----5----0----5----0----5----
    local s, t
    s = [=====[
---  @global  name_
]=====]
    ---@type AD.At.Global
    t = self.p:match(s)
    expect(t).contains({
      min = 1,
      max = 20,
      name = "name_",
    })

---5----0----5----0----5----0----5----0----5----0----5----
    s = [=====[
---  @global  name_ @ COMMENT
]=====]
    t = self.p:match(s)
    expect(t).contains({
      min = 1,
      max = 30,
      name = "name_",
    })
    expect(t:get_comment(s)).is("COMMENT")
----5----0----5----0----5----0----5----0----5----0----5----
    s = [=====[
---   @global NAME TYPE @ CMT
]=====]
    t = self.p:match(s)
    expect(t).contains({
      min = 1,
      content_min = 27,
      content_max = 29,
      max = 30,
      name = "NAME",
      types = { "TYPE" }
    })
    expect(t:get_comment(s)).is("CMT")
  end,
  test_TD = function (self)
    self:do_test_TD("Global")
  end,
  test_complete = function (self)
    self:do_test_complete("Global")

    local p = AD.At.Global:get_complete_p()
    local TD = self:get_GLOBAL_COMPLETE()
    expect(p:match(TD.s)).contains(TD.m())
  end,
})

Test.STANDARD_ITEMS = {
  "LINE_DOC",
  "LONG_DOC",
  "FIELD",
  "SEE",
  "CLASS",
  "TYPE",
  "MODULE",
  "ALIAS",
  -- "PARAM",
  -- "GENERIC",
  -- "VARARG",
  -- "RETURN",
  "FUNCTION",
  "GLOBAL",
}
Test.FUNCTION_ITEMS = {
  PARAM = true,
  GENERIC = false,
  VARARG = false,
  RETURN = true,
}
_G.test_loop_p = Test({
  setup = function (self)
    self.p = __.loop_p
  end,
  test_standard_items = function (self)
    for _, KEY in ipairs(self.STANDARD_ITEMS) do
      local f = self["get_".. KEY]
      local TD = f(self)
      local m = self.p:match(TD.s)
      expect(m).contains(TD.m())
      if TD.c and m.get_content then
        expect(m:get_content(TD.s)).is(TD.c)
      end
    end
  end,
  test_function_items = function (self)
    -- to one attributes
    for KEY, multi in pairs(self.FUNCTION_ITEMS) do
      local f = self["get_".. KEY]
      local TD = f(self)
      local m = self.p:match(TD.s)
      local key = multi
        and KEY:lower() .."s"
        or  KEY:lower()
      expect(m).contains({
        ID          = AD.At.Function.ID,
        max         = TD.m().max,
        [key]       = multi and { TD.m() } or TD.m(),
      })
    end
  end,
})

_G.test_Source = Test({
  test_base = function ()
    local t = AD.Source()
    expect(t).contains( AD.Source() )
  end,
  setup = function (self)
    self.p = AD.Source:get_capture_p()
  end,
  test_standard_items = function (self)
    for _, KEY in ipairs(self.STANDARD_ITEMS) do
      local f = self["get_".. KEY]
      local TD = f(self)
      local m = self.p:match(TD.s)
      expect(m).contains({
        ID = AD.Source.ID,
        infos = { TD.m() },
      })
    end
  end,
  test_function_items = function (self)
    for KEY, multi in pairs(self.FUNCTION_ITEMS) do
      local f = self["get_".. KEY]
      local TD = f(self)
      local m = self.p:match(TD.s)
      local key = multi
        and KEY:lower() .."s"
        or  KEY:lower()
      expect(m).contains({
        ID = AD.Source.ID,
        infos = { {
          ID          = AD.At.Function.ID,
          max         = TD.m().max,
          [key]       = multi and { TD.m() } or TD.m(),
        } },
      })
    end
  end,
  test_two_items = function (self)
    for _, KEY_1 in ipairs(self.STANDARD_ITEMS) do
      local f_1 = self["get_".. KEY_1]
      local TD_1 = f_1(self)
      for _, KEY_2 in ipairs(self.STANDARD_ITEMS) do
        local f_2 = self["get_".. KEY_2]
        local TD_2 = f_2(self)
        local m = self.p:match(TD_1.s .. TD_2.s)
        -- do not test when items are combined into one
        if #m.infos == 2 then
          expect(m).contains({
            ID = AD.Source.ID,
            infos = {
              TD_1.m(),
              TD_2.m(1 + TD_1.m().max)
            },
          })
        end
      end
    end
  end,
})

_G.test_autodoc = Test({
  setup = function (self)
    self.p = AD.Source:get_capture_p()
  end,
  test = function (self)
    local fh =  io.open(AUTODOC_PATH)
    local s = fh:read("a")
    fh:close()
    local m = self.p:match(s)
    expect(#m.infos>0).is(true)
  end,
})

_G.test_autodoc_Module = Test({
  setup = function (self)
    self.module = AD.Module({
      file_path = AUTODOC_PATH,
    })
  end,
  test_base = function (self)
    expect(self.module.__infos).contains({})
    expect(self.module.__globals).contains({})
    expect(self.module.__functions).contains({})
    expect(self.module.__classes).contains({})
  end,
  test_function_name = function (self)
    for info in self.module.__all_infos do
      if info:is_instance_of(AD.At.Function) then
        -- all function names have been properly guessed:
        expect(info.name).is.NOT(AD.At.Function.name)
      end
    end
  end,
  test_module_name = function (self)
    expect(self.module.name).is.NOT(AD.Module.name)
    expect(self.module.file_path).is(AUTODOC_PATH)
    expect(self.module.name).is(AUTODOC_NAME)
  end,
  test_class_names = function (self)
    local module = self.module
    for name in module.all_class_names do
      local info = module:get_class(name)
      expect(info.name).is(name)
    end
  end,
  test_all_fun_names = function (self)
    local module = self.module
    for name in module.all_fun_names do
      local info = module:get_fun(name)
      expect(info.name).is(name)
    end
  end,
  test_function_param_names = function (self)
    local module = self.module
    for function_name in module.all_fun_names do
      ---@type AD.Function
      local info = module:get_fun(function_name)
      for param_name in info.all_param_names do
        local param = info:get_param(param_name)
        expect(param.name).is(param_name)
      end
    end
  end,
  test_global_names = function (self)
    local module = self.module
    for name in module.all_global_names do
      local info = module:get_global(name)
      expect(info.name).is(name)
    end
  end,
})

_G.test_Module = Test({
  prepare = function (self, str)
    self.module = AD.Module({
      file_path = AUTODOC_PATH,
      foo = "bar",
      contents = str
    })
  end,
  test_global_names = function (self)
    local s = [[
---@global NAME_1
---@global NAME_2
---@type string
whatever
---@type boolean
_G.NAME_3 = false
]]
    self:prepare(s)
    local iterator = self.module.all_global_names
    expect(iterator()).is("NAME_1")
    expect(iterator()).is("NAME_2")
    expect(iterator()).is("NAME_3")
    expect(iterator()).is(nil)
    for global_name in self.module.all_global_names do
      local g_info = self.module:get_global(global_name)
      expect(g_info.name).is(global_name)
    end
  end,
  test_class_names = function (self)
    local s = [[
---@class NAME_1
---@class NAME_2
---@type string
whatever
---@class NAME_3
]]
    self:prepare(s)
    local iterator = self.module.all_class_names
    expect(iterator()).is("NAME_1")
    expect(iterator()).is("NAME_2")
    expect(iterator()).is("NAME_3")
    expect(iterator()).is(nil)
  end,
  test_all_fun_names = function (self)
----5----0----5----0
    local s = [[
---@function NAME_1
---@function NAME_2
whatever          X
---@param foo   int
local function NAME_3()
---@return int
function PKG.NAME_4()
---@param foo   int
local NAME_5 = function ()
---@return int
PKG.NAME_6 = function ()
]]
    self:prepare(s)
    local iterator = self.module.all_fun_names
    expect(iterator()).is("NAME_1")
    expect(iterator()).is("NAME_2")
    expect(iterator()).is("NAME_3")
    expect(iterator()).is("PKG.NAME_4")
    expect(iterator()).is("NAME_5")
    expect(iterator()).is("PKG.NAME_6")
    expect(iterator()).is(nil)
  end,
  test_Global = function (self)
    local TD = self.get_GLOBAL_COMPLETE()
    local s = TD.s
    self:prepare(s)
    local g_info = self.module:get_global("NAME")
    expect(g_info).is.NOT(nil)
    expect(g_info).Class(AD.Global)
    expect(g_info.name).is("NAME")
    expect(g_info.short_description)
      .is("GLOBAL:  SHORT DESCRIPTION")
    expect(g_info.long_description)
      .is("GLOBAL:  LONG  DESCRIPTION")
    expect(g_info.comment)
      .is("GLOBAL: CMT")
    local type = g_info._type
    expect(type).is.NOT(nil)
    expect(type.comment)
      .is("TYPE: COMMENT")
    expect(type.short_description)
      .is("TYPE:    SHORT DESCRIPTION")
    expect(type.long_description)
      .is("TYPE:    LONG  DESCRIPTION")
    expect(type.types)
      .is("TYPE")
    expect(g_info.types)
      .is("TYPE")
----5----0----5----0----5---30
    s = [[
---TYPE:    SHORT DESCRIPTION
-- TYPE:    IGNORED DESCR5N 1
---TYPE:    LONG  DESCRIPTION
-- TYPE:    IGNORED DESCR5N 2
---@type TYPE @ TYPE: COMMENT
_G.foo = bar
]]
    self:prepare(s)
    expect(self.module.all_global_names()).is("foo")
    g_info = self.module:get_global("foo")
    expect(g_info).NOT(nil)
    expect(g_info).Class(AD.Global)
    expect(g_info.name).is("foo")
    expect(g_info.short_description)
      .is("TYPE:    SHORT DESCRIPTION")
    expect(g_info.long_description)
      .is("TYPE:    LONG  DESCRIPTION")
    expect(g_info.comment)
      .is("TYPE: COMMENT")
  end,
  test_Class = function (self)
    local TD = self.get_CLASS_COMPLETE()
    local s = TD.s
    self:prepare(s)
    local c_info = self.module:get_class("NAME")
    expect(c_info).is.NOT(nil)
    expect(c_info.__Class).is(AD.Class)
    expect(c_info.__fields).contains({})
    local field_1 = c_info:get_field("FIELD_1")
    expect(field_1).is.NOT(nil)
    expect(field_1.comment)
      .is("FIELD_1: CMT")
    expect(field_1.short_description)
      .is("FIELD_1: SHORT DESCRIPTION")
    expect(field_1.long_description )
      .is("FIELD_1: LONG  DESCRIPTION")
    expect(field_1.types)
      .is("TYPE_1")
    expect(field_1.visibility)
      .is("protected")
    local field_2 = c_info:get_field("FIELD_2")
    expect(field_2).is.NOT(nil)
    expect(field_2.comment)
      .is("FIELD_2: CMT")
    expect(field_2.short_description)
      .is("FIELD_2: SHORT DESCRIPTION")
    expect(field_2.long_description )
      .is("FIELD_2: LONG  DESCRIPTION")
    expect(field_2.types)
      .is("TYPE_2")
    expect(field_2.visibility)
      .is("protected")
      local author = c_info.author
      expect(author).is.NOT(nil)
      expect(author.value)
        .is("PSEUDO IDENTIFIER")
      expect(author.short_description)
        .is("AUTHOR:  SHORT DESCRIPTION")
      expect(author.long_description )
        .is("AUTHOR:  LONG  DESCRIPTION")
      local see = c_info.see
      expect(see).is.NOT(nil)
      expect(see.value)
        .is("VARIOUS REFERENCES")
      expect(see.short_description)
        .is("SEE:     SHORT DESCRIPTION")
      expect(see.long_description )
        .is("SEE:     LONG  DESCRIPTION")
  end,
  test_Class_field_names = function (self)
    local s = [[
---@class CLASS.NAME
---@field public FIELD_1 TYPE_1
---@field public FIELD_2 TYPE_2
]]
    self:prepare(s)

    local c_info = self.module:get_class("CLASS.NAME")
    expect(c_info).NOT(nil)
    local iterator = c_info.all_field_names
    expect(iterator()).is("FIELD_1")
    expect(iterator()).is("FIELD_2")
    expect(iterator()).is(nil)
  end,
  test_Function = function (self)
    local TD = self.get_FUNCTION_COMPLETE()
    local s = TD.s
    self:prepare(s)
    local f_info = self.module:get_fun("NAME")
    expect(f_info).is.NOT(nil)
    expect(f_info.__Class).is(AD.Function)
    expect(f_info.__params).contains({})
    local param_1 = f_info:get_param("PARAM_1")
    expect(param_1).is.NOT(nil)
    expect(param_1.comment)
      .is("PARAM_1: CMT")
    expect(param_1.short_description)
      .is("PARAM_1: SHORT DESCRIPTION")
    expect(param_1.long_description )
      .is("PARAM_1: LONG  DESCRIPTION")
    expect(param_1.types)
      .is("string")
    local param_2 = f_info:get_param("PARAM_2")
    expect(param_2).is.NOT(nil)
    expect(param_2.comment)
      .is("PARAM_2: CMT")
    expect(param_2.short_description)
      .is("PARAM_2: SHORT DESCRIPTION")
    expect(param_2.long_description )
      .is("PARAM_2: LONG  DESCRIPTION")
    expect(param_2.types)
      .is("string")
    local vararg = f_info.vararg
    expect(vararg).NOT(nil)
    expect(vararg.comment)
      .is("VARARG:     COMMENT")
    expect(vararg.short_description)
      .is("VARARG:  SHORT DESCRIPTION")
    expect(vararg.long_description )
      .is("VARARG:  LONG  DESCRIPTION")
    expect(vararg.types)
      .is("string")
    local return_1 = f_info:get_return(1)
    expect(return_1).is.NOT(nil)
    expect(return_1.comment)
      .is("RETURN_1:  COMMENT")
    expect(return_1.short_description)
      .is("RETURN_1: SHORT DESCRIPT2N")
    expect(return_1.long_description )
      .is("RETURN_1: LONG DESCRIPTION")
    expect(return_1.types)
      .is("string")
    local return_2 = f_info:get_return(2)
    expect(return_2).is.NOT(nil)
    expect(return_2.comment)
      .is("RETURN_2:  COMMENT")
    expect(return_2.short_description)
      .is("RETURN_2: SHORT DESCRIPT2N")
    expect(return_2.long_description )
      .is("RETURN_2: LONG DESCRIPTION")
    expect(return_2.types)
      .is( "boolean" )
  end,
})

_G.test_Module_2 = Test({
  prepare = function (self, str)
    self.module = AD.Module({
      file_path = AUTODOC_PATH,
      contents = str
    })
  end,
  test_class_base = function (self)
    local p = PEG.class_base
    expect(p:match("a")).is(nil)
    expect(p:match("a.b")).contains({
      class = "a",
      base  = "b",
    })
    expect(p:match("a.b.c")).contains({
      class = "a.b",
      base  = "c",
    })
    expect(p:match("a.b:c")).contains({
      class = "a.b",
      base  = "c",
    })
  end,
  test_method = function (self)
    local s = [[
---@class CLASS.NAME_1
---@field public METHOD fun()
---@class CLASS.NAME_2
---@field public METHOD fun()
---@function CLASS.NAME_1.METHOD_1
---@function CLASS.NAME_1.METHOD_2
---@function CLASS.NAME_1.SUB.METHOD_1
---@function CLASS.NAME_1.SUB.METHOD_2
---@function CLASS.NAME_2.METHOD_1
---@function CLASS.NAME_2.METHOD_2
---@function CLASS.NAME_2.SUB.METHOD_1
---@function CLASS.NAME_2.SUB.METHOD_2
]]
    self:prepare(s)
    local c_info = self.module:get_class("CLASS.NAME_1")
    local iterator = c_info.all_method_names
    expect(iterator()).is("METHOD_1")
    expect(iterator()).is("METHOD_2")
    expect(iterator()).is(nil)
    local m_info = c_info:get_method("METHOD_1")
    expect(m_info).Class.is(AD.Method)
    expect(m_info.name).is("CLASS.NAME_1.METHOD_1")
    expect(m_info.base_name).is("METHOD_1")
    expect(m_info.class_name).is("CLASS.NAME_1")
    expect(m_info.class).is(c_info)
    c_info = self.module:get_class("CLASS.NAME_2")
    iterator = c_info.all_method_names
    expect(iterator()).is("METHOD_1")
    expect(iterator()).is("METHOD_2")
    expect(iterator()).is(nil)
    m_info = c_info:get_method("METHOD_2")
    expect(m_info).Class.is(AD.Method)
    expect(m_info.name).is("CLASS.NAME_2.METHOD_2")
    expect(m_info.base_name).is("METHOD_2")
    expect(m_info.class).is(c_info)
  end,
})

_G.test_latex = Test({
  prepare = function (self, str)
    self.module = AD.Module({
      file_path = AUTODOC_PATH,
      contents = str
    })
  end,
  test_Global = function (self)
    local s = [[
---GLOBAL: SHORT DESCRIPTION
---GLOBAL: LONG  DESCRIPTION
---@global GLOBAL @ GLOBAL: COMMENT
---TYPE: SHORT DESCRIPTION
---TYPE: LONG  DESCRIPTION
---@type TYPE @ TYPE: COMMENT
]]
    local expected = [[
\begin{Global}
\Name{GLOBAL}
\Types{TYPE}
\Comment{GLOBAL: COMMENT}
\ShortDescription{GLOBAL: SHORT DESCRIPTION}
\begin{LongDescription}
GLOBAL: LONG  DESCRIPTION
\end{LongDescription}
\end{Global}
]]

    self:prepare(s)
    local g_info = self.module:get_global("GLOBAL")
    local as_latex_environment = g_info.as_latex_environment
    expect(as_latex_environment).NOT(nil)
    expect(as_latex_environment).is(expected)

    s = [[
---FUNCTION: SHORT DESCRIPTION
---FUNCTION: LONG  DESCRIPTION
---@function FUNCTION
---PARAM: SHORT DESCRIPTION
---PARAM: LONG  DESCRIPTION
---@param PARAM PARAM_TYPE @ PARAM: COMMENT
---VARARG: SHORT DESCRIPTION
---VARARG: LONG  DESCRIPTION
---@vararg VARARG_TYPE @ VARARG: COMMENT
---RETURN: SHORT DESCRIPTION
---RETURN: LONG  DESCRIPTION
---@return RETURN_TYPE @ RETURN: COMMENT
---SEE: SHORT DESCRIPTION
---SEE: LONG  DESCRIPTION
---@see SEE
---AUTHOR: SHORT DESCRIPTION
---AUTHOR: LONG  DESCRIPTION
---@author AUTHOR
]]
    expected = [[
\begin{Function}
\Name{FUNCTION}
\ShortDescription{FUNCTION: SHORT DESCRIPTION}
\begin{LongDescription}
FUNCTION: LONG  DESCRIPTION
\end{LongDescription}
\begin{Params}
\begin{Param}
\Name{PARAM}
\Types{PARAM_TYPE}
\Comment{PARAM: COMMENT}
\ShortDescription{PARAM: SHORT DESCRIPTION}
\begin{LongDescription}
PARAM: LONG  DESCRIPTION
\end{LongDescription}
\end{Param}
\end{Params}
\begin{Vararg}
\Types{VARARG_TYPE}
\Comment{VARARG: COMMENT}
\ShortDescription{VARARG: SHORT DESCRIPTION}
\begin{LongDescription}
VARARG: LONG  DESCRIPTION
\end{LongDescription}
\end{Vararg}
\begin{Returns}
\begin{Return}
\Types{RETURN_TYPE}
\Comment{RETURN: COMMENT}
\ShortDescription{RETURN: SHORT DESCRIPTION}
\begin{LongDescription}
RETURN: LONG  DESCRIPTION
\end{LongDescription}
\end{Return}
\end{Returns}
\begin{See}
\Value{SEE}
\ShortDescription{SEE: SHORT DESCRIPTION}
\begin{LongDescription}
SEE: LONG  DESCRIPTION
\end{LongDescription}
\end{See}
\begin{Author}
\Value{AUTHOR}
\ShortDescription{AUTHOR: SHORT DESCRIPTION}
\begin{LongDescription}
AUTHOR: LONG  DESCRIPTION
\end{LongDescription}
\end{Author}
\end{Function}
]]
    self:prepare(s)
    local f_info = self.module:get_fun("FUNCTION")
    as_latex_environment = f_info.as_latex_environment
    expect(as_latex_environment).NOT(nil)
    expect(as_latex_environment).is(expected)

    s = [[
---CLASS: SHORT DESCRIPTION
---CLASS: LONG  DESCRIPTION
---@class CLASS @ CLASS CMT
---FIELD: SHORT DESCRIPTION
---FIELD: LONG  DESCRIPTION
---@field public FIELD TYPE @ FIELD CMT
---SEE: SHORT DESCRIPTION
---SEE: LONG  DESCRIPTION
---@see SEE
---AUTHOR: SHORT DESCRIPTION
---AUTHOR: LONG  DESCRIPTION
---@author AUTHOR
]]
    expected = [[
\begin{Class}
\Name{CLASS}
\Comment{CLASS CMT}
\ShortDescription{CLASS: SHORT DESCRIPTION}
\begin{LongDescription}
CLASS: LONG  DESCRIPTION
\end{LongDescription}
\begin{Fields}
\begin{Field}
\Name{FIELD}
\Types{TYPE}
\Comment{FIELD CMT}
\ShortDescription{FIELD: SHORT DESCRIPTION}
\begin{LongDescription}
FIELD: LONG  DESCRIPTION
\end{LongDescription}
\end{Field}
\end{Fields}
\begin{See}
\Value{SEE}
\ShortDescription{SEE: SHORT DESCRIPTION}
\begin{LongDescription}
SEE: LONG  DESCRIPTION
\end{LongDescription}
\end{See}
\begin{Author}
\Value{AUTHOR}
\ShortDescription{AUTHOR: SHORT DESCRIPTION}
\begin{LongDescription}
AUTHOR: LONG  DESCRIPTION
\end{LongDescription}
\end{Author}
\end{Class}
]]
    self:prepare(s)
    local c_info = self.module:get_class("CLASS")
    as_latex_environment = c_info.as_latex_environment
    expect(as_latex_environment).NOT(nil)
    expect(as_latex_environment).is(expected)
  end
})
