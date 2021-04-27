#!/usr/bin/env texlua

local lpeg    = require("lpeg")
local P       = lpeg.P
local Cg      = lpeg.Cg
local Ct      = lpeg.Ct
local Cc      = lpeg.Cc
local Cb      = lpeg.Cb
local V       = lpeg.V
local Cp      = lpeg.Cp

---@type corelib_t
local corelib = require("l3b-corelib")

local expect  = require("l3b-test/expect").expect

local l3build = require("l3build")

local AUTODOC_NAME = "l3b-autodoc"
local AUTODOC_PATH = l3build.work_dir .."l3b/".. AUTODOC_NAME ..".lua"

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

local lpad = loadfile(
  l3build.work_dir .."l3b/l3b-lpeg-autodoc.lua",
  "t",
  PEG_XTD
)()

local DB    = require("l3b-test/autodoc_db")
local Test  = require("l3b-test/autodoc_test")

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
      * P( corelib.get_spaced_p("<")
        * V("type")
        * corelib.spaced_comma_p
        * V("type")
        * corelib.get_spaced_p(">")
      )^-1,
    })
    expect((p * Cp()):match("table<abc,abc>")).is(15)
  end,
  test_key = function (self)
    local Subclass = AD.Content:make_subclass("fOo.BaR")
    expect(Subclass.key).is("bar")
  end,
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
  test = function (self)
    self:do_setup(AD.ShortLiteral)
    self:do_test_base(DB.BASE())
    self:do_test_DB_x("short_literal")
  end
})

_G.test_LongLiteral = Test({
  test = function (self)
    self:do_setup(AD.LongLiteral)
    self:do_test_base(DB.BASE())
    self:do_test_DB_x("long_literal")
  end
})

_G.test_LineComment = Test({
  test = function (self)
    self:do_setup(AD.LineComment)
    self:do_test_base(DB.BASE())
    self:do_test_TD("line_comment")
    self:do_test_DB_x("line_comment")
  end
})

_G.test_LongComment = Test({
  test = function (self)
    self:do_setup(AD.LongComment)
    self:do_test_base(DB.BASE())
    self:do_test_TD("long_comment")
    self:do_test_DB_x("long_comment")
  end,
})

_G.test_LineDoc = Test({
  test = function (self)
    self:do_setup(AD.LineDoc)
    self:do_test_base(DB.BASE())
    self:do_test_TD("line_doc")
    self:do_test_DB_x("line_doc")
  end,
})

_G.test_LongDoc = Test({
  test = function (self)
    self:do_setup(AD.LongDoc)
    self:do_test_base(DB.BASE())
    self:do_test_TD("long_doc")
    self:do_test_DB_x("long_doc")
  end,
})

DB:fill(
  AD.Description.__TYPE,
  "--",
  nil,
  "---",
  {
    min   = 1,
    max   = 3,
    long  = {},
    short = AD.LineDoc({
      min   = 1,
      content_min = 4,
      content_max = 3,
      max   = 3,
    }),
  },
  "---\n",
  {
    min   = 1,
    max   = 4,
    long  = {},
  },
  "---\ns",
  {
    min   = 1,
    max   = 4,
    long  = {},
  },
  "---\n\n",
  {
    min   = 1,
    max   = 4,
    long  = {},
  },
  "-- \n---",
  nil,
  "---\n---",
  {
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
  },
----5----0----5----0----5----0----5----0----5
  [=====[
---
--[[]]
]=====],
  {
    min   = 1,
    max   = 11,
    short = AD.LineDoc({
      min         = 1,
      content_min = 4,
      content_max = 3,
      max         = 4,
    }),
    long  = {},
  },
----5----0----5----0----5----0----5----0----5
  [=====[
---
--[===[]===]
]=====],
  {
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
  },
----5----0----5----0----5----0----5----0----5
  [=====[
---
--[===[]===]
--
---
s   s
]=====],
  {
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
  }
)

_G.test_Description = Test({
  test = function (self)
    self:do_setup(AD.Description)
    self:do_test_base(DB.BASE())
    self:do_test_DB_x(AD.Description.__TYPE, true)
  end,
})

