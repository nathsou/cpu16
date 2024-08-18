
pub struct FunctionArgument {
  name: String
  ty: Type
}

pub enum Decl {
  Func(~name: String, ~arguments: Array[FunctionArgument], ~returnType: Type, ~body: Array[Stmt])
  Stmt(Stmt)
}

pub fn to_string(self: Decl) -> String {
  match self {
    Decl::Func(~name, ~arguments, ~returnType, ~body) => {
      let args = []

      for arg in arguments {
        args.push(arg.name + ": " + arg.ty.to_string())
      }
      
      let argsStr = args.join(", ")
      let bodyStr = show_stmts(body)
      "fn \{name}(\{argsStr}): \{returnType} \n{" + bodyStr + "\n}"
    }
    Decl::Stmt(stmt) => stmt.to_string()
  }
}
