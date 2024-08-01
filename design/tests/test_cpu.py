import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
import os
from pathlib import Path
from cocotb.runner import get_runner
from cocotb.types import LogicArray
from typing import List

def replace_text_in_files(directory, old_text, new_text):
    for root, _, files in os.walk(directory):
        for file in files:
            if file.endswith(".sv"):
                file_path = os.path.join(root, file)
                with open(file_path, 'r', encoding='utf-8') as f:
                    content = f.read()
                
                # Replace the old text with the new text
                new_content = content.replace(old_text, new_text)
                
                with open(file_path, 'w', encoding='utf-8') as f:
                    f.write(new_content)

root_path = Path(__file__).resolve().parent.parent
proj_path = root_path / 'build'
replace_text_in_files(str(proj_path.absolute()), ") inside", ")")

def is_binary(logic_array: LogicArray) -> bool:
    """Check if a LogicArray contains only binary data."""
    return all(bit in '01' for bit in str(logic_array))

def parse_prog(file: str):
    with open(file, 'r') as f:
        lines = f.readlines()
        return [int(line, 16) for line in lines]

class CPU:
    def __init__(self, dut, prog_rom: List[int]):
        self.dut = dut
        self.prog_rom = prog_rom
        self.ram = [0] * (1 << 16)
        self.clock = Clock(signal=dut.i_clk, period=10, units='us')
        cocotb.start_soon(self.clock.start())
        self.name_table = [0] * ((640 >> 3) * (480 >> 3))
        self.name_table_index = 0

    async def reset_conditioner(self):
        self.dut.i_rst.value = 1
        await RisingEdge(self.dut.i_clk)
        self.dut.i_rst.value = 0
        await RisingEdge(self.dut.i_clk)

    def is_halted(self) -> bool:
        return self.dut.r_halt_flag.value == 1
    
    def get_reg(self, reg_idx: int) -> LogicArray:
        return self.dut.register_file.r_regs[reg_idx].value

    async def step(self):
        pc = int(self.dut.o_program_counter.value)
        inst = self.prog_rom[pc] if pc < len(self.prog_rom) else 0
        self.dut.i_rom_data.value = inst

        if self.dut.o_ram_write_enable.value == 1:
            addr = int(self.dut.o_ram_write_address.value)
            val = int(self.dut.o_ram_write_data.value)

            if addr == 0xffff:
                if val & 0x8000 != 0:
                    self.name_table_index = val & 0x1fff
                else:
                    self.name_table[self.name_table_index] = val
            else:
                self.ram[addr] = val

        ram_read_addr = self.dut.o_ram_read_address.value

        if is_binary(ram_read_addr):
            self.dut.i_ram_read_data.value = self.ram[int(ram_read_addr)]
        
        await RisingEdge(self.dut.i_clk)

# @cocotb.test()
# async def test_add(dut):
#     prog_rom = [0x4823, 0x5017, 0xc940, 0x0000]

#     cpu = CPU(dut, prog_rom)

#     await cpu.reset_conditioner()

#     while not cpu.is_halted():
#         await cpu.step()

#     assert cpu.get_reg(1) == 0x3a


@cocotb.test()
async def test_nametable(dut):
    """ Test NameTable """

    # a program that writes "Hello, FPGA!" to the name table
    prog_rom: List[int] = [
        0x71ff, 0x50ff, 0x6808, 0xd2ba, 0x68ff, 0xd2b8, 0x5880, 0x6808, 0xdbba, 0xdb18, 0x9a00,
        0x4848, 0x8a00, 0xdb14, 0x9a00, 0x4865, 0x8a00, 0xdb14, 0x9a00, 0x486c, 0x8a00, 0xdb14,
        0x9a00, 0x486c, 0x8a00, 0xdb14, 0x9a00, 0x486f, 0x8a00, 0xdb14, 0x9a00, 0x482c, 0x8a00,
        0xdb14, 0x9a00, 0x4820, 0x8a00, 0xdb14, 0x9a00, 0x4846, 0x8a00, 0xdb14, 0x9a00, 0x4850,
        0x8a00, 0xdb14, 0x9a00, 0x4847, 0x8a00, 0xdb14, 0x9a00, 0x4841, 0x8a00, 0xdb14, 0x9a00,
        0x4821, 0x8a00, 0xdb14, 0x0000,
    ]

    cpu = CPU(dut, prog_rom)

    await cpu.reset_conditioner()

    while not cpu.is_halted():
        await cpu.step()

    message = ''.join([chr(c) for c in cpu.name_table[:12]])

    assert message == "Hello, FPGA!"
    assert all(cpu.name_table[i] == 0 for i in range(12, len(cpu.name_table)))


def test_cpu_runner():
    sim = os.getenv("SIM", "icarus")

    sources = [
        proj_path / "CPU.sv",
        proj_path / "ALU.sv",
        proj_path / "RegisterFile.sv",
    ]

    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="cpu16_CPU",
        always=True,
        timescale=("1us", "1us"),
        verbose=True,
    )

    runner.test(hdl_toplevel="cpu16_CPU", test_module="test_cpu")


if __name__ == "__main__":
    test_cpu_runner()