DB:fill(
  "AD.At.Author",
  -----5----0----5----0----5----0----5----0----5
  "---@author 9hat do you want of 30  ",
  {
    min         = 1,
    -- content_min = 12,
    -- content_max = 33,
    max         = 35,
    value       = "9hat do you want of 30",
    ignores     = {},
  }
)
_G.test_At_Author = Test({
  test = function (self)
    self:do_setup(AD.At.Author)
    self:do_test_base(DB.BASE())
    self:do_test_DB_x("AD.At.Author", true)
  end,
  test_complete = function (self)
    self:do_test_complete("Author")
  end
})

DB:fill(
  "AD.At.Field",
  "--- @field public f21 b25",
  {
    min         = 1,
    content_min = 26,
    content_max = 25,
    max         = 25,
    visibility  = "public",
    name        = "f21",
    types       = { "b25" },
  },
  -----5----0----5----0----5----0----5
  "--- @field private f22 b26\n   ",
  {
    min         = 1,
    content_min = 27,
    content_max = 26,
    max         = 27,
    visibility  = "private",
    name        = "f22",
    types       = { "b26" },
  },
  ----5----0----5----0----5----0----5----0----5
  "--- @field private f22 b26 @ commentai40   ",
  {
    min         = 1,
    content_min = 30,
    content_max = 40,
    max         = 43,
    visibility  = "private",
    name        = "f22",
    types       = { "b26" },
  },
  -----5----0----5----0----5----0----5----0----5
  "--- @field private f22 b26\n   ",
  {
    min         = 1,
    content_min = 27,
    content_max = 26,
    max         = 27,
    visibility  = "private",
    name        = "f22",
    types       = { "b26" },
  },
  -----5----0----5----0----5----0----5----0----5
  "123456789--- @field private f22 b26\n   ",
  {
    min         = 10,
    content_min = 36,
    content_max = 35,
    max         = 36,
    visibility  = "private",
    name        = "f22",
    types       = { "b26" },
  },
  10
)

_G.test_At_Field = Test({
  test = function (self)
    expect(AD.At.Field()).contains(AD.At.Field(DB.Base))
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
    self:do_setup(AD.At.Field)
    self:do_test_base(DB.BASE())
    self:do_test_DB_x("AD.At.Field", true)
  end,
  test_complete = function (self)
    self:do_test_complete("Field")
  end
})

DB:fill(
  "AD.At.See",
  -----5----0----5----0----5----0----5----0----5
  "---@see 9hat do you want of 30  ",
  {
    min         = 1,
    value       = "9hat do you want of 30",
    ignores     = {},
    max         = 32,
  }
)

_G.test_At_See = Test({
  test = function (self)
    expect(AD.At.See()).contains( AD.At.See(DB.Base) )
    self:do_setup(AD.At.See)
    self:do_test_base(DB.BASE())
    self:do_test_DB_x("AD.At.See", true)
  end,
  test_complete = function (self)
    self:do_test_complete("See")
  end
})

DB:fill(
  "AD.At.Class",
  -----5----0----5----0----5----0----5----0----5
  "---@class MY_TY17",
  {
    min         = 1,
    content_min = 18,
    content_max = 17,
    max         = 17,
  },
  -----5----0----5----0----5----0----5----0----5
  "---@class AY_TYPE: PARENT_TY30",
  {
    min         = 1,
    content_min = 31,
    content_max = 30,
    max         = 30,
    name        = "AY_TYPE",
    parent      = "PARENT_TY30",
  }
)

-- @class MY_TYPE[:PARENT_TYPE] [@comment]
_G.test_At_Class = Test({
  test = function (self)
    expect(AD.At.Class()).equals( AD.At.Class(DB.Base) )
    self:do_setup(AD.At.Class)
    self:do_test_base(DB.BASE())
    self:do_test_DB_x("AD.At.Class", true)
    local TD = self.get_CLASS()
    ---@type AD.At.Class
    local t = self.p:match(TD.s)
    expect(t).contains(TD:x())
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
    expect(t.fields).equals({
      TD_FIELD:m(1 + TD_CLASS:m().max)
    })
    expect(t.author).equals(
      TD_AUTHOR:m(
        1 + TD_FIELD:m(1 + TD_CLASS:m().max).max
      )
    )
    local TD = self.get_CLASS_COMPLETE()
    local actual = p:match(TD.s)
    local expected = TD:m()
    expect(actual).contains(expected)
  end,

})

