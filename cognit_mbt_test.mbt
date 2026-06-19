///|
test "straight-line function has zero cognitive complexity" {
  let source =
    #|fn add(a : Int, b : Int) -> Int {
    #|  let sum = a + b
    #|  sum
    #|}
  let scores = @cognit_mbt.score_source(source)
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
  let scores = @cognit_mbt.score_source(source)
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
  let scores = @cognit_mbt.score_source(source)
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
  let scores = @cognit_mbt.score_source(source)
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
  let scores = @cognit_mbt.score_source(source)
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
  let scores = @cognit_mbt.score_source(source)
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
  let scores = @cognit_mbt.score_source(source)
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
  let scores = @cognit_mbt.score_source(source)
  assert_eq(scores[0].score, 2)
}
