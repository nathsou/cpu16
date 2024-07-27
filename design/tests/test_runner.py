import os
from pathlib import Path

from cocotb.runner import get_runner

simulator = os.getenv('SIM', 'icarus')
build_dir = Path(__file__).resolve().parent.parent / 'build'

def test_register_file_runner():
    sources = [build_dir / 'RegisterFile.sv']
    top = 'cpu16_RegisterFile'

    runner = get_runner(simulator)
    runner.build(
        sources=sources,
        hdl_toplevel=top,
    )

    runner.test(hdl_toplevel=top, test_module='test_register_file')

# def test_alu_runner():
#     sources = [build_dir / 'ALU.sv']
#     top = 'cpu16_ALU'

#     runner = get_runner(simulator)
#     runner.build(
#         sources=sources,
#         hdl_toplevel=top,
#     )

#     runner.test(hdl_toplevel=top, test_module='test_alu')


if __name__ == '__main__':
    test_register_file_runner()
    # test_alu_runner()
