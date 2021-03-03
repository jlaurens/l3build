--[[

File l3build-upload.lua Copyright (C) 2018-2020 The LaTeX Project

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

local print    = print
local tostring = tostring

local close = io.close
local flush = io.flush
local open  = io.open
local popen = io.popen
local read  = io.read
local write = io.write

local len     = string.len
local lower   = string.lower
local match   = string.match
local str_rep = string.rep

---@type utlib_t
local utlib         = require("l3b.utillib")
local chooser       = utlib.chooser
local entries       = utlib.entries
local trim_space    = utlib.trim
local file_contents = utlib.file_contents
local deep_copy     = utlib.deep_copy

---@type l3build_t
local l3build = require("l3build")
---@type l3build_debug_t
local debug   = l3build.debug
local options = l3build.options

--[=[

UPLOAD()

takes a package configuration table and an optional boolean

if the upload parameter is not supplied or is not true, only package validation
is used, if upload is true then package upload will be attempted if validation
succeeds.

fields are given as a string, or optionally for fields allowing multiple
values, as a table of strings.

Mandatory fields are checked in Lua
Maximum string lengths are checked.

Currently string values are not checked, eg licence names, or URL syntax.

The input form could be used to construct a post body but
luasec is not included in texlua. Instead an external program is used to post.
As Windows (since April 2018) includes curl now use curl.
A version using ctan-o-mat is available in the ctan-post github repo.

the main interface is
    upload()
with a configuration table `uploadconfig`

--]=]

local Vars = chooser(_G, {
  curlexe = "curl",
  curl_debug = false,
  uploadconfig = {}
})

-- function for interactive multiline fields
local function input_multi_line_field (name)
  print("Enter " .. name .. "  three <return> or ctrl-D to stop")
  local field = ""
  local answer_line
  local return_count = 0
  repeat
    write("> ")
    flush()
    answer_line = read()
    if answer_line == "" then
      return_count = return_count + 1
    else
      field = field + str_rep("\n", return_count)
      return_count = 0
      if answer_line then
        field = field .. "\n" .. answer_line
      end
     end
  until return_count == 3 or answer_line == nil or answer_line == '\004'
  return field
end

local function input_single_line_field(name)
  print("Enter " .. name )
  write("> ")
  flush()
  return read()
end

---Input one field
---@param name string field name
---@param value any field value
---@param max number max size
---@param desc string description
---@param mandatory boolean
---@return string
local function single_field(name, value, max, desc, mandatory)
  local value_print = value == nil and '??' or value
  print('ctan-upload | ' .. name .. ': ' ..tostring(value_print))
  if (value == nil and mandatory) or value == 'ask' then
    if max < 256 then
      value = input_single_line_field(name)
    else
      value = input_multi_line_field(name)
    end
  end
  if value == nil or type(value) ~= "table" then
    local vs = trim_space(tostring(value))
    if mandatory == true and (value == nil or vs == "") then
      if name == "announcement" then
        print("Empty announcement: No ctan announcement will be made")
      else
        error("The field " .. name .. " must contain " .. desc)
      end
    end
    if value and len(vs) > 0 then
      if max > 0 and len(vs) > max then
        error("The field " .. name .. " is longer than " .. max)
      end
      vs =  vs:gsub('"', '\\"')
              :gsub('`', '\\`')
              :gsub('\n', '\\n')
-- for strings on commandline version      self.ctan_post=self.ctan_post .. ' --form "' .. fname .. "=" .. vs .. '"'
      return '\nform="' .. name .. '=' .. vs .. '"'
    end
  else
    error("The value of the field '" .. name .."' must be a scalar not a table")
  end
end

local MT = {}

---comment
---@param tag_names string_list_t|nil
local function upload(tag_names)
  tag_names = tag_names or {}
  local controller = setmetatable({}, MT)
  controller:prepare(tag_names[1])
  controller:upload(tag_names)
end

---Send the request with the given command
---Return the result.
---@param command string
---@return string
function MT:send_request(command)
  local fh = assert(popen(self.request .. command, "r"))
  local t  = assert(fh:read("a"))
  fh:close()
  return t
end

---Prepare the context
---@param version string
---@return integer
function MT:prepare(version)

  -- avoid lower level error from post command if zip file missing
  self.upload_file = _G.ctanzip ..".zip"
  local zip = open(trim_space(tostring(self.upload_file)), "r")
  if zip then
    close(zip)
  else
    error("Missing zip file '" .. tostring(self.upload_file) .. "'")
  end
  
  -- if ctanupload is nil or false, only validation is attempted
  -- if ctanupload is true the ctan upload URL will be used after validation
  -- if upload is anything else, the user will be prompted whether to upload.
  -- For now, this is undocumented. I think I would prefer to keep it always set to ask for the time being.
  
  -- Keep data local, JL: what does it mean?
  self.config = deep_copy(Vars.uploadconfig)
  local config = self.config

  -- try a sensible default for the package name:
  config.pkg = config.pkg or _G.ctanpkg or nil

  -- Get data from command line if appropriate
  do
    local message = options["message"]
        or file_contents(options["file"])
        or file_contents(config.announcement_file)
    assert(message)
    config.announcement = message
  end

  config.email = options["email"] or config.email

  config.note = config.note or file_contents(config.note_file)

  config.version = version or config.version

  self.override_update_check = false
  if config.update ~= false then
    config.update = true
    self.override_update_check = true
  end
  self.ctanzip = _G.ctanzip

end

---Append the given text to the current request
---@param str string
---@return integer
function MT:append_request(str)
  self.request = self.request .. str
end

---comment
---@param tag_names string_list_t
---@return integer
function MT:upload(tag_names)

  self:construct_request()

  local config = self.config
-- curl file version
  local curlopt_file = config.curlopt_file or (self.ctanzip .. ".curlopt")
  local curlopt = open(curlopt_file, "w")
  curlopt:write(self.request)
  curlopt:close()

  self.request = Vars.curlexe .. " --config " .. curlopt_file

  if options["debug"] then
    self.append_request(' https://httpbin.org/post')
    local response = send(self.request)
    print('\n\nCURL COMMAND:')
    print(self.request)
    print("\n\nHTTP RESPONSE:")
    print(response)
    return 1
  end

  self.append_request(' https://ctan.org/submit/')

  -- call post command to validate the upload at CTAN's validate URL
  local exit_status = 0
  local response = ""
  -- use popen not execute so get the return body local exit_status = os.execute(self.ctan_post .. "validate")

  if Vars.curl_debug or debug.no_curl_posting then
    local reason = Vars.curl_debug
      and "curl_debug==true"
      or  "--debug-no-curl-posting"
    response = "WARNING: ".. reason ..": posting disabled"
    print(self.request)
    return 1
  end

  print("Contacting CTAN for validation:")
  response = self:send_request("validate")

  if self.override_update_check then
    if match(response, "non%-existent%spackage") then
      print("Package not found on CTAN; re-validating as new package:")
      config.update = false
      self:construct_request()
      response = self:send_request("validate")
    end
  end
  if match(response, "ERROR") then
    exit_status = 1
  end

  -- if upload requested and validation succeeded repost to the upload URL
  if exit_status ~= 0 and exit_status ~= nil then
    error("Warnings from CTAN package validation:\n" .. response)
  end

  local upload_to_ctan
  if options["dry-run"] then
    upload_to_ctan = false
  else
    upload_to_ctan = _G.ctanupload or "ask"
  end
  if upload_to_ctan ~= nil and upload_to_ctan ~= false and upload_to_ctan ~= true then
    if match(response, "WARNING") then
      print("Warnings from CTAN package validation:" .. response:gsub("%[", "\n["):gsub("%]%]", "]\n]"))
    else
      print("Validation successful." )
    end
    print("Do you want to upload to CTAN? [y/n]" )
    local answer = ""
    io.stdout:write("> ")
    io.stdout:flush()
    answer = read()
    if lower(answer, 1, 1) == "y" then
      upload_to_ctan = true
    end
  end
  if upload_to_ctan then
    response = self:send_request("upload")
--     this is just html, could save to a file
--     or echo a cleaned up version
    print('Response from CTAN:')
    print(response)
    if match(response, "WARNING") or match(response, "ERROR") then
      exit_status = 1
    end
  else
    if match(response, "WARNING") then
      print("Warnings from CTAN package validation:"
        .. response:gsub("%[", "\n["):gsub("%]%]", "]\n]"))
    else
      print("CTAN validation successful")
    end
  end
  return exit_status
end

function MT:construct_request()

  -- start building the curl command:
  -- commandline  self.ctan_post = curlexe .. " "
  self.request = ""

  -- build up the curl command field-by-field:

  --                        field            max  desc                               mandatory  multi
  -- -------------------------------------------------------------------------------------------------
  self:append_request_field("announcement", 8192, "Announcement",                        true,  false )
  self:append_request_field("author",        128, "Author name",                         true,  false )
  self:append_request_field("bugtracker",    255, "URL(s) of bug tracker",               false, true  )
  self:append_request_field("ctanPath",      255, "CTAN path",                           true,  false )
  self:append_request_field("description",  4096, "Short description of package",        false, false )
  self:append_request_field("development",   255, "URL(s) of development channels",      false, true  )
  self:append_request_field("email",         255, "Email of uploader",                   true,  false )
  self:append_request_field("home",          255, "URL(s) of home page",                 false, true  )
  self:append_request_field("license",      2048, "Package license(s)",                  true,  true  )
  self:append_request_field("note",         4096, "Internal note to ctan",               false, false )
  self:append_request_field("pkg",            32, "Package name",                        true,  false )
  self:append_request_field("repository",    255, "URL(s) of source repositories",       false, true  )
  self:append_request_field("summary",       128, "One-line summary of package",         true,  false )
  self:append_request_field("support",       255, "URL(s) of support channels",          false, true  )
  self:append_request_field("topic",        1024, "Topic(s)",                            false, true  )
  self:append_request_field("update",          8, "Boolean: true=update, false=new pkg", false, false )
  self:append_request_field("uploader",      255, "Name of uploader",                    true,  false )
  self:append_request_field("version",        32, "Package version",                     true,  false )

  local upload_file = tostring(self.upload_file)
  self.append_request('\nform="file=@' .. upload_file .. ';filename=' .. upload_file .. '"')
end

---Append field info to the request
---@param name string
---@param max integer
---@param desc string
---@param mandatory boolean
---@param multi boolean
function MT:append_request_field(name, max, desc, mandatory, multi)
  local value = self.config[name]
  if type(value) == "table" and multi then
    for v in entries(value) do
      self.append_request(single_field(name, v, max, desc, mandatory))
      mandatory = false
    end
  else
    self.append_request(single_field(name, value, max, desc, mandatory))
  end
end

---@class l3b_upload_t
---@field upload fun(tag_names: string_list_t): string

return {
  global_symbol_map = {},
  upload            = upload,
}
