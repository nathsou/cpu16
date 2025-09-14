
// for some reason abort(msg) doesn't print the message
pub fn[T] panic_msg(msg: String) -> T {
    println("PANIC: \{msg}")
    panic()
}

pub fn[T] impossible() -> T {
    panic_msg("unreachable")
}
