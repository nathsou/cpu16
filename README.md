# CPU 16

Simple load-store 16-bit CPU ISA, along with a Rust simulator and SystemVerilog
design.

<img src="res/cpu16.png" alt="CPU16 Running on an Alchitry Au" width="400">

## Instruction Set

| Instruction | Description       | Opcode | Flags       | Arguments                                      | Cycles            |
| ----------- | ----------------- | ------ | ----------- | ---------------------------------------------- | ----------------- |
| CTL         | Control flags     | 0b00   | Zero, Carry | <padding: 11> <ctrl_op: 3>                     | 1                 |
| SET         | Set register      | 0b01   | -           | <dst: 3> <value: 11>                           | 1                 |
| MEM         | Load/Store memory | 0b10   | -           | <dst: 3> <addr: 3> <load/store: 1> <offset: 7> | load: 2, store: 1 |
| ALU         | ALU operation     | 0b11   | Zero, Carry | <dst: 3> <src1: 3> <src2: 3> <alu_op: 5>       | 1                 |

### Registers

| Register | Description                                    | Index |
| -------- | ---------------------------------------------- | ----- |
| Z        | Zero register (always 0, cannot be written to) | 0     |
| R1       | General purpose register                       | 1     |
| R2       | General purpose register                       | 2     |
| R3       | General purpose register                       | 3     |
| R4       | General purpose register                       | 4     |
| TMP      | Temporary value register                       | 5     |
| SP       | Stack pointer                                  | 6     |
| PC       | Program counter                                | 7     |

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

### Nexys A7 (Xilinx Artix 7 XC7A100T)

1. Install [Vivado](https://alchitry.com/tutorials/setup/vivado/)
2. Run `make build-vivado` in the fpga directory
3. The bitstream will be in fpga/build/cpu16_Top.bin
4. Run openFPGALoader or any other compatible tool to program the FPGA