DB:fill(
  "AD.At.Type",
----5----0----5----0----5----0----5----0
  [=====[
---@type MY_TYPE]=====],
  {
    min = 1,
    content_min = 17,
    content_max = 16,
    max = 16,
    types = { "MY_TYPE" },
  },
----5----0----5----0----5----0----5----0
  [=====[
---@type MY_TYPE|OTHER_TYPE]=====],
  {
    min = 1,
    content_min = 28,
    content_max = 27,
    max = 27,
    types = { "MY_TYPE", "OTHER_TYPE" },
  },
----5----0----5----0----5----0----5----0
  [=====[
---@type MY_TYPE|OTHER_TYPE @ COMMENT ]=====],
  "COMMENT",
  {
    min = 1,
    content_min = 31,
    content_max = 37,
    max = 38,
    types = { "MY_TYPE", "OTHER_TYPE" },
  }
)

_G.test_At_Type = Test({
  test = function (self)
    expect(AD.At.Type()).contains( AD.At.Type(DB.Base) )
    self:do_setup(AD.At.Type)
    self:do_test_base(DB.BASE())
    self:do_test_DB_x("AD.At.Type", true)
    self:do_test_TD("Type")
    local TD = self.get_TYPE()
    ---@type AD.At.Type
    local t = self.p:match(TD.s)
    expect(t).contains(TD:m())
    expect(t:get_comment(TD.s)).is(TD.c)
  end,
  test_complete = function (self)
    self:do_test_complete("Type")
  end,
})

DB:fill(
  "AD.At.Alias",
  [=====[
---@alias NEW_NAME TYPE ]=====],
  {
    min         = 1,
    content_min = 24,
    content_max = 23,
    max         = 24,
    name        = "NEW_NAME",
    types       = { "TYPE" },
  },
----5----0----5----0----5----0----5----0
  [=====[
---@alias NEW_NAME TYPE | OTHER_TYPE ]=====],
  {
    min         = 1,
    content_min = 37,
    content_max = 36,
    max         = 37,
    name        = "NEW_NAME",
    types       = { "TYPE", "OTHER_TYPE" },
  },
  ----5----0----5----0----5----0----5----0----5----
  [=====[
---@alias     NAME TYPE @ SOME   COMMENT]=====],
  {
    min         = 1,
    content_min = 27,
    content_max = 40,
    max         = 40,
    name        = "NAME",
    types       = { "TYPE" },
  },
  [=====[
---@alias     NAME TYPE @ SOME   COMMENT         
  SUITE                                        ]=====],
  "SOME   COMMENT",
  {
    min         = 1,
    content_min = 27,
    content_max = 40,
    max         = 50,
    name        = "NAME",
    types       = { "TYPE" },
  }
)

_G.test_At_Alias = Test({
  test = function (self)
    expect(AD.At.Alias()).contains( AD.At.Alias(DB.Base) )
    self:do_setup(AD.At.Alias)
    self:do_test_base(DB.BASE())
    self:do_test_DB_x("AD.At.Alias", true)
    self:do_test_TD("Alias")
  end,
  test_complete = function (self)
    self:do_test_complete("Alias")
  end,
})

