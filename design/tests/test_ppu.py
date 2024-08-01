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

@cocotb.test()
async def test_ppu(dut):
    """ Test PPU """

    clock = Clock(signal=dut.i_clk_100mhz, period=10, units='us')
    cocotb.start_soon(clock.start())

    await RisingEdge(dut.i_clk_100mhz)
    dut.i_rst.value = 1
    await RisingEdge(dut.i_clk_100mhz)
    dut.i_rst.value = 0
    await RisingEdge(dut.i_clk_100mhz)

    dut.i_name_table_write_enable.value = 1
    dut.i_name_table_write_data.value = 0x4e # N
    dut.i_name_table_write_addr.value = 0
    await RisingEdge(dut.i_clk_100mhz)
    dut.i_name_table_write_enable.value = 0
    await RisingEdge(dut.i_clk_100mhz)

    for _ in range(4 * 10):
        print(f"hsync: {dut.o_hsync.value}, vsync: {dut.o_vsync.value}, tile_x: {dut.tile_x.value}, tile_y: {dut.tile_y.value}, col: {dut.col.value}, row: {dut.row.value}, name_table_index: {dut.name_table_index.value}")
        await RisingEdge(dut.i_clk_100mhz)

def test_ppu_runner():
    sim = os.getenv("SIM", "icarus")

    sources = [
        proj_path / "PPU.sv",
    ]

    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="cpu16_PPU",
        always=True,
        timescale=("1us", "1us"),
        verbose=True,
        build_args=['-pfileline=1']
    )

    runner.test(hdl_toplevel="cpu16_PPU", test_module="test_ppu")


if __name__ == "__main__":
    test_ppu_runner()
