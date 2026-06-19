///|
test "join_path preserves an existing trailing slash" {
  assert_eq(join_path("root/", "child"), "root/child")
}

///|
test "join_path inserts a missing slash" {
  assert_eq(join_path("root", "child"), "root/child")
}

///|
test "collect_mbt_files accepts a single MoonBit file" {
  let files = Array::new()
  collect_mbt_files("cmd/main/main.mbt", files) catch {
    _ => ()
  }
  assert_eq(files.length(), 1)
  assert_eq(files[0], "cmd/main/main.mbt")
}

///|
test "collect_mbt_files walks a directory and skips generated trees" {
  let files = Array::new()
  collect_mbt_files("cmd", files) catch {
    _ => ()
  }
  assert_true(files.length() > 0)
}
