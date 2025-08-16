
pub struct Env[K, T] {
    parent: Option[Env[K, T]]
    bindings: Map[K, T]
}

pub fn[K, T] Env::new() -> Env[K, T] {
    {
        parent: None,
        bindings: Map::new(),
    }
}

pub fn[K, T] Env::child(self: Env[K, T]) -> Env[K, T] {
    {
        parent: Some(self),
        bindings: Map::new(),
    }
}
pub fn[K: Eq + Hash, T] declare(self: Env[K, T], name: K, value: T) -> Unit {
    self.bindings[name] = value
}

pub fn[K: Eq + Hash, T] lookup(self: Env[K, T], name: K) -> Option[T] {
    match self.bindings.get(name) {
        Some(value) => Some(value)
        None => {
            match self.parent {
                Some(parent) => parent.lookup(name)
                None => None
            }
        }
    }
}
