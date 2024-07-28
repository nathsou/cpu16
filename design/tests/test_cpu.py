import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
import os
from pathlib import Path
from cocotb.runner import get_runner
from cocotb.types import LogicArray

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

@cocotb.test()
async def test_cpu(dut):
    """ Test CPU """

    prog_rom = parse_prog(root_path / 'src' / 'prog.hex')
    ram = [0] * (1 << 16)
    name_table = [0] * ((640 >> 3) * (480 >> 3))
    name_table_index = 0
    clock = Clock(signal=dut.i_clk, period=10, units='us')
    cocotb.start_soon(clock.start())

    dut.i_rst.value = 1
    await RisingEdge(dut.i_clk)
    dut.i_rst.value = 0
    await RisingEdge(dut.i_clk)

    while dut.r_halt_flag.value != 1:
        pc = int(dut.o_program_counter.value)
        print(f"pc: {pc}")
        inst = prog_rom[pc] if pc < len(prog_rom) else 0
        dut.i_rom_data.value = inst
        print(f"inst: {bin(inst)}")

        if dut.o_ram_write_enable.value == 1:
            addr = int(dut.o_ram_write_address.value)
            val = int(dut.o_ram_write_data.value)
            print(f"store ram[{addr}] = {val}")

            if addr == 0xffff:
                if val & 0x8000 != 0:
                    name_table_index = val & 0x1fff
                else:
                    name_table[name_table_index] = val
            else:
                ram[addr] = val

        ram_read_addr = dut.o_ram_read_address.value

        if is_binary(ram_read_addr):
            print(f"load {ram[int(ram_read_addr)]}")
            dut.i_ram_read_data.value = ram[int(ram_read_addr)]
        
        await RisingEdge(dut.i_clk)

    print(''.join([chr(c) for c in name_table[:32]]))


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
        build_args=['-pfileline=1']
    )

    runner.test(hdl_toplevel="cpu16_CPU", test_module="test_cpu")


if __name__ == "__main__":
    test_cpu_runner()
