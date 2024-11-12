Zig port of sorting functions by @scandum: https://github.com/scandum/quadsort

This aims to be a fairly straight-forward port, however there are key changes
made such as replacing all pointer usages with slices and refactoring goto
control-flow.


```
zig build run -Dtrace=true
```

## Status

**This is not fully complete.**

The quadsort + piposort implementations pass a few million fuzz iterations but
the other implementations have some outstanding issues and will fail after a few
thousand cases currently.

## Setup

The C implementations are vendored directly in this repo with a small header
shim to make available to Zig code.

There are two main entry point programs:
 - `main.zig`: Performs a single sort with arguments given on command-line
 - `main_fuzz.zig`: Sorts a range of data with the requested algorithm until
   failure.

Typically, I will use the fuzzer main to find a failing test-case, and then use
the `diff` shell script (in root) which is a wrapper to `main.zig` and performs
a sort of the C implementation and the Zig and does a textual diff against a
trace of each.

All sort implementations have manual tracing added to their control-flow which
can be toggled with the `-Dtrace` flag in the zig build script.
