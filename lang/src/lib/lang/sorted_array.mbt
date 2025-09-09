
pub struct SortedArray[T] {
    priv values: Array[T]
}

fn[T] SortedArray::new() -> SortedArray[T] {
    { values: [] }
}

fn[T: Eq] SortedArray::remove(self: SortedArray[T], value: T) -> Unit {
    match self.values.search_by(x => x == value) {
        Some(idx) => {
            self.values.swap(idx, self.values.length() - 1)
            let _ = self.values.unsafe_pop()
        }
        None => ()
    }
}

fn[T: Compare] SortedArray::insert(self: SortedArray[T], value: T) -> Unit {
    match self.values.search_by(x => x < value) {
        Some(idx) => {
            self.values.insert(idx, value)
        }
        None => {
            self.values.push(value)
        }
    }
}
