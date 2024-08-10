
pub struct Env[T] {
    parent: Option[Env[T]]
    bindings: Map[String, T]
}

pub fn Env::new[T]() -> Env[T] {
    {
        parent: None,
        bindings: Map::new()
    }
}

pub fn child[T](self: Env[T]) -> Env[T] {
    {
        parent: Some(self),
        bindings: Map::new()
    }
}
pub fn bind[T](self: Env[T], name: String, value: T) -> Unit {
    self.bindings[name] = value
}

pub fn lookup[T](self: Env[T], name: String) -> Option[T] {
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
