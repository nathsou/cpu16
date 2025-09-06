
pub enum InstOrDirective {
  Inst(Inst)
  Directive(Directive)
}

pub impl Show for InstOrDirective with output(self, logger) {
  match self {
    Inst(inst) => inst.output(logger)
    Directive(text) => text.output(logger)
  }
}

pub(all) enum Directive {
  Origin(addr~: UInt16)
}

pub impl Show for Directive with output(self, logger) {
  match self {
    Origin(addr~) => {
      logger.write_string(".org \{addr}")
    }
  }
}
