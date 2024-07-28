import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
import os
from pathlib import Path
from cocotb.runner import get_runner
import json

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

# parse JSONL of: {"r1":18,"r2":0,"r3":0,"r4":0,"tmp":0,"sp":0,"pc":1,"zero":false,"carry":false,"halt":false}
def parse_cpu_state(file: str):
    with open(file, 'r') as f:
        lines = f.readlines()
        return [json.loads(line) for line in lines]
    

@cocotb.test()
async def test_top(dut):
    """ Test Top """

    clock = Clock(signal=dut.clk, period=10, units='us')
    cocotb.start_soon(clock.start())

    trace = parse_cpu_state(Path(__file__).resolve().parent / 'traces' / 'add.jsonl')

    dut.btn_r.value = 0

    def print_state():
        pc = dut.program_counter.value
        a = dut.cpu.alu.i_a.value
        b = dut.cpu.alu.i_b.value
        alu_op = dut.cpu.alu.i_op.value
        flags = dut.cpu.alu.i_flags.value
        carry_in = dut.cpu.alu.carry_in.value
        print(f"PC: {pc}, rst: {dut.rst} inst: {dut.rom.o_data.value}, a: {a}, b: {b}, alu_en: {dut.cpu.alu.i_enable.value}, alu_out: {dut.cpu.alu_out.value}, alu_op: {alu_op}, flags: {flags}, carry_in: {carry_in}")
        reg_file = dut.cpu.register_file
        regs = {i: int(reg_file.r_regs[i].value) for i in range(8)}
        print("regs:", regs)
        print(f"src1: {reg_file.i_read_src1.value}, src2: {reg_file.i_read_src2.value}, dst: {reg_file.i_write_dest.value}, d1: {reg_file.o_read_data1.value}, d2: {reg_file.o_read_data2.value}, wr: {reg_file.i_write_enable.value}, wr_data: {reg_file.i_write_data}")
        print("")


    trace_index = 0

    while dut.halt_flag.value != 1:
        is_ready = dut.cpu.register_file.r_regs[0].value == 0 and dut.program_counter.value != 0

        if is_ready:
            is_reading_mem = dut.cpu.is_reading_memory.value
            
            regs = [int(dut.cpu.register_file.r_regs[i].value) for i in range(8)]
            print_state()
            regs = [int(dut.cpu.register_file.r_regs[i].value) for i in range(8)]
            print([hex(n) for n in regs])
            print(f"inst: {dut.rom_data.value}")
            zero_flag = dut.zero_flag.value
            carry_flag = dut.carry_flag.value
            halt_flag = dut.halt_flag.value

                
            print(f"is_reading_mem: {is_reading_mem}")

            expected = trace[trace_index]
            print('expected', expected)

            assert regs[0] == 0
            assert regs[7] == expected['pc']
            assert regs[1] == expected['r1']
            assert regs[2] == expected['r2']
            assert regs[3] == expected['r3']
            assert regs[4] == expected['r4']
            assert regs[5] == expected['tmp']
            assert regs[6] == expected['sp']
            assert zero_flag == expected['zero']
            assert carry_flag == expected['carry']
            assert halt_flag == expected['halt']

            if is_reading_mem == 0:
                trace_index += 1

        # print_state()
        await RisingEdge(dut.clk)

    # print_state()
    assert dut.halt_flag.value == 1


def test_top_runner():
    sim = os.getenv("SIM", "icarus")

    sources = [
        proj_path / "Top.sv",
        proj_path / "CPU.sv",
        proj_path / "ALU.sv",
        proj_path / "RAM.sv",
        proj_path / "ROM.sv",
        proj_path / "RegisterFile.sv",
        proj_path / "ResetConditioner.sv",
        proj_path / "SevenSegment.sv",
    ]

    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="cpu16_Top",
        always=True,
        timescale=("1us", "1us"),
        verbose=True,
        build_args=['-pfileline=1']
    )

    runner.test(hdl_toplevel="cpu16_Top", test_module="test_top")


if __name__ == "__main__":
    test_top_runner()