DB:fill(
  "AD.At.Param",
  [=====[
---@param NAME TYPE]=====],
  {
    min         = 1,
    content_min = 20,
    content_max = 19,
    max         = 19,
    name        = "NAME",
    optional    = false,
    types       = { "TYPE" },
  },
----5----0----5----0----5----0----5----0----5----
  [=====[
---@param NAME ? TYPE]=====],
  {
    min         = 1,
    content_min = 22,
    content_max = 21,
    max         = 21,
    name        = "NAME",
    optional    = true,
    types       = { "TYPE" },
  },
----5----0----5----0----5----0----5----0----5----
  [=====[
---@param NAME TYPE
]=====],
  {
    min         = 1,
    content_min = 20,
    content_max = 19,
    max         = 20,
    name        = "NAME",
    optional    = false,
    types       = { "TYPE" },
  },
----5----0----5----0----5----0----5----0----5----
  [=====[
---@param NAME ? TYPE
]=====],
  "",
  {
    min         = 1,
    content_min = 22,
    content_max = 21,
    max         = 22,
    name        = "NAME",
    optional    = true,
    types       = { "TYPE" },
  },
----5----0----5----0----5----0----5----0----5----
  [=====[
---@param NAME TYPE  |  OTHER
]=====],
  "",
  {
    min         = 1,
    content_min = 30,
    content_max = 29,
    max         = 30,
    name        = "NAME",
    optional    = false,
    types       = { "TYPE", "OTHER" },
  },
----5----0----5----0----5----0----5----0----5----
  [=====[
---@param NAME TYPE  |  OTHER@  COMMENT
]=====],
  "COMMENT",
  {
    min         = 1,
    content_min = 33,
    content_max = 39,
    max         = 40,
    name        = "NAME",
    optional    = false,
    types       = { "TYPE", "OTHER" },
  }
)

_G.test_At_Param = Test({
  test = function (self)
    expect(AD.At.Param()).contains( AD.At.Param(DB.Base) )
    self:do_setup(AD.At.Param)
    self:do_test_base(DB.BASE())
    self:do_test_DB_x("AD.At.Param", true)
    self:do_test_TD("Param")
  end,
  test_complete = function (self)
    self:do_test_complete("Param")
  end,
})

DB:fill(
  "AD.At.Return",
  [=====[
---   @return TYPE   |  OTHER @ COMMENT
]=====],
  "COMMENT",
  {
    min         = 1,
    max         = 40,
    content_min = 33,
    content_max = 39,
    types       = { "TYPE", "OTHER" },
  },
----5----0----5----0----5----0----5----0----5----
  [=====[
---   @return TYPE? @ COMMENT
]=====],
  "COMMENT",
  {
    min         = 1,
    max         = 30,
    content_min = 23,
    content_max = 29,
    types       = { "TYPE" },
    optional    = true,
  },
  -----5----0----5----0----5----0----5----0----5----
  "---@return fun(): string | nil",
  {
    min         = 1,
    max         = 30,
    content_min = 31,
    content_max = 30,
    types       = { "fun(): string | nil" },
    optional    = false,
  }
)

_G.test_At_Return = Test({
  test = function (self)
    expect(AD.At.Return()).equals(AD.At.Return(DB:BASE()))
    self:do_setup(AD.At.Return)
    self:do_test_base(DB.BASE())
    self:do_test_DB_x("AD.At.Return", true)
    self:do_test_TD("Return")
  end,
  test_complete = function (self)
    self:do_test_complete("Return")
  end,
})

DB:fill(
  "AD.At.Generic",
  [=====[
---@generic T1
]=====],
  {
    type_1 = "T1",
    parent_1 = nil,
    type_2 = nil,
    parent_2 = nil,
  },
  [=====[
---@generic T1: P1
]=====],
  {
    type_1 = "T1",
    parent_1 = "P1",
    type_2 = nil,
    parent_2 = nil,
  },
  [=====[
---@generic T1, T2
]=====],
  {
    type_1 = "T1",
    parent_1 = nil,
    type_2 = "T2",
    parent_2 = nil,
  },
  [=====[
---@generic T1 : P1, T2
]=====],
{
  type_1 = "T1",
  parent_1 = "P1",
  type_2 = "T2",
  parent_2 = nil,
},
  [=====[
---@generic T1, T2 : P2
]=====],
  {
    type_1 = "T1",
    parent_1 = nil,
    type_2 = "T2",
    parent_2 = "P2",
  },
  [=====[
---@generic T1 : P1, T2 : P2
]=====],
  {
    type_1 = "T1",
    parent_1 = "P1",
    type_2 = "T2",
    parent_2 = "P2",
  },
----5----0----5----0----5----0----5----0----5----0----5----
  [=====[
---@generic   T1 : P1, T2 : P2 @  COMMENT
]=====],
  "COMMENT",
  {
    type_1 = "T1",
    parent_1 = "P1",
    type_2 = "T2",
    parent_2 = "P2",
  }
)

