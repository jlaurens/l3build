M = {}

local lfs = require("lfs")

-- Get the file contents given a file_name
-- @param kvargs.path Either a full path or relative to kvargs.dir
-- @param kvargs.dir Optional directory name, defaults to the current working directory
M.File_contents = function(kvargs)
  local p = kvargs.path
  if not p:match('^/.*') then
    local dir = kvargs.dir or lfs.currentdir()
    p = dir .. '/' .. p
  end
  local f = io.open(p)
  assert(f ~= nil)
  local ans = f:read("a")
  f:close()
  return ans
end

M.reserved_words = {
  ["and"] = true,
  ["break"] = true,
  ["do"] = true,
  ["else"] = true,
  ["elseif"] = true,
  ["end"] = true,
  ["false"] = true,
  ["for"] = true,
  ["function"] = true,
  ["goto"] = true,
  ["if"] = true,
  ["in"] = true,
  ["local"] = true,
  ["nil"] = true,
  ["not"] = true,
  ["or"] = true,
  ["repeat"] = true,
  ["return"] = true,
  ["then"] = true,
  ["true"] = true,
  ["until"] = true,
  ["while"] = true,
  ["select"] = true,
  ["print"] = true,
  ["exit"] = true,
  ["next"] = true,
  ["ipairs"] = true,
  ["tonumber"] = true,
  ["assert"] = true,
  ["match"] = true,
  ["gsub"] = true,
  ["insert"] = true,
  ["lookup"] = true,
  ["lfs"] = true
}

