///|
using @syntax {
  type Argument,
  type Binder,
  type Case,
  type DeclBody,
  type Expr,
  type FieldDef,
  type Func,
  type InterpElem,
  type LexCase,
  type ListComprehensionKind,
  type Impl,
  type Label,
  type LongIdent,
  type MapExprElem,
  type SpreadableElem,
  type Type,
  type TypeName,
}

///|
/// A complexity score score for a top-level function or method.
///
/// `name` is the source-level function name. Methods are reported as
/// `Type::method`.
pub(all) struct FunctionScore {
  name : String
  score : Int
}

///|
/// Parse MoonBit source text and score every top-level function body.
///
/// Invalid source returns an empty result because the parser diagnostics make
/// the AST unreliable for scoring.
pub fn score_source(source : String) -> Array[FunctionScore] {
  let (items, reports) = @parser.parse_string(source, name="source")
  score_items(items, reports)
}

///|
/// Parse a MoonBit source file and score every top-level function body.
pub fn score_file(path : String) -> Array[FunctionScore] raise @fs.IOError {
  let (items, reports) = @parser.parse_file(path)
  score_items(items, reports)
}

///|
/// Convert parsed top-level declarations into scores.
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
            DeclBody::DeclBody(expr~) => {
              let name = function_name(fun_decl.type_name, fun_decl.name.name)
              scores.push({
                name,
                score: score_expr(expr, 0, current_function=fun_decl.name.name),
              })
            }
            _ => ()
          }
        _ => ()
      }
    })
    scores
  }
}

///|
/// Build the display name used in reports.
fn function_name(type_name : TypeName?, name : String) -> String {
  match type_name {
    Some(type_name) => long_ident_name(type_name.name) + "::" + name
    None => name
  }
}

///|
/// Render a parser long identifier using dot notation.
fn long_ident_name(name : LongIdent) -> String {
  match name {
    LongIdent::Ident(name~) => name
    LongIdent::Dot(pkg~, id~) => pkg + "." + id
  }
}

///|
/// Score a structural increment at the current nesting depth.
fn structural(nesting : Int) -> Int {
  1 + nesting
}

///|
/// Score an expression tree using Sonar-style complexity score rules.
fn score_expr(
  expr : Expr,
  nesting : Int,
  current_function? : String = "",
) -> Int {
  score_control_expr(expr, nesting, current_function~)
}

///|
/// Score control-flow constructs that create structural increments.
fn score_control_expr(
  expr : Expr,
  nesting : Int,
  current_function~ : String,
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
    Expr::LexMatch(expr=matched, cases~, match_loc~, loc~, strategy~) => {
      ignore(strategy)
      ignore(match_loc)
      ignore(loc)
      score_expr(matched, nesting, current_function~) +
      structural(nesting) +
      score_lex_cases(cases, nesting + 1, current_function~)
    }
    Expr::While(loop_cond~, loop_body~, while_else~, label~, loc~) => {
      ignore(label)
      ignore(loc)
      score_logical(loop_cond) +
      structural(nesting) +
      score_expr(loop_body, nesting + 1, current_function~) +
      score_optional_expr(while_else, nesting, current_function~)
    }
    Expr::For(
      binders~,
      condition~,
      continue_block~,
      body~,
      for_else~,
      where_clause~,
      label~,
      loc~
    ) => {
      ignore(label)
      ignore(where_clause)
      ignore(loc)
      score_binder_exprs(binders, nesting, current_function~) +
      score_optional_logical(condition) +
      score_binder_exprs(continue_block, nesting, current_function~) +
      structural(nesting) +
      score_expr(body, nesting + 1, current_function~) +
      score_optional_expr(for_else, nesting, current_function~)
    }
    Expr::ForEach(
      binders~,
      expr=iterated,
      init~,
      continue_block~,
      body~,
      else_block~,
      where_clause~,
      label~,
      loc~
    ) => {
      ignore(binders)
      ignore(label)
      ignore(where_clause)
      ignore(loc)
      score_expr(iterated, nesting, current_function~) +
      score_binder_exprs(init, nesting, current_function~) +
      score_binder_exprs(continue_block, nesting, current_function~) +
      structural(nesting) +
      score_expr(body, nesting + 1, current_function~) +
      score_optional_expr(else_block, nesting, current_function~)
    }
    Expr::Try(
      body~,
      catch_~,
      try_else~,
      has_try~,
      try_loc~,
      catch_loc~,
      else_loc~,
      loc~
    ) => {
      ignore(has_try)
      ignore(try_loc)
      ignore(catch_loc)
      ignore(else_loc)
      ignore(loc)
      score_expr(body, nesting, current_function~) +
      score_catch_cases(catch_, nesting, current_function~) +
      score_optional_cases(try_else, nesting, current_function~)
    }
    Expr::Guard(cond~, otherwise~, body~, loc~) => {
      ignore(loc)
      score_logical(cond) +
      structural(nesting) +
      score_optional_expr(otherwise, nesting + 1, current_function~) +
      score_expr(body, nesting, current_function~)
    }
    _ => score_binding_expr(expr, nesting, current_function~)
  }
}

