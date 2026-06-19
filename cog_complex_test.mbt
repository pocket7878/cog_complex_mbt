///|
test "straight-line function has zero complexity score" {
  let source =
    #|fn add(a : Int, b : Int) -> Int {
    #|  let sum = a + b
    #|  sum
    #|}
  let scores = @cog_complex.score_source(source)
  assert_eq(scores.length(), 1)
  assert_eq(scores[0].name, "add")
  assert_eq(scores[0].score, 0)
}

///|
test "single if adds one structural increment" {
  let source =
    #|fn classify(n : Int) -> Int {
    #|  if n > 0 {
    #|    1
    #|  } else {
    #|    0
    #|  }
    #|}
  let scores = @cog_complex.score_source(source)
  assert_eq(scores[0].score, 1)
}

///|
test "nested if includes nesting increment" {
  let source =
    #|fn nested(a : Bool, b : Bool) -> Int {
    #|  if a {
    #|    if b {
    #|      1
    #|    } else {
    #|      2
    #|    }
    #|  } else {
    #|    3
    #|  }
    #|}
  let scores = @cog_complex.score_source(source)
  assert_eq(scores[0].score, 3)
}

///|
test "else-if chain does not add nesting increment for chained branch" {
  let source =
    #|fn chain(n : Int) -> Int {
    #|  if n == 0 {
    #|    0
    #|  } else if n == 1 {
    #|    1
    #|  } else {
    #|    2
    #|  }
    #|}
  let scores = @cog_complex.score_source(source)
  assert_eq(scores[0].score, 2)
}

///|
test "match adds one structural increment but cases are not counted separately" {
  let source =
    #|fn classify(n : Int) -> Int {
    #|  match n {
    #|    0 => 0
    #|    1 => 1
    #|    _ => 2
    #|  }
    #|}
  let scores = @cog_complex.score_source(source)
  assert_eq(scores[0].score, 1)
}

///|
test "loop body increases nesting for nested branch" {
  let source =
    #|fn looped(xs : Array[Int]) -> Int {
    #|  let mut i = 0
    #|  while i < xs.length() {
    #|    if xs[i] > 0 {
    #|      return xs[i]
    #|    }
    #|    i = i + 1
    #|  }
    #|  0
    #|}
  let scores = @cog_complex.score_source(source)
  assert_eq(scores[0].score, 3)
}

///|
test "logical operator sequence in condition adds one increment" {
  let source =
    #|fn all(a : Bool, b : Bool, c : Bool) -> Int {
    #|  if a && b && c {
    #|    1
    #|  } else {
    #|    0
    #|  }
    #|}
  let scores = @cog_complex.score_source(source)
  assert_eq(scores[0].score, 2)
}

///|
test "recursive call adds one increment" {
  let source =
    #|fn factorial(n : Int) -> Int {
    #|  if n <= 1 {
    #|    1
    #|  } else {
    #|    n * factorial(n - 1)
    #|  }
    #|}
  let scores = @cog_complex.score_source(source)
  assert_eq(scores[0].score, 2)
}

///|
test "for loops add structural and nesting increments" {
  let source =
    #|fn find_first(xs : Array[Int]) -> Int {
    #|  for i = 0; i < xs.length(); i = i + 1 {
    #|    if xs[i] > 0 {
    #|      return xs[i]
    #|    }
    #|  }
    #|  0
    #|}
  let scores = @cog_complex.score_source(source)
  assert_eq(scores[0].score, 3)
}

///|
test "foreach loops add structural and nesting increments" {
  let source =
    #|fn any_positive(xs : Array[Int]) -> Bool {
    #|  for x in xs {
    #|    if x > 0 {
    #|      return true
    #|    }
    #|  }
    #|  false
    #|}
  let scores = @cog_complex.score_source(source)
  assert_eq(scores[0].score, 3)
}

///|
test "labeled break and continue add fundamental increments" {
  let source =
    #|fn scan(xs : Array[Int]) -> Int {
    #|  outer~: for i = 0; i < xs.length(); i = i + 1 {
    #|    if xs[i] < 0 {
    #|      break outer~
    #|    }
    #|    if xs[i] == 0 {
    #|      continue outer~
    #|    }
    #|  }
    #|  0
    #|}
  let scores = @cog_complex.score_source(source)
  assert_eq(scores[0].score, 7)
}

///|
test "unlabeled return break and continue do not add jump increments" {
  let source =
    #|fn scan(xs : Array[Int]) -> Int {
    #|  for x in xs {
    #|    if x < 0 {
    #|      break
    #|    }
    #|    if x == 0 {
    #|      continue
    #|    }
    #|    if x > 10 {
    #|      return x
    #|    }
    #|  }
    #|  0
    #|}
  let scores = @cog_complex.score_source(source)
  assert_eq(scores[0].score, 7)
}

///|
test "nested function increments nesting but has no structural increment" {
  let source =
    #|fn outer(a : Bool, b : Bool) -> Int {
    #|  fn inner() -> Int {
    #|    if a {
    #|      if b {
    #|        1
    #|      } else {
    #|        2
    #|      }
    #|    } else {
    #|      3
    #|    }
    #|  }
    #|  inner()
    #|}
  let scores = @cog_complex.score_source(source)
  assert_eq(scores[0].score, 5)
}

