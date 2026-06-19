# cognit_mbt

MoonBit projects can run this tool to measure Cognitive Complexity for each
top-level function and method in `.mbt` files.

```sh
moon run cmd/main -- path/to/moonbit/project
```

If no path is passed, the current directory is scanned recursively. `_build`,
`.mooncakes`, and `.git` are skipped.

Output is line oriented:

```text
src/main/main.mbt:main  3
```

## Current Rules

The scoring model follows SonarSource Cognitive Complexity principles:

- structural control flow increments for `if`, `guard`, `match`, `lexmatch`,
  `for`, `foreach`, `while`, list comprehensions, and `catch` cases
- extra nesting increments for nested control flow
- `else if` chains do not add an extra nesting increment
- `match` cases are not counted as separate branches
- `try`, `try?`, `try!`, `return`, `raise`, and unlabeled `break`/`continue`
  are traversed but do not add jump increments by themselves
- labeled `break` and `continue` add one fundamental increment
- function literals and local functions add nesting level without adding a
  structural increment
- logical operator sequences add one increment per sequence, including outside
  conditions
- direct recursive function and method calls add one increment

The implementation uses `moonbitlang/parser` and analyzes MoonBit AST nodes
instead of scanning source text.
