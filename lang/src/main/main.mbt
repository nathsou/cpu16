
fn main {
    try {
      match @sys.get_cli_args() {
        [_, source_file] => {
          let prog = @fs.read_file_to_string(source_file, encoding="utf8")
          let _ = @lib.compile(prog, verbose=true)
        }
        [_, source_file, output_file] => {
          let prog = @fs.read_file_to_string(source_file, encoding="utf8")
          let compiled = @lib.compile(prog, verbose=true)
          @fs.write_bytes_to_file(output_file, compiled)
        }
        _ => {
          println("Usage: lang <source_file.txt> <output_file.bin>")
        }
      }
    } catch {
      error => { println(error) }
    }
}
