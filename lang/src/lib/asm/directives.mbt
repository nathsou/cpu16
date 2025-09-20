
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
  U8(Array[Byte])
  U16(Array[UInt16])
  Ascii(String)
}

pub impl Show for Directive with output(self, logger) {
  match self {
    Origin(addr~) => {
      logger.write_string(".org \{addr}")
    }
    U8(values) => {
      logger.write_string(".u8")

      for v in values {
        logger.write_string(" \{v.to_uint16()}")
      }
    }
    U16(values) => {
      logger.write_string(".u16")

      for v in values {
        logger.write_string(" \{v}")
      }
    }
    Ascii(text) => {
      logger.write_string(".ascii \"\{text}\"")
    }
  }
}
