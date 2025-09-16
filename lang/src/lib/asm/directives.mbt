
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
  Byte(Byte)
  Word(UInt16)
}

pub impl Show for Directive with output(self, logger) {
  match self {
    Origin(addr~) => {
      logger.write_string(".org \{addr}")
    }
    Byte(value) => {
      logger.write_string(".byte \{value.to_uint16()}")
    }
    Word(value) => {
      logger.write_string(".word \{value}")
    }
  }
}
