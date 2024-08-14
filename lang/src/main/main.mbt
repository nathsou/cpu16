
extern "js" fn write_file(file_path: String, contents: FixedArray[UInt]) -> Unit =
  #|(file_path, contents) => {
  #|  Bun.write(file_path, new Uint16Array(contents));
  #|}

fn main {
    let prog =
      #|if 3 + 7 == 10 {
      #|  if 2 + 1 == 4 { 1621 } else { 1998 }
      #|} else {
      #|  4 + 5 + (if 1 + 2 == 3 { 1 } else { 8 })
      #|}

    try {
      let compiled = @lib.compile!(prog, ~verbose=true)
      write_file("out.bin", compiled)
    } catch {
      _ => { println("Error") }
    }
}
