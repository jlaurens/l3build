--[[

File l3b-autodoc.lua Copyright (C) 2018-2020 The LaTeX Project

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

local append = table.insert
local concat = table.concat

local AD = _ENV.AD

assert(AD)

AD.AtProxy.LATEX_ENVIRONMENT = "unknown"
for _, Key in ipairs({
  "Param",
  "Vararg",
  "Return",
  "See",
  "Author",
  "Function",
  "Field",
  "Class",
  "Global",
  "Module"
}) do
  AD[Key].LATEX_ENVIRONMENT = Key
end

function AD.AtProxy.__computed_table:as_latex_environment()
 local content = self.as_latex
 return content and #content > 1 and
   ([[\begin{<?>}
]]):gsub("<%?>", self.LATEX_ENVIRONMENT)
   .. content
   .. ([[\end{<?>}
]]):gsub("<%?>", self.LATEX_ENVIRONMENT) or ""
end

function AD.AtProxy.__computed_table:as_latex()
  return self.latex_name
      .. self.latex_value
      .. self.latex_types
      .. self.latex_comment
      .. self.latex_short_description
      .. self.latex_long_description
end

function AD.AtProxy.__computed_table:latex_name()
  local replacement = self.name
  return replacement and ([[
\Name{<?>}
]]):gsub("<%?>", replacement) or ""
end

function AD.AtProxy.__computed_table:latex_types()
  local replacement = self.types
  return replacement and ([[
\Types{<?>}
]]):gsub("<%?>", replacement) or ""
end

function AD.AtProxy.__computed_table:latex_comment()
  local replacement = self.comment
  return replacement and ([[
\Comment{<?>}
]]):gsub("<%?>", replacement) or ""
end

function AD.AtProxy.__computed_table:latex_short_description()
  local replacement = self.short_description
  return replacement and ([[
\ShortDescription{<?>}
]]):gsub("<%?>", replacement) or ""
end

function AD.AtProxy.__computed_table:latex_long_description()
  local replacement = self.long_description
  return replacement and ([[
\begin{LongDescription}
<?>
\end{LongDescription}
]]):gsub("<%?>", replacement) or ""
end

function AD.AtProxy.__computed_table:latex_value()
  local replacement = self.value
  return replacement and ([[
\Value{<?>}
]]):gsub("<%?>", replacement) or ""
end

function AD.Function.__computed_table:as_latex()
  return self.latex_name
      .. self.latex_comment
      .. self.latex_short_description
      .. self.latex_long_description
      .. self.latex_params
      .. self.vararg.as_latex_environment
      .. self.latex_returns
      .. self.see.as_latex_environment
      .. self.author.as_latex_environment
end
function AD.Function.__computed_table:latex_params()
  local t = {}
  for param_name in self.all_param_names do
    local p_info = self:get_param(param_name)
    local as_latex = p_info.as_latex_environment
    if as_latex and #as_latex>0 then
      append(t, as_latex)
    end
  end
  if #t > 0 then
    return [[
\begin{Params}
]]
      .. concat(t, "")
      .. [[
\end{Params}
]]
  end
  return ""
end
function AD.Function.__computed_table:latex_vararg()
  return "vararg"
end
function AD.Function.__computed_table:latex_returns()
  local t = {}
  for i in self.all_return_indices do
    local r_info = self:get_return(i)
    local as_latex = r_info.as_latex_environment
    if as_latex and #as_latex>0 then
      append(t, as_latex)
    end
  end
  if #t > 0 then
    return [[
\begin{Returns}
]]
      .. concat(t, "")
      .. [[
\end{Returns}
]]
  end
  return ""
end
function AD.Function.__computed_table:latex_see()
  local replacement = self.see
  return replacement and ([[
\See{<?>}
  ]]):gsub("<?>", replacement) or ""
end
function AD.Function.__computed_table:latex_author()
  local replacement = self.author
  return replacement and ([[
\Author{<?>}
  ]]):gsub("<?>", replacement) or ""
end

function AD.Class.__computed_table:as_latex()
  return self.latex_name
      .. self.latex_comment
      .. self.latex_short_description
      .. self.latex_long_description
      .. self.latex_fields
      .. self.see.as_latex_environment
      .. self.author.as_latex_environment
end

function AD.Class.__computed_table:latex_fields()
  local t = {}
  for field_name in self.all_field_names do
    local f_info = self:get_field(field_name)
    local as_latex = f_info.as_latex_environment
    if as_latex and #as_latex>0 then
      append(t, as_latex)
    end
  end
  if #t > 0 then
    return [[
\begin{Fields}
]]
    .. concat(t, "")
    .. [[
\end{Fields}
]]
  end
  return ""
end

function AD.Module.__computed_table:as_latex_environment()
  local content = self.as_latex
  return content and #content > 1 and
    ([[\begin{<?>}
]]):gsub("<%?>", self.LATEX_ENVIRONMENT)
    .. content
    .. ([[\end{<?>}
]]):gsub("<%?>", self.LATEX_ENVIRONMENT) or ""
end

function AD.Module.__computed_table:as_latex()
  return
      self.latex_name
    .. self.latex_comment
    .. self.latex_short_description
    .. self.latex_long_description
    .. self.latex_globals
    .. self.latex_functions
    .. self.latex_classes
end