_G.test_At_Generic = Test({
  test = function (self)
    expect(AD.At.Generic()).contains(AD.At.Generic(DB:BASE()))
    self:do_setup(AD.At.Generic)
    self:do_test_base(DB.BASE())
    self:do_test_DB_x("AD.At.Generic", true)
    self:do_test_TD("Generic")
  end,
  test_complete = function (self)
    self:do_test_complete("Generic")
  end,
})

DB:fill(
  "AD.At.Vararg",
----5----0----5----0----5----0----5----0----5----0----5----
  [=====[
---@vararg    TYPE_
]=====],
  "",
  {
    min         = 1,
    content_min = 20,
    content_max = 19,
    max         = 20,
    types       = { "TYPE_" },
  },
----5----0----5----0----5----0----5----0----5----0----5----
  [=====[
---@vararg    TYPE_|TYPE
]=====],
  "",
  {
    min         = 1,
    content_min = 25,
    content_max = 24,
    max         = 25,
    types       = { "TYPE_", "TYPE" },
  },
----5----0----5----0----5----0----5----0----5----0----5----
  [=====[
---@vararg    TYPE_|TYPE@CMT_
]=====],
  "CMT_",
  {
    min         = 1,
    content_min = 26,
    content_max = 29,
    max         = 30,
    types       = { "TYPE_", "TYPE" },
  }
)

_G.test_At_Vararg = Test({
  test = function (self)
    expect(AD.At.Vararg()).contains( AD.At.Vararg(DB.Base) )
    self:do_setup(AD.At.Vararg)
    self:do_test_base(DB.BASE())
    self:do_test_DB_x("AD.At.Vararg", true)
    self:do_test_TD("Vararg")
  end,
  test_complete = function (self)
    self:do_test_complete("Vararg")
  end,
})

DB:fill(
  "AD.At.Module",
----5----0----5----0----5----0----5----0----5----0----5----
    [=====[
---   @module name_
]=====],
  "",
  {
    min         = 1,
    content_min = 20,
    content_max = 19,
    max         = 20,
    name        = "name_",
  },
----5----0----5----0----5----0----5----0----5----0----5----
  [=====[
---   @module name_ @ COMMENT
]=====],
  "COMMENT",
  {
    min         = 1,
    content_min = 23,
    content_max = 29,
    max         = 30,
    name        = "name_",
  }
)

_G.test_At_Module = Test({
  test = function (self)
    expect(AD.At.Module()).equals( AD.At.Module(DB:BASE()) )
    self:do_setup(AD.At.Module)
    self:do_test_base(DB.BASE())
    self:do_test_DB_x("AD.At.Module", true)
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
      max         = 42,
      value       = "my_pseudo",
      ignores     = {},
    }) )
    expect(t:get_comment(s)).is("")
    expect(t.author.value).is("my_pseudo")
    end,
})

DB:fill(
  "AD.At.Function",
---5----0----5----0----5----0----5----0----5----0----5----
  [=====[
---@function  name_
]=====],
  {
    min = 1,
    max = 20,
    name = "name_",
  },
---5----0----5----0----5----0----5----0----5----0----5----
  [=====[
---@function  NAME  @ COMMENT
]=====],
  "COMMENT",
  {
    min         = 1,
    max         = 30,
    content_min = 23,
    content_max = 29,
    name        = "NAME",
  }
)

_G.test_At_Function = Test({
  test = function (self)
    expect(AD.At.Function()).equals( AD.At.Function(DB:BASE()) )
    self:do_setup(AD.At.Function)
    self:do_test_base(DB.BASE())
    self:do_test_DB_x("AD.At.Function", true)
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
    expect(p:match(TD.s)).contains(TD:m())
  end,
})