///|
test "try catch cases add structural and nesting increments" {
  let source =
    #|fn load(path : String) -> Int raise {
    #|  try {
    #|    read(path)
    #|  } catch {
    #|    _ => if path == "" { 0 } else { 1 }
    #|  }
    #|}
  let scores = @cog_complex.score_source(source)
  assert_eq(scores[0].score, 3)
}

///|
test "logical operator sequences are counted outside conditions once" {
  let source =
    #|fn mixed(a : Bool, b : Bool, c : Bool, d : Bool) -> Bool {
    #|  a && b || c && d
    #|}
  let scores = @cog_complex.score_source(source)
  assert_eq(scores[0].score, 3)
}

///|
test "methods are scored and named with receiver type" {
  let source =
    #|struct Counter {
    #|  value : Int
    #|}
    #|
    #|fn Counter::sign(self : Counter) -> Int {
    #|  if self.value > 0 {
    #|    1
    #|  } else {
    #|    0
    #|  }
    #|}
  let scores = @cog_complex.score_source(source)
  assert_eq(scores.length(), 1)
  assert_eq(scores[0].name, "Counter::sign")
  assert_eq(scores[0].score, 1)
}

///|
test "direct method recursion adds one increment" {
  let source =
    #|struct Nat {
    #|  value : Int
    #|}
    #|
    #|fn Nat::sum(self : Nat) -> Int {
    #|  if self.value <= 0 {
    #|    0
    #|  } else {
    #|    self.value + Nat::{ value: self.value - 1 }.sum()
    #|  }
    #|}
  let scores = @cog_complex.score_source(source)
  assert_eq(scores[0].score, 2)
}

///|
test "invalid source returns no scores" {
  let scores = @cog_complex.score_source("fn broken {")
  assert_eq(scores.length(), 0)
}

///|
test "score_file parses a MoonBit source file" {
  let scores = @cog_complex.score_file("cog_complex.mbt") catch { _ => [] }
  assert_true(scores.length() > 0)
}

///|
test "let mut sequence function literal and unary expressions are traversed" {
  let source =
    #|fn mixed(n : Int) -> Int {
    #|  let mut total = 0
    #|  total = total + n
    #|  let classify = fn(x) {
    #|    if !false && x > 0 {
    #|      1
    #|    } else {
    #|      0
    #|    }
    #|  }
    #|  classify(total)
    #|}
  let scores = @cog_complex.score_source(source)
  assert_eq(scores[0].score, 3)
}

///|
test "guard and raise expressions are traversed" {
  let source =
    #|fn guarded(n : Int) -> Int raise {
    #|  guard n > 0 else {
    #|    raise Failure("bad")
    #|  }
    #|  n
    #|}
  let scores = @cog_complex.score_source(source)
  assert_eq(scores[0].score, 1)
}

///|
test "try catch cases with guards are traversed" {
  let source =
    #|fn attempted(n : Int) -> Int {
    #|  try {
    #|    n
    #|  } catch {
    #|    _ if n > 0 => 1
    #|    _ => if n == 0 { 0 } else { -1 }
    #|  }
    #|}
  let scores = @cog_complex.score_source(source)
  assert_eq(scores[0].score, 4)
}

///|
test "collections records maps spreads and interpolation are traversed" {
  let source =
    #|struct Box {
    #|  value : Int
    #|}
    #|
    #|fn collection(n : Int) -> Int {
    #|  let xs = [1, 2, n]
    #|  let ys = [..xs, 4]
    #|  let _slice = ys[0:2]
    #|  ys[0] = ys[1]
    #|  ys[0] += 1
    #|  let box = Box::{ value: ys[0] }
    #|  let updated = { ..box, value: ys[1] }
    #|  let _map = { "value": updated.value }
    #|  let _text = "\{updated.value}"
    #|  updated.value
    #|}
  let scores = @cog_complex.score_source(source)
  assert_eq(scores[0].score, 0)
}

///|
test "wrapper pipe and type-test expressions are traversed" {
  let source =
    #|fn id(n : Int) -> Int { n }
    #|
    #|fn wrappers(n : Int) -> Int {
    #|  let grouped = (n : Int)
    #|  let _is_int = grouped is Int
    #|  grouped |> id
    #|}
  let scores = @cog_complex.score_source(source)
  assert_eq(scores.length(), 2)
  assert_eq(scores[1].score, 0)
}

///|
test "method calls that are not recursive do not add recursion increment" {
  let source =
    #|struct Nat {
    #|  value : Int
    #|}
    #|
    #|fn Nat::next(self : Nat) -> Nat {
    #|  Nat::{ value: self.value + 1 }
    #|}
    #|
    #|fn Nat::other(self : Nat) -> Nat {
    #|  self.next()
    #|}
  let scores = @cog_complex.score_source(source)
  assert_eq(scores[1].score, 0)
}

///|
test "plain calls and unary arithmetic are traversed without increments" {
  let source =
    #|fn id(n : Int) -> Int { n }
    #|
    #|fn negated(n : Int) -> Int {
    #|  id(-n)
    #|}
  let scores = @cog_complex.score_source(source)
  assert_eq(scores.length(), 2)
  assert_eq(scores[1].score, 0)
}

///|
test "list comprehensions count structural nesting" {
  let source =
    #|fn positives(xs : Array[Int]) -> Array[Int] {
    #|  [ for x in xs if x > 0 => x + 1 ]
    #|}
  let scores = @cog_complex.score_source(source)
  assert_eq(scores[0].score, 1)
}
