# CPU 16

Simple load-store 16-bit CPU ISA, along with a Rust simulator and SystemVerilog
design.

## Instruction Set

| Instruction | Description       | Opcode | Flags       | Arguments                                      | Cycles            |
| ----------- | ----------------- | ------ | ----------- | ---------------------------------------------- | ----------------- |
| CTL         | Control flags     | 0b00   | Zero, Carry | <padding: 11> <ctrl_op: 3>                     | 1                 |
| SET         | Set register      | 0b01   | -           | <dst: 3> <value: 11>                           | 1                 |
| MEM         | Load/Store memory | 0b10   | -           | <dst: 3> <addr: 3> <load/store: 1> <offset: 7> | load: 2, store: 2 |
| ALU         | ALU operation     | 0b11   | Zero, Carry | <dst: 3> <src1: 3> <src2: 3> <alu_op: 5>       | 1                 |

### CtrlOps:

- 0b000: Halt
- 0b001: SetZero
- 0b010: ClearZero
- 0b011: SetCarry
- 0b100: ClearCarry

### AluOps:

- 0b000_00: Add
- 0b000_01: Sub
- 0b000_10: Adc (Add with carry)
- 0b000_11: Sbc (Subtract with carry)
- 0b001_00: AddIfZero
- 0b001_01: SubIfZero
- 0b001_10: AdcIfZero
- 0b001_11: SbcIfZero
- 0b010_00: AddIfNotZero
- 0b010_01: SubIfNotZero
- 0b010_10: AdcIfNotZero
- 0b010_11: SbcIfNotZero
- 0b011_00: AddIfCarry
- 0b011_01: SubIfCarry
- 0b011_10: AdcIfCarry
- 0b011_11: SbcIfCarry
- 0b100_00: AddIfNotCarry
- 0b100_01: SubIfNotCarry
- 0b100_10: AdcIfNotCarry
- 0b100_11: SbcIfNotCarry
- 0b101_00: Inc
- 0b101_01: Dec
- 0b101_10: And
- 0b101_11: Nand
- 0b110_00: Or
- 0b110_01: Xor
- 0b110_10: Shl
- 0b110_11: Shr

**To make programming easier, the assembler defines common operations using
these primitive instructions.**

## Generating bin files

Currently, both the Alchitry Cu and Alchitry Au development boards are supported
with the IO Element header.

- Alchitry Cu (iCE40HX8K)

The Alchitry Cu supports a fully open-source toolchain:

1. Download the [OSS CAD Suite](https://github.com/YosysHQ/oss-cad-suite-build)
   and update the path in fpga/Makefile
2. Run `make build` in the fpga directory
3. The bitstream will be in fpga/build/Top.bin
4. Run iceprog to program the FPGA

- Alchitry Au (Xilinx 7)

1. Install [Vivado](https://alchitry.com/tutorials/setup/vivado/)
2. Run build_alchitry_au.bat in the fpga directory
3. The bitstream will be in fpga/build/vivado/cpu16.runs/impl_1/Top.bin
4. Run Alchitry Loader or any other compatible tool to program the FPGA

### Board differences

| Board       | CPU Freq | RAM (16-bit) |
| ----------- | -------- | ------------ |
| Alchitry Cu | 50 MHz   | 8k           |
| Alchitry Au | 100 MHz  | 64k          |