///|
/// Score binding and local function constructs.
fn score_binding_expr(
  expr : Expr,
  nesting : Int,
  current_function~ : String,
) -> Int {
  match expr {
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
    Expr::LetFn(name~, func~, body~, loc~) => {
      ignore(name)
      ignore(loc)
      score_func(func, nesting + 1, current_function~) +
      score_expr(body, nesting, current_function~)
    }
    Expr::LetAnd(bindings~, body~, loc~) => {
      ignore(loc)
      score_let_and_bindings(bindings, nesting + 1, current_function~) +
      score_expr(body, nesting, current_function~)
    }
    Expr::Sequence(exprs~, last_expr~, loc~) => {
      ignore(loc)
      score_exprs(exprs, nesting, current_function~) +
      score_expr(last_expr, nesting, current_function~)
    }
    Expr::Function(func~, loc~) => {
      ignore(loc)
      score_func(func, nesting + 1, current_function~)
    }
    _ => score_jump_expr(expr, nesting, current_function~)
  }
}

///|
/// Score explicit jumps and raised values.
fn score_jump_expr(
  expr : Expr,
  nesting : Int,
  current_function~ : String,
) -> Int {
  match expr {
    Expr::Break(arg~, label~, loc~) => {
      ignore(loc)
      score_optional_expr(arg, nesting, current_function~) + score_label(label)
    }
    Expr::Continue(args~, label~, loc~) => {
      ignore(loc)
      score_exprs(args, nesting, current_function~) + score_label(label)
    }
    Expr::Return(return_value~, loc~) => {
      ignore(loc)
      score_optional_expr(return_value, nesting, current_function~)
    }
    Expr::Raise(err_value~, loc~) => {
      ignore(loc)
      score_expr(err_value, nesting, current_function~)
    }
    _ => score_collection_expr(expr, nesting, current_function~)
  }
}

///|
/// Labeled break and continue count as fundamental increments.
fn score_label(label : Label?) -> Int {
  match label {
    Some(_) => 1
    None => 0
  }
}

///|
/// Score collection, record, map, and interpolation expressions.
fn score_collection_expr(
  expr : Expr,
  nesting : Int,
  current_function~ : String,
) -> Int {
  match expr {
    Expr::Array(exprs~, loc~) | Expr::Tuple(exprs~, loc~) => {
      ignore(loc)
      score_exprs(exprs, nesting, current_function~)
    }
    Expr::ArraySpread(elems~, loc~) => {
      ignore(loc)
      score_spreadable_elems(elems, nesting, current_function~)
    }
    Expr::ListComprehension(kind~, guard_~, body~, loc~) => {
      ignore(loc)
      score_list_comprehension_kind(kind, nesting, current_function~) +
      score_optional_logical(guard_) +
      structural(nesting) +
      score_expr(body, nesting + 1, current_function~)
    }
    Expr::ArrayGet(array~, index~, loc~) => {
      ignore(loc)
      score_expr(array, nesting, current_function~) +
      score_expr(index, nesting, current_function~)
    }
    Expr::ArrayGetSlice(array~, start_index~, end_index~, loc~, index_loc~) => {
      ignore(loc)
      ignore(index_loc)
      score_expr(array, nesting, current_function~) +
      score_optional_expr(start_index, nesting, current_function~) +
      score_optional_expr(end_index, nesting, current_function~)
    }
    Expr::ArraySet(array~, index~, value~, loc~)
    | Expr::ArrayAugmentedSet(array~, index~, value~, loc~, ..) => {
      ignore(loc)
      score_expr(array, nesting, current_function~) +
      score_expr(index, nesting, current_function~) +
      score_expr(value, nesting, current_function~)
    }
    Expr::Interp(elems~, loc~) => {
      ignore(loc)
      score_interp_elems(elems, nesting, current_function~)
    }
    Expr::Record(fields~, loc~, ..) => {
      ignore(loc)
      score_fields(fields, nesting, current_function~)
    }
    Expr::RecordUpdate(record~, fields~, loc~, ..) => {
      ignore(loc)
      score_expr(record, nesting, current_function~) +
      score_fields(fields, nesting, current_function~)
    }
    Expr::Map(elems~, loc~) => {
      ignore(loc)
      score_map_elems(elems, nesting, current_function~)
    }
    _ => score_wrapper_expr(expr, nesting, current_function~)
  }
}

