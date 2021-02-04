# Unit testing

## base

The file `base.test.lua` contains a very small set of tests to demonstrate the unit testing features.

In order to run the test, here are the possibilities from the main folder

```
  $ texlua l3build.lua --unit --test base
  $ texlua l3build-main-unit.lua --test base
```
From another directory, you provide the path to the script.

The expected output is

```
Testing base.test.lua
..
Ran 2 tests in 0.001 seconds, 2 successes, 0 failures
OK
```

