# Scripts

## Modes

Adding new capabilities to `l3build` must be done with great care to guarantee a complete backward compatibility.
In order to ensure that nothing can break, one solution is to maintain different tools for different tasks.
When `l3build` is called as usual, nothing changes, but when it is called with a new dedicated syntax, then it switches to a new main script.

There are 2 modes: `unit` for unit testing and `advanced` for experimental enhancements.

```
$ l3build --unit ...
$ l3build --advanced ...
```

When `l3build` detects one of this modes, it transfers control to `l3build-main-<mode>.lua`. Then the auxiliary modules used are firstly in the `script/` directory then in the main directory.

## Boot

The booting process is the detection of the directory containing the scripts to load. This is straightforward with `kpse` help unless developping `l3build` itself.

Some setup is necessary to make `require` find the correct module.