///|
/// Score wrapper expressions that delegate complexity to their inner values.
fn score_wrapper_expr(
  expr : Expr,
  nesting : Int,
  current_function~ : String,
) -> Int {
  match expr {
    Expr::Constraint(expr=inner, loc~, ..)
    | Expr::As(expr=inner, loc~, ..)
    | Expr::Group(expr=inner, loc~, ..)
    | Expr::ProofAssert(expr=inner, loc~)
    | Expr::TryOperator(body=inner, loc~, ..) => {
      ignore(loc)
      score_expr(inner, nesting, current_function~)
    }
    Expr::Is(expr=inner, loc~, ..)
    | Expr::IsLexMatch(expr=inner, loc~, ..)
    | Expr::RegexMatch(expr=inner, loc~, ..)
    | Expr::Field(record=inner, loc~, ..) => {
      ignore(loc)
      score_expr(inner, nesting, current_function~)
    }
    Expr::Defer(expr=deferred, body~, loc~)
    | Expr::Pipe(lhs=deferred, rhs=body, loc~)
    | Expr::RevPipe(lhs=deferred, rhs=body, loc~)
    | Expr::TemplateWriting(expr=deferred, template=body, loc~)
    | Expr::Implies(lhs=deferred, rhs=body, loc~) => {
      ignore(loc)
      score_expr(deferred, nesting, current_function~) +
      score_expr(body, nesting, current_function~)
    }
    _ => score_call_expr(expr, nesting, current_function~)
  }
}

///|
/// Score calls, infix operators, mutation, and proof-related expressions.
fn score_call_expr(
  expr : Expr,
  nesting : Int,
  current_function~ : String,
) -> Int {
  match expr {
    Expr::Infix(op~, lhs~, rhs~, loc~) => {
      ignore(loc)
      if is_logical_op(op.name) {
        score_logical(expr) +
        score_logical_operands(expr, nesting, current_function~)
      } else {
        score_expr(lhs, nesting, current_function~) +
        score_expr(rhs, nesting, current_function~)
      }
    }
    Expr::Unary(expr=inner, loc~, op~) => {
      ignore(op)
      ignore(loc)
      score_expr(inner, nesting, current_function~)
    }
    Expr::Apply(func~, args~, loc~) => {
      ignore(loc)
      score_expr(func, nesting, current_function~) +
      score_arguments(args, nesting, current_function~) +
      score_recursive_call(func, current_function)
    }
    Expr::DotApply(self~, args~, loc~, ..) => {
      ignore(loc)
      score_expr(self, nesting, current_function~) +
      score_arguments(args, nesting, current_function~) +
      score_method_recursive_call(expr, current_function)
    }
    Expr::Mutate(record~, field~, loc~, ..) => {
      ignore(loc)
      score_expr(record, nesting, current_function~) +
      score_expr(field, nesting, current_function~)
    }
    Expr::Assign(expr=assigned, loc~, ..)
    | Expr::ProofLet(expr=assigned, loc~, ..) => {
      ignore(loc)
      score_expr(assigned, nesting, current_function~)
    }
    Expr::Quantifier(body~, loc~, ..) => {
      ignore(loc)
      score_expr(body, nesting, current_function~)
    }
    Expr::StaticAssert(body~, ..) =>
      score_expr(body, nesting, current_function~)
    _ => 0
  }
}

///|
/// Score an `else` branch while preserving `else if` chain semantics.
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
/// Score an optional expression, returning zero for absent syntax.
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
/// Score logical operator sequences in an optional condition.
fn score_optional_logical(expr : Expr?) -> Int {
  match expr {
    Some(expr) => score_logical(expr)
    None => 0
  }
}

///|
/// Sum expression scores for parser lists.
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
/// Sum scores for loop binder initializer and continuation expressions.
fn score_binder_exprs(
  exprs : @list.List[(Binder, Expr)],
  nesting : Int,
  current_function~ : String,
) -> Int {
  let mut score = 0
  exprs.each(fn(pair) {
    score = score + score_expr(pair.1, nesting, current_function~)
  })
  score
}

///|
/// Score match cases without adding a branch increment for each case.
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
/// Score optional case lists such as `try else`.
fn score_optional_cases(
  cases : @list.List[Case]?,
  nesting : Int,
  current_function~ : String,
) -> Int {
  match cases {
    Some(cases) => score_cases(cases, nesting, current_function~)
    None => 0
  }
}

///|
/// Score catch cases as structural branches.
fn score_catch_cases(
  cases : @list.List[Case],
  nesting : Int,
  current_function~ : String,
) -> Int {
  let mut score = 0
  cases.each(fn(case_) {
    score = score +
      score_optional_expr(case_.guard_, nesting, current_function~) +
      structural(nesting) +
      score_expr(case_.body, nesting + 1, current_function~)
  })
  score
}

