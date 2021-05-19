# Unit testing

## Naming convention

`foo.test.lua` contains testing material for `foo.lua`.
Other files are testing utilities imported by the testing files.

## Running tests

### Running all the tests:

```texlua ../l3build.lua test```

### Running specific tests by core file name:

```texlua ../l3build.lua test os,fs,path```

It will run all the tests which file names contains one of
"os", "fs" or "path"

### Running specific tests by test name

```texlua ../l3build.lua test -p basic -p level```

It will run all the tests which names contains one of
"basic" or "level"

### Output

```
test_object_unique.test_instance ... Ok
test_object_unique.test_subclass ... Ok
test_oslib_OS ... Ok
test_oslib_base ... Ok
test_oslib_cmd_concat ... Ok
test_oslib_content ... Ok
test_oslib_os_execute ... 
Next line expectedly reads: Script file ... not found
Script file /tmp/l3build_8AoGAiX7/_WVYsqFZe/_kdN6wLQ_.luaNOT FOUND not found
Ok
test_oslib_read_command ... Ok
test_oslib_run ... Ok
test_oslib_run_process ... Ok
test_pathlib_POC_parts ... Ok
test_pathlib_Path ... Ok
test_pathlib_Path_forward_slash ... Ok
```

All lines should be "Ok".
Please notice that some spurious messages may appear.
This is sometimes a necessity because the tests are concerning some code that displays informations on the terminal.


## List of tests

By order, from the simplest.
Each test depends on the preceding ones (if any)

Only the core part of the name is mentioned.

### Core code

* corelib
* object
* pathlib
* utillib
* oslib
* fslib
* lpeglib
* env

Running these tests:

```texlua ../l3build.lua test core,obj,path,os,fs,lpeg,^env$```

### l3build models

Model for the LaTeX "module"

* modlib
* modenv
* module

* options
* targets

* globals

Running these tests:

```texlua ../l3build.lua test ^mod,options,targets```

### l3build actions

* help
* main

* unpack

Running these tests:

```texlua ../l3build.lua test core,obj,path,os,fs,lpeg,^env$```

### Extra

* manager
* autodoc
