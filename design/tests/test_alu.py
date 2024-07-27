import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from typing import List
import os
from pathlib import Path
from cocotb.runner import get_runner
from dataclasses import dataclass
from enum import IntEnum

class Op(IntEnum):
    ADD = 0
    SUB = 1
    ADC = 2
    SBC = 3
    ADD_IF_ZERO = 4
    SUB_IF_ZERO = 5
    ADC_IF_ZERO = 6
    SBC_IF_ZERO = 7
    ADD_IF_NOT_ZERO = 8
    SUB_IF_NOT_ZERO = 9
    ADC_IF_NOT_ZERO = 10
    SBC_IF_NOT_ZERO = 11
    ADD_IF_CARRY = 12
    SUB_IF_CARRY = 13
    ADC_IF_CARRY = 14
    SBC_IF_CARRY = 15
    ADD_IF_NOT_CARRY = 16
    SUB_IF_NOT_CARRY = 17
    ADC_IF_NOT_CARRY = 18
    SBC_IF_NOT_CARRY = 19
    AND = 20
    NAND = 21
    OR = 22
    XOR = 23
    SHL = 24
    SHR = 25
    INC = 26
    DEC = 27
    
@dataclass
class ALUInput:
    op: int
    a: int
    b: int
    out: Op

ALU_INPUTS = [
    ALUInput(op=Op.ADD, a=5, b=3, out=8),
    ALUInput(op=Op.SUB, a=5, b=3, out=0b10000000000000010),
    ALUInput(op=Op.AND, a=5, b=3, out=1),
    ALUInput(op=Op.OR, a=5, b=3, out=7),
    ALUInput(op=Op.XOR, a=5, b=3, out=6),
    ALUInput(op=Op.SHL, a=5, b=3, out=40),
    ALUInput(op=Op.SHR, a=5, b=3, out=0),
    ALUInput(op=Op.INC, a=5, b=0, out=6),
    ALUInput(op=Op.DEC, a=5, b=0, out=0b10000000000000100),
]

@cocotb.test()
async def test_alu(dut):
    """ Test ALU """

    clock = Clock(signal=dut.i_clk, period=10, units="us")
    cocotb.start_soon(clock.start())

    dut.i_rst.value = 1
    await RisingEdge(dut.i_clk)

    for input in ALU_INPUTS:
        dut.i_enable.value = 1
        dut.i_rst.value = 0
        dut.i_op.value = input.op.value
        dut.i_a.value = input.a
        dut.i_b.value = input.b
        await RisingEdge(dut.i_clk)

        assert dut.o_out.value == input.out, f"ALU output is {dut.o_out.value}, expected {input.out} for op {input.op.name}"


def test_alu_runner():
    sim = os.getenv("SIM", "icarus")

    proj_path = Path(__file__).resolve().parent.parent / 'build'
    sources = [proj_path / "ALU.sv"]

    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="cpu16_ALU",
        always=True,
        timescale=("1us", "1us"),
    )

    runner.test(hdl_toplevel="cpu16_ALU", test_module="test_alu")


if __name__ == "__main__":
    test_alu_runner()
