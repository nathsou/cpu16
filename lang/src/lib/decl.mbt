
pub struct FunctionArgument {
  name: String
  ty: Type
}

pub enum Decl {
  Func(~name: String, ~parameters: Array[FunctionArgument], ~return_type: Type, ~body: Array[Stmt])
  Stmt(Stmt)
}

pub fn to_string(self: Decl) -> String {
  match self {
    Decl::Func(~name, ~parameters, ~return_type, ~body) => {
      let args = []

      for param in parameters {
        args.push(param.name + ": " + param.ty.to_string())
      }
      
      let argsStr = args.join(", ")
      let bodyStr = show_stmts(body)
      "fn \{name}(\{argsStr}): \{return_type} \n{" + bodyStr + "\n}"
    }
    Decl::Stmt(stmt) => stmt.to_string()
  }
}