-- Get the words
-- @param kvargs.string The string holding the words
-- @param kvargs.pattern The optional pattern defining the concept of word.
--        defaults to "%w+"
M.get_words = function (kvargs)
  local p = '[\r\n]+'
  local ll = {}
  local carret  = 1
  local s = kvargs.string
  local from, to = s:find(p, carret)
  while from do
    ll[#ll+1] = s:sub(carret, from-1)
    carret  = to + 1
    from, to = s:find(p, carret)
  end
  ll[#ll+1] = s:sub(carret)
  local ww = {}
  local unik = {}
  for _,l in pairs(ll) do
    from = l:find('%-%-')
    if from ~= nil then
      l = l:sub(1, from-1)
    end
    for w in l:gmatch(kvargs.pattern or "%w+") do
      print('****', l)
      if w:len()>1 and not unik[w] and not M.reserved_words[w] then
        ww[#ww+1] = w
        unik[w] = true
      end
    end
  end
  table.sort(ww)
  return ww
end

-- Get the local variables
-- @param s The string holding the variables
M.get_local_variables = function (s)
  -- find local variables
  local lvv = {}
  local unik = {}
  local carret = 1
  while carret <= s:len() do
    local from, to = s:find('local%s+', carret)
    if from ~= nil then
      local v = s:match('([a-zA-Z_][%w_]*)%s*=', to)
      if v and not M.reserved_words[v] and not unik[v] then
        unik[v] = true
        lvv[to] =v
      end
      carret = to + 1
    else
      break
    end
  end
  table.sort(lvv)
  return lvv
end

-- Get the variables
-- @param s The string holding the variables
M.Get_global_variables = function (s)
  -- find local variables
  local lvv = {}
  local vv = {}
  local carret = 1
  while carret <= s:len() do
    local from, to = s:find('local%s+', carret)
    if from ~= nil then
      local v = s:match('([a-zA-Z_][%w_]*)%s*=', to)
      if v and not M.reserved_words[v] then
        lvv[v] = lvv[v] or {}
        lvv[v][to+1] = true
      end
      carret = to + 1
    else
      break
    end
  end
  local unik = {}
  carret = 1
  while carret <= s:len() do
    local from, to = s:find('[a-zA-Z_][%w_]*', carret)
    if from ~= nil then
      carret = to + 1
      local op_from, op_to = s:find('^%s*=', carret)
      if op_from ~= nil then
        local v = s:sub(from, to)
        if not unik[v] then
          if not M.reserved_words[v] then
            if lvv[v] == nil or not lvv[v][from] then
              vv[#vv+1] = v
              unik[v] = true
            end
          end
        end
        carret = op_to + 1
      end
    else
      break
    end
  end
  table.sort(vv)
  return vv
end

M.Get_global_variables_variables = function ()
  local s = M.File_contents_variables()
  return M.Get_global_variables(s)
end

local kk = {
  "arguments",
  "aux",
  "check",
  "clean",
  "ctan",
  "file-functions",
  "help",
  "install",
  "manifest-setup",
  "manifest",
  "stdmain",
  "tagging",
  "typesetting",
  "unpack",
  "upload",
  "variables"
}
for _,k in pairs(kk) do
  k_ = k:gsub('-', '_')
  local n = 'File_contents_' .. k_
  M[n] = function ()
    return M.File_contents({path = 'l3build-' .. k .. '.lua'})
  end
  local n2 = 'Get_global_variables_' .. k_
  M[n2] = function ()
    print(n)
    local s = M[n]()
    return M.Get_global_variables(s)
  end
  local n3 = 'Get_local_variables_' .. k_
  M[n3] = function ()
    local s = M[n]()
    return M.Get_local_variables(s)
  end
end

print(M.File_contents_file_functions())
print("****")
for _, v in pairs(M.Get_global_variables_file_functions()) do
  print(v)
end
os.exit(0)
M.File_contents_build = function ()
  return M.File_contents({path = 'l3build.lua'})
end
M.Get_local_variables_build = function ()
  local s = M.File_contents_build()
  return M.Get_local_variables(s)
end
M.Get_global_variables_build = function ()
  local s = M.File_contents_build()
  return M.Get_global_variables(s)
end

M.global_variables = {
  "asciiengines",
  "auxfiles",
  "bakext",
  "biberexe",
  "biberopts",
  "bibfiles",
  "bibtexexe",
  "bibtexopts",
  "binary",
  "binaryfiles",
  "bstfiles",
  "builddir",
  "bundle",
  "checkconfigs",
  "checkdeps",
  "checkengines",
  "checkfiles",
  "checkformat",
  "checkopts",
  "checkruns",
  "checksearch",
  "checksuppfiles",
  "cleanfiles",
  "context",
  "ctandir",
  "ctanpkg",
  "ctanreadme",
  "ctanzip",
  "curlexe",
  "currentdir",
  "demofiles",
  "distribdir",
  "docfiledir",
  "docfiles",
  "dviext",
  "dynamicfiles",
  "epoch",
  "etex",
  "excludefiles",
  "excludetests",
  "flatten",
  "flattentds",
  "forcecheckepoch",
  "forcedocepoch",
  "format",
  "glossarystyle",
  "includetests",
  "indexstyle",
  "installfiles",
  "interaction",
  "latex",
  "localdir",
  "logext",
  "luatex",
  "lveext",
  "lvtext",
  "maindir",
  "makeindexexe",
  "makeindexfiles",
  "makeindexopts",
  "manifestfile",
  "maxprintline",
  "module",
  "moduledir",
  "options",
  "packtdszip",
  "pdfext",
  "pdftex",
  "ps2pdfopt",
  "psext",
  "ptex",
  "pvtext",
  "recordstatus",
  "resultdir",
  "scriptfiles",
  "scriptmanfiles",
  "sourcefiledir",
  "sourcefiles",
  "specialformats",
  "specialtypesetting",
  "stdengine",
  "supportdir",
  "tagfiles",
  "tdsdir",
  "tdslocations",
  "tdsroot",
  "testdir",
  "testfiledir",
  "testsuppdir",
  "texmfdir",
  "textfiledir",
  "textfiles",
  "tlgext",
  "tpfext",
  "typesetcmds",
  "typesetdemofiles",
  "typesetdeps",
  "typesetdir",
  "typesetexe",
  "typesetfiles",
  "typesetopts",
  "typesetruns",
  "typesetsearch",
  "typesetsourcefiles",
  "typesetsuppfiles",
  "unpackdeps",
  "unpackdir",
  "unpackexe",
  "unpackfiles",
  "unpackopts",
  "unpacksearch",
  "unpacksuppfiles",
  "uploadconfig",
  "uptex",
  "xetex",
  "zipexe",
  "zipopts",
}

for _, v in pairs(M.Get_global_variables_file_functions()) do
  print(v)
end


return M