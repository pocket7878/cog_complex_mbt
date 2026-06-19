///|
using @syntax {
  type Argument,
  type Case,
  type DeclBody,
  type Expr,
  type Impl,
  type LongIdent,
}

///|
pub(all) struct FunctionScore {
  name : String
  score : Int
}

///|
pub fn score_source(source : String) -> Array[FunctionScore] {
  let (items, reports) = @parser.parse_string(source, name="source")
  score_items(items, reports)
}

///|
pub fn score_file(path : String) -> Array[FunctionScore] raise @fs.IOError {
  let (items, reports) = @parser.parse_file(path)
  score_items(items, reports)
}

///|
fn score_items(
  items : @list.List[Impl],
  reports : Array[@basic.Report],
) -> Array[FunctionScore] {
  if reports.length() > 0 {
    []
  } else {
    let scores = Array::new()
    items.each(fn(item) {
      match item {
        Impl::TopFuncDef(fun_decl~, decl_body~, ..) =>
          match decl_body {
            DeclBody::DeclBody(expr~) =>
              scores.push({
                name: fun_decl.name.name,
                score: score_expr(expr, 0, current_function=fun_decl.name.name),
              })
            _ => ()
          }
        _ => ()
      }
    })
    scores
  }
}

///|
fn structural(nesting : Int) -> Int {
  1 + nesting
}

///|
fn score_expr(
  expr : Expr,
  nesting : Int,
  current_function? : String = "",
) -> Int {
  match expr {
    Expr::If(cond~, ifso~, ifnot~, loc~) => {
      ignore(loc)
      score_logical(cond) +
      structural(nesting) +
      score_expr(ifso, nesting + 1, current_function~) +
      score_else(ifnot, nesting, current_function~)
    }
    Expr::Match(expr=matched, cases~, match_loc~, loc~) => {
      ignore(match_loc)
      ignore(loc)
      score_expr(matched, nesting, current_function~) +
      structural(nesting) +
      score_cases(cases, nesting + 1, current_function~)
    }
    Expr::While(loop_cond~, loop_body~, while_else~, label~, loc~) => {
      ignore(label)
      ignore(loc)
      score_logical(loop_cond) +
      structural(nesting) +
      score_expr(loop_body, nesting + 1, current_function~) +
      score_optional_expr(while_else, nesting, current_function~)
    }
    Expr::Infix(op~, lhs~, rhs~, loc~) => {
      ignore(loc)
      score_expr(lhs, nesting, current_function~) +
      score_expr(rhs, nesting, current_function~) +
      score_logical_op(op.name)
    }
    Expr::Apply(func~, args~, loc~) => {
      ignore(loc)
      score_expr(func, nesting, current_function~) +
      score_arguments(args, nesting, current_function~) +
      score_recursive_call(func, current_function)
    }
    Expr::Let(pattern~, expr=bound, body~, loc~) => {
      ignore(pattern)
      ignore(loc)
      score_expr(bound, nesting, current_function~) +
      score_expr(body, nesting, current_function~)
    }
    Expr::LetMut(binder~, ty~, expr=bound, body~, loc~) => {
      ignore(binder)
      ignore(ty)
      ignore(loc)
      score_expr(bound, nesting, current_function~) +
      score_expr(body, nesting, current_function~)
    }
    Expr::Sequence(exprs~, last_expr~, loc~) => {
      ignore(loc)
      score_exprs(exprs, nesting, current_function~) +
      score_expr(last_expr, nesting, current_function~)
    }
    _ => 0
  }
}

///|
fn score_else(ifnot : Expr?, nesting : Int, current_function~ : String) -> Int {
  match ifnot {
    Some(Expr::If(cond~, ifso~, ifnot~, loc~)) => {
      ignore(loc)
      score_logical(cond) +
      1 +
      score_expr(ifso, nesting + 1, current_function~) +
      score_else(ifnot, nesting, current_function~)
    }
    Some(expr) => score_expr(expr, nesting + 1, current_function~)
    None => 0
  }
}

///|
fn score_optional_expr(
  expr : Expr?,
  nesting : Int,
  current_function~ : String,
) -> Int {
  match expr {
    Some(expr) => score_expr(expr, nesting, current_function~)
    None => 0
  }
}

///|
fn score_exprs(
  exprs : @list.List[Expr],
  nesting : Int,
  current_function~ : String,
) -> Int {
  let mut score = 0
  exprs.each(fn(expr) {
    score = score + score_expr(expr, nesting, current_function~)
  })
  score
}

///|
fn score_cases(
  cases : @list.List[Case],
  nesting : Int,
  current_function~ : String,
) -> Int {
  let mut score = 0
  cases.each(fn(case_) {
    score = score +
      score_optional_expr(case_.guard_, nesting, current_function~) +
      score_expr(case_.body, nesting, current_function~)
  })
  score
}

///|
fn score_arguments(
  args : @list.List[Argument],
  nesting : Int,
  current_function~ : String,
) -> Int {
  let mut score = 0
  args.each(fn(arg) {
    score = score + score_expr(arg.value, nesting, current_function~)
  })
  score
}

///|
fn score_recursive_call(func : Expr, current_function : String) -> Int {
  match func {
    Expr::Ident(id~, loc~) => {
      ignore(loc)
      match id.name {
        LongIdent::Ident(name~) => if name == current_function { 1 } else { 0 }
        _ => 0
      }
    }
    _ => 0
  }
}

///|
fn score_logical(expr : Expr) -> Int {
  logical_sequences(expr, "")
}

///|
fn score_logical_op(op : LongIdent) -> Int {
  match op {
    LongIdent::Ident(name="&&") | LongIdent::Ident(name="||") => 1
    _ => 0
  }
}

///|
fn logical_sequences(expr : Expr, current : String) -> Int {
  match expr {
    Expr::Infix(op~, lhs~, rhs~, loc~) => {
      ignore(loc)
      match op.name {
        LongIdent::Ident(name="&&") | LongIdent::Ident(name="||") => {
          let op_name = match op.name {
            LongIdent::Ident(name~) => name
            _ => ""
          }
          let here = if current == op_name { 0 } else { 1 }
          here +
          logical_sequences(lhs, op_name) +
          logical_sequences(rhs, op_name)
        }
        _ => logical_sequences(lhs, current) + logical_sequences(rhs, current)
      }
    }
    _ => 0
  }
}
