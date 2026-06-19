// Learn more about moon.mod configuration:
// https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html
//
// To add a dependency, run this command in your terminal:
//   moon add moonbitlang/x
//
// Or manually declare it in `import`, for example:
// import {
//   "moonbitlang/x@0.4.6",
// }

name = "pocket7878/cog_complex"

version = "0.1.0"

readme = "README.mbt.md"

repository = "https://github.com/pocket7878/cob_complex_mbt"

license = "Apache-2.0"

keywords = [ "complexity-score", "lint", "analysis", "cli" ]

description = "Complexity score analyzer for MoonBit source code"

import {
  "moonbitlang/parser@0.3.4",
  "moonbitlang/x@0.4.45",
}
