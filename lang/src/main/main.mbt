
enum Command {
    Compile(source_file~: String, output_file~: String?)
    Asm(source_file~: String, output_file~: String?)
    Run(source_file~: String)
}

fn run_command(command: Command, verbose~: Bool) -> Unit raise {
    match command {
        Asm(source_file~, output_file~) => {
            let prog = @fs.read_file_to_string(source_file, encoding="utf8")
            let compiled = @asm.assemble(prog, verbose~)

            match output_file {
                Some(file) => {
                    @fs.write_bytes_to_file(file, compiled)
                }
                None => ()
            }
        }
        Compile(source_file~, output_file~) => {
            let prog = @fs.read_file_to_string(source_file, encoding="utf8")
            let compiled = @lang.compile(prog, verbose~)

            match output_file {
                Some(file) => {
                    @fs.write_bytes_to_file(file, compiled)
                }
                None => ()
            }
        }
        Run(source_file~) => {
            let prog = @fs.read_file_to_bytes(source_file)
            let cpu = @sim.CPU::from(prog, 0x0000)

            while !cpu.halted {
                if verbose {
                    println(cpu)
                }

                cpu.step()
            }

            if !verbose {
                println(cpu)
            }
        }
    }
}

fn parse_command(args: Array[String]) -> Command? {
    match args {
        [_, "compile", source_file] => Some(Command::Compile(source_file~, output_file=None))
        [_, "compile", source_file, output_file] => Some(Command::Compile(source_file~, output_file=Some(output_file)))
        [_, "asm", source_file] => Some(Command::Asm(source_file~, output_file=None))
        [_, "asm", source_file, output_file] => Some(Command::Asm(source_file~, output_file=Some(output_file)))
        [_, "run", source_file] => Some(Command::Run(source_file~))
        _ => None
    }
}

fn main {
    try {
        match parse_command(@sys.get_cli_args()) {
            Some(cmd) => run_command(cmd, verbose=true)
            None => {
                println("Usage: lang <command> <source_file> [output_file]")
                println("Commands:")
                println("  compile - Compile a source file")
                println("  asm - Assemble a source file")
                println("  run - Run a compiled program")
            }
        }
    } catch {
        error => { println(error) }
    }
}