///|
/// Score lexical match cases without per-case branch increments.
fn score_lex_cases(
  cases : @list.List[LexCase],
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
/// Sum scores for call arguments.
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
/// Score a function body at the supplied nesting depth.
fn score_func(func : Func, nesting : Int, current_function~ : String) -> Int {
  score_expr(func.body, nesting, current_function~)
}

///|
/// Score mutually-bound local functions.
fn score_let_and_bindings(
  bindings : @list.List[(Binder, Type?, Func)],
  nesting : Int,
  current_function~ : String,
) -> Int {
  let mut score = 0
  bindings.each(fn(binding) {
    score = score + score_func(binding.2, nesting, current_function~)
  })
  score
}

///|
/// Sum scores for record fields.
fn score_fields(
  fields : @list.List[FieldDef],
  nesting : Int,
  current_function~ : String,
) -> Int {
  let mut score = 0
  fields.each(fn(field) {
    score = score + score_expr(field.expr, nesting, current_function~)
  })
  score
}

///|
/// Sum scores for map expression elements.
fn score_map_elems(
  elems : @list.List[MapExprElem],
  nesting : Int,
  current_function~ : String,
) -> Int {
  let mut score = 0
  elems.each(fn(elem) {
    score = score + score_expr(elem.expr, nesting, current_function~)
  })
  score
}

///|
/// Sum scores for regular and spread array elements.
fn score_spreadable_elems(
  elems : @list.List[SpreadableElem],
  nesting : Int,
  current_function~ : String,
) -> Int {
  let mut score = 0
  elems.each(fn(elem) {
    let inc = match elem {
      SpreadableElem::Regular(expr) =>
        score_expr(expr, nesting, current_function~)
      SpreadableElem::Spread(expr~, loc~) => {
        ignore(loc)
        score_expr(expr, nesting, current_function~)
      }
    }
    score = score + inc
  })
  score
}

///|
/// Sum scores for interpolation expressions while ignoring literal segments.
fn score_interp_elems(
  elems : @list.List[InterpElem],
  nesting : Int,
  current_function~ : String,
) -> Int {
  let mut score = 0
  elems.each(fn(elem) {
    let inc = match elem {
      InterpElem::Expr(expr~, loc~) => {
        ignore(loc)
        score_expr(expr, nesting, current_function~)
      }
      InterpElem::Literal(_) | InterpElem::Source(_) => 0
    }
    score = score + inc
  })
  score
}

///|
/// Score list-comprehension loop clauses.
fn score_list_comprehension_kind(
  kind : ListComprehensionKind,
  nesting : Int,
  current_function~ : String,
) -> Int {
  match kind {
    ListComprehensionKind::Foreach(expr=iterated, init~, continue_block~, ..) =>
      score_expr(iterated, nesting, current_function~) +
      score_binder_exprs(init, nesting, current_function~) +
      score_binder_exprs(continue_block, nesting, current_function~)
    ListComprehensionKind::For(binders~, condition~, continue_block~, ..) =>
      score_binder_exprs(binders, nesting, current_function~) +
      score_optional_logical(condition) +
      score_binder_exprs(continue_block, nesting, current_function~)
  }
}

///|
/// Add one increment for direct recursive free-function calls.
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
/// Add one increment for direct recursive method calls.
fn score_method_recursive_call(expr : Expr, current_function : String) -> Int {
  match expr {
    Expr::DotApply(method_name~, loc~, ..) => {
      ignore(loc)
      if method_name.name == current_function {
        1
      } else {
        0
      }
    }
    _ => 0
  }
}

///|
/// Count logical operator sequences in an expression.
fn score_logical(expr : Expr) -> Int {
  logical_sequences(expr, "")
}

///|
/// Return one when the operator is a logical sequence operator.
fn score_logical_op(op : LongIdent) -> Int {
  match op {
    LongIdent::Ident(name="&&") | LongIdent::Ident(name="||") => 1
    _ => 0
  }
}

///|
/// Test whether an operator starts or continues a logical sequence.
fn is_logical_op(op : LongIdent) -> Bool {
  score_logical_op(op) == 1
}

///|
/// Score non-logical operands inside a logical operator tree.
fn score_logical_operands(
  expr : Expr,
  nesting : Int,
  current_function~ : String,
) -> Int {
  match expr {
    Expr::Infix(op~, lhs~, rhs~, loc~) => {
      ignore(loc)
      if is_logical_op(op.name) {
        score_logical_operands(lhs, nesting, current_function~) +
        score_logical_operands(rhs, nesting, current_function~)
      } else {
        score_expr(expr, nesting, current_function~)
      }
    }
    _ => score_expr(expr, nesting, current_function~)
  }
}

///|
/// Count changes between logical operator sequences.
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
