
pub struct Env[K, T] {
    parent: Option[Env[K, T]]
    bindings: Map[K, T]
}

pub fn Env::new[K, T]() -> Env[K, T] {
    {
        parent: None,
        bindings: Map::new(),
    }
}

pub fn child[K, T](self: Env[K, T]) -> Env[K, T] {
    {
        parent: Some(self),
        bindings: Map::new(),
    }
}
pub fn declare[K: Eq + Hash, T](self: Env[K, T], name: K, value: T) -> Unit {
    self.bindings[name] = value
}

pub fn lookup[K: Eq + Hash, T](self: Env[K, T], name: K) -> Option[T] {
    match self.bindings[name] {
        Some(value) => Some(value)
        None => {
            match self.parent {
                Some(parent) => parent.lookup(name)
                None => None
            }
        }
    }
}
