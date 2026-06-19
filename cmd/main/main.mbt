///|
fn main {
  let args = @sys.get_cli_args()
  let root = if args.length() > 1 { args[1] } else { "." }
  let files = Array::new()
  collect_mbt_files(root, files) catch {
    err => {
      ignore(err)
      println("error: failed to read path \{root}")
      @sys.exit(2)
    }
  }
  for file in files {
    let scores : Array[@lib.FunctionScore] = @lib.score_file(file) catch {
      err => {
        ignore(err)
        println("error: failed to parse \{file}")
        @sys.exit(2)
        []
      }
    }
    for score in scores {
      println("\{file}:\{score.name}  \{score.score}")
    }
  }
}

///|
fn collect_mbt_files(
  path : String,
  files : Array[String],
) -> Unit raise @fs.IOError {
  if @fs.is_file(path) {
    if path.has_suffix(".mbt") {
      files.push(path)
    }
  } else if @fs.is_dir(path) {
    for child in @fs.read_dir(path) {
      if child != "_build" && child != ".mooncakes" && child != ".git" {
        collect_mbt_files(join_path(path, child), files)
      }
    }
  }
}

///|
fn join_path(parent : String, child : String) -> String {
  if parent.has_suffix("/") {
    parent + child
  } else {
    parent + "/" + child
  }
}
