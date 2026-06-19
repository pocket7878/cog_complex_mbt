# cog_complex

MoonBit projects can run this tool to measure a Cognitive Complexity score for
each top-level function and method in `.mbt` files.

`cog_complex` reports a small integer for each function using a
Cognitive-Complexity-style model, where a higher number means the control flow
is harder to read. It is not a general complexity analyzer for time complexity,
space complexity, or cyclomatic complexity. The implementation is specific to
MoonBit and works from `moonbitlang/parser` AST nodes.

## Installation

Install the published command from mooncakes.io:

```sh
moon install pocket7878/cog_complex/cmd/cog_complex
cog_complex path/to/moonbit/project
```

Use it from this repository with `moon run`:

```sh
moon run cmd/cog_complex -- path/to/moonbit/project
```

Or install the command locally from a checkout:

```sh
moon install ./cmd/cog_complex
cog_complex path/to/moonbit/project
```

If no path is passed, the current directory is scanned recursively. `_build`,
`.mooncakes`, and `.git` are skipped.

## Usage

Scan the current project:

```sh
moon run cmd/cog_complex -- .
```

Scan a single package, directory, or file:

```sh
moon run cmd/cog_complex -- src
moon run cmd/cog_complex -- src/parser
moon run cmd/cog_complex -- src/parser/token.mbt
```

Output is line oriented:

```text
src/main/main.mbt:main  3
```

Each line has:

```text
<path>:<function-or-method-name>  <complexity-score>
```

Methods are reported as `Type::method`:

```text
src/counter.mbt:Counter::sign  1
```

For a simple local quality gate, combine the output with a small script and
fail CI when any function is over your threshold. This project keeps all
functions at `15` or below:

```sh
moon run cmd/cog_complex -- . | awk '$NF > 15 { print; bad = 1 } END { exit bad }'
```

## How Scores Are Counted

The Cognitive Complexity score starts at `0` for each top-level function or
method. Control-flow syntax adds structural increments, and nested control flow
adds more.

For example, an `else if` chain adds one point per branch:

```moonbit nocheck
///|
fn words(n : Int) -> String {
  if n == 1 { // +1
    "one"
  } else if n == 2 { // +1
    "two"
  } else {
    "many"
  }
} // Complexity score = 2
```

A `match` is usually easier to scan because cases do not each add a branch
increment:

```moonbit nocheck
///|
fn words(n : Int) -> String {
  match n { // +1
    1 => "one"
    2 => "two"
    _ => "many"
  }
} // Complexity score = 1
```

Nested loops and nested branches include the current nesting depth:

```moonbit nocheck
///|
fn first_positive(rows : Array[Array[Int]]) -> Int {
  for row in rows { // +1
    for x in row { // +2 (nesting = 1)
      if x > 0 { // +3 (nesting = 2)
        return x
      }
    }
  }
  0
} // Complexity score = 6
```

Labeled jumps add a fundamental increment because the reader has to track the
target label:

```moonbit nocheck
///|
fn scan(xs : Array[Int]) -> Int {
  outer~: for i = 0; i < xs.length(); i = i + 1 { // +1
    if xs[i] < 0 { // +2
      break outer~ // +1
    }
  }
  0
} // Complexity score = 4
```

## Current Rules

The scoring model follows Cognitive Complexity principles for structured code:

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

## Development

Run the full validation loop:

```sh
moon test
moon coverage analyze
moon coverage report -f summary
moon run cmd/cog_complex -- .
moon info
moon fmt
```

The repository currently uses `85%` coverage and a maximum Cognitive Complexity
score of `15` as quality gates.

## Publish Checklist

Before publishing:

```sh
moon test
moon coverage analyze
moon coverage report -f summary
moon run cmd/cog_complex -- .
moon info
moon fmt
moon package --list
moon install --dry-run ./cmd/cog_complex
```

`moon package --list` should complete without manifest warnings, and
`moon install --dry-run ./cmd/cog_complex` should report that it would install
the `cog_complex` binary.
