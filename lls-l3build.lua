-- This meta file is never included nor loaded
-- It contains l3build related declarations that are used for linting
-- with the Lua Language Server
-- The extra comments are useful in development mode
-- but should not be archived with the bundle
--
-- More declarations will appear here as soon as needed.

---@meta l3build 

---@class L3BuildLib
----@field root_dir string
----@field script_path string

---@alias L3BuildTestRewrite fun(input: string, output: string, engine: string, errlevels: integer[])

---@alias L3BuildTestCompare fun(difffile: string, tlgfile: string, logfile: string, cleanup: boolean, name: string, engine: string): integer

---@class L3BTestType
---@field test string the extension of the test file run by a check engine
---@field reference string? the extension of the file the output is compared with
---@field generated string? extension of the analyzed output file
---@field expectation string? Extension of expectation
---@field compare L3BuildTestCompare? 
---@field rewrite L3BuildTestRewrite?
---@field naming (fun(name: string, engine: string): string)? 
---@field skip (fun(name: string, engine: string): boolean?)? 

---@type L3BTestType[]
test_types = {} -- never executed

---@type string[]
test_order = {} -- never executed

---comment
---@param dir string
function mkdir(dir)
  return 0
end

forcecheckruns = false -- Always run `checkruns` runs and never stop early (never executed)

---Writes the argument to the output, including tables 
---@param x any
actual = function(x) end -- (never executed)

---@class L3BTestGenerator
l3btest = {}

---write
---@param name string
---@param unknown any
function write(name, unknown) end -- (never defined)

---Execute the given function only on proper system type
---@param type "windows"|"msdos"|"unix"
---@param f fun(...):...
---@param ... unknown
function on_os_type(type, f, ...) end -- (never defined)

PASS = true -- (never executed)
FAIL = false -- (never executed)

---@class L3BTargetType
---@field func fun(names: string[]): integer main function
---@field desc string? description
---@field bundle_func fun(names: string[]): integer A variant of func used when at the top level of a bundle
---@field bundle_target boolean? A boolean to specify that when passing the target name in a bundle, it should have bundle prepended
---@field pre fun(names: string[]): integer A function executed before the main function, this allows checking of the name data without impact on the main func.

---@class declaretarget_kvargs: L3BTargetType
---@field already "override"|"replace"? what to do if the target already exists
