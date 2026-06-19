# cognit_mbt

MoonBit projects can run this tool to measure Cognitive Complexity for each
top-level function in `.mbt` files.

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

- structural control flow increments for `if`, `match`, and `while`
- extra nesting increments for nested control flow
- `else if` chains do not add an extra nesting increment
- `match` cases are not counted as separate branches
- logical operator sequences in conditions add one increment per sequence
- direct recursive calls add one increment

The implementation uses `moonbitlang/parser` and analyzes MoonBit AST nodes
instead of scanning source text.
