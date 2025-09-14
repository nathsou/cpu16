
pub struct SortedArray[T] {
    priv values: Array[T]
}

fn[T] SortedArray::new() -> SortedArray[T] {
    { values: [] }
}

fn[T: Eq] SortedArray::remove(self: SortedArray[T], value: T) -> Unit {
  if self.values.search(value) is Some(idx) {
    let _ = self.values.remove(idx)
  }
}

fn[T: Compare] SortedArray::insert(self: SortedArray[T], value: T) -> Unit {
  match self.values.binary_search(value) {
    Ok(insert_idx) | Err(insert_idx) => self.values.insert(insert_idx, value)
  }
}