DB:fill(
  "AD.Break",
  "",
  nil,
  " \n ",
  {
    min = 1,
    max = 3,
  },
  " \n \n",
  {
    min = 1,
    max = 4,
  }
)

_G.test_Break = Test({
  test = function (self)
    expect(AD.Break().__Class).equals(AD.Break)
    self:do_setup(AD.Break)
    self:do_test_base(DB.BASE())
    self:do_test_DB_x("AD.Break", true)
  end,
})

DB:fill(
  AD.At.Global.__TYPE,
----5----0----5----0----5----0----5----0----5----0----5----
    [=====[
---  @global   NAME
]=====],
{
    min = 1,
    max = 20,
    name = "NAME",
  },
---5----0----5----0----5----0----5----0----5----0----5----
  [=====[
---  @global   NAME @ COMMENT
]=====],
  "COMMENT",
  {
    min = 1,
    max = 30,
    name = "NAME",
  },
----5----0----5----0----5----0----5----0----5----0----5----
  [=====[
---   @global NAME TYPE @ CMT
]=====],
  "CMT",
  {
    min = 1,
    content_min = 27,
    content_max = 29,
    max = 30,
    name = "NAME",
    types = { "TYPE" }
  }
)

_G.test_At_Global = Test({
  test = function (self)
    self:do_setup(AD.At.Global)
    self:do_test_base(DB.BASE())
    self:do_test_DB_x("AD.At.Global", true)
    self:do_test_TD("Global")
  end,
  test_complete = function (self)
    self:do_test_complete("Global")
    local p = AD.At.Global:get_complete_p()
    local TD = self:get_GLOBAL_COMPLETE()
    expect(p:match(TD.s)).contains(TD:m())
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
      local actual = self.p:match(TD.s)
      local expected = TD:m()
      expect(actual).equals(expected)
      if TD.c and actual.get_content then
        expect(actual:get_content(TD.s)).is(TD.c)
      end
    end
  end,
  test_function_items = function (self)
    -- to one attributes
    for KEY, multi in pairs(self.FUNCTION_ITEMS) do
      local f = self["get_".. KEY]
      local TD = f(self)
      local actual = self.p:match(TD.s)
      local key = multi
        and KEY:lower() .."s"
        or  KEY:lower()
      local expected = AD.At.Function({
        min         = 1,
        max         = TD:m().max,
        [key]       = multi and { TD:m() } or TD:m(),
      })
      expect(actual).equals(expected)
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
        infos = { TD:m() },
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
          max         = TD:m().max,
          [key]       = multi and { TD:m() } or TD:m(),
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
              TD_1:m(),
              TD_2:m(1 + TD_1:m().max)
            },
          })
        end
      end
    end
  end,
  test = function (self)
    local s
  end
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
    expect(g_info.name)
      .is("NAME")
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
    expect(field_1).contains({
      comment = "FIELD_1: CMT",
      short_description = "FIELD_1: SHORT DESCRIPTION",
      long_description = "FIELD_1: LONG  DESCRIPTION",
      types = "TYPE_1",
      visibility = "protected"
    })
    local field_2 = c_info:get_field("FIELD_2")
    expect(field_2).contains({
      comment = "FIELD_2: CMT",
      short_description = "FIELD_2: SHORT DESCRIPTION",
      long_description = "FIELD_2: LONG  DESCRIPTION",
      types = "TYPE_2",
      visibility = "protected"
    })
    local author = c_info.author
    expect(author).contains({
      value = "PSEUDO IDENTIFIER",
      short_description = "AUTHOR:  SHORT DESCRIPTION",
      long_description = "AUTHOR:  LONG  DESCRIPTION",
    })
    local see = c_info.see
    expect(see).contains({
      value = "VARIOUS REFERENCES",
      short_description = "SEE:     SHORT DESCRIPTION",
      long_description = "SEE:     LONG  DESCRIPTION",
    })
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
