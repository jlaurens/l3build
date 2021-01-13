
L3.options = {"help"}

L3.option_list =
  {
    config =
      {
        desc  = "Sets the config(s) used for running tests",
        short = "c",
        type  = "table"
      },
    date =
      {
        desc  = "Sets the date to insert into sources",
        type  = "string"
      },
    debug =
      {
        desc = "Runs target in debug mode (not supported by all targets)",
        type = "boolean"
      },
    dirty =
      {
        desc = "Skip cleaning up the test area",
        type = "boolean"
      },
    ["dry-run"] =
      {
        desc = "Dry run for install",
        type = "boolean"
      },
    email =
      {
        desc = "Email address of CTAN uploader",
        type = "string"
      },
    engine =
      {
        desc  = "Sets the engine(s) to use for running test",
        short = "e",
        type  = "table"
      },
    epoch =
      {
        desc  = "Sets the epoch for tests and typesetting",
        type  = "string"
      },
    file =
      {
        desc  = "Take the upload announcement from the given file",
        short = "F",
        type  = "string"
      },
    first =
      {
        desc  = "Name of first test to run",
        type  = "string"
      },
    force =
      {
        desc  = "Force tests to run if engine is not set up",
        short = "f",
        type  = "boolean"
      },
    full =
      {
        desc = "Install all files",
        type = "boolean"
      },
    ["halt-on-error"] =
      {
        desc  = "Stops running tests after the first failure",
        short = "H",
        type  = "boolean"
      },
    help =
      {
        desc  = "Print this message and exit",
        short = "h",
        type  = "boolean"
      },
    last =
      {
        desc  = "Name of last test to run",
        type  = "string"
      },
    message =
      {
        desc  = "Text for upload announcement message",
        short = "m",
        type  = "string"
      },
    quiet =
      {
        desc  = "Suppresses TeX output when unpacking",
        short = "q",
        type  = "boolean"
      },
    rerun =
      {
        desc  = "Skip setup: simply rerun tests",
        type  = "boolean"
      },
    ["show-log-on-error"] =
      {
        desc  = "If 'halt-on-error' stops, show the full log of the failure",
        type  = "boolean"
      },
    shuffle =
      {
        desc  = "Shuffle order of tests",
        type  = "boolean"
      },
    texmfhome =
      {
        desc = "Location of user texmf tree",
        type = "string"
      },
    version =
      {
        desc = "Print version information and exit",
        type = "boolean"
      }
  }

-- Build the `options` table of the receiver
-- by parsing the command line arguments.
-- @param arg The standard argument table
L3.parse_arg = function (self, arg)
  local options = {
    -- target = nil,
    -- names = nil,
    -- engine = nil,
    -- force = nil,
    -- dirty = nil,
    -- rerun = nil,
    -- first = nil,
    -- last = nil,
    -- shuffle = nil,
    -- texmfhome = nil,
    -- full = nil,
    -- ["dry-run"] = nil,
    -- date = nil,
    -- quiet = nil,
    -- file = nil,
    -- email = nil,
    -- message = nil,
    -- debug = nil,
    -- epoch = nil,
    -- config = nil,
  }
  local names  = { }
  local long_options =  { }
  local short_options = { }
  -- Turn long/short options into two lookup tables
  for k,v in pairs(self.option_list) do
    if v.short then
      short_options[v.short] = k
    end
    long_options[k] = k
  end
  -- arg[1] is a special case: must be a command or "-h"/"--help"
  -- Deal with this by assuming help and storing only apparently-valid
  -- input
  local a = arg[1]
  options.target = "help"
  if a then
    -- No options are allowed in position 1, so filter those out
    if a == "--version" then
      options.target = "version"
    elseif not a:match("^%-") then
      options.target = a
    end
  end
  -- Stop here if help or version is required
  if options.target == "help" or options.target == "version" then
    self.options = options
    return
  end
  -- An auxiliary to grab all file names into a table
  local function remainder(num)
    local t = { }
    for i = num, #arg do
      t[#t+1] = arg[i]
    end
    return t
  end
  -- Examine all other arguments
  -- Use a while loop rather than for as this makes it easier
  -- to grab arg for optionals where appropriate
  local i = 2
  while i <= #arg do
    local a = arg[i]
    -- Terminate search for options
    if a == "--" then
      names = remainder(i + 1)
      break
    end
    -- Look for optionals
    local opt
    local optarg
    local opts
    -- Look for and option and get it into a variable
    if a:match("^%-") then
      if a:match("^%-%-") then
        opts = long_options
        local pos = a:find("=", 1, true)
        if pos then
          opt    = a:sub(3, pos - 1)
          optarg = a:sub(pos + 1)
        else
          opt = a:sub(3)
        end
      else
        opts = short_options
        opt  = a:sub(2, 2)
        -- Only set optarg if it is there
        if #a > 2 then
          optarg = a:sub(3)
        end
      end
      -- Now check that the option is valid and sort out the argument
      -- if required
      local optname = opts[opt]
      if optname then
        -- Tidy up arguments
        if self.option_list[optname].type == "boolean" then
          if optarg then
            local opt = "-" .. (a:match("^%-%-") and "-" or "") .. opt
            io.stderr:write("Value not allowed for option " .. opt .."\n")
            return
          end
        else
         if not optarg then
          optarg = arg[i + 1]
          if not optarg then
            io.stderr:write("Missing value for option " .. a .."\n")
            return
          end
          i = i + 1
         end
        end
      else
        io.stderr:write("Unknown option " .. a .."\n")
        return
      end
      -- Store the result
      if optarg then
        if option_list[optname].type == "string" then
          options[optname] = optarg
        else
          local opts = options[optname] or { }
          for hit in optarg:gmatch("([^,%s]+)") do
            opts[#opts + 1] = hit
          end
          options[optname] = opts
        end
      else
        options[optname] = true
      end
      i = i + 1
    end
    if not opt then
      names = remainder(i)
      break
    end
  end
  if next(names) then
   options.names = names
  end
  self.options = options
  return options
end
