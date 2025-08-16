
fn compile(source_file: String, output_file: String?, verbose~: Bool) -> Unit raise {
    let prog = @fs.read_file_to_string(source_file, encoding="utf8")

    let compiled = if source_file.has_suffix(".s") {
      @asm.assemble(prog, verbose~)
    } else {
      @lang.compile(prog, verbose~)
    }

    match output_file {
        Some(file) => {
            @fs.write_bytes_to_file(file, compiled)
        }
        None => ()
    }
}

fn main {
    let verbose = true

    try {
      match @sys.get_cli_args() {
        [_, source_file] => {
          compile(source_file, None, verbose~)
        }
        [_, source_file, output_file] => {
          compile(source_file, Some(output_file), verbose~)
        }
        _ => {
          println("Usage: lang <source_file.txt> <output_file.bin>")
        }
      }
    } catch {
      error => { println(error) }
    }
}
