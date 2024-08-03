import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
import os
from pathlib import Path
from cocotb.runner import get_runner
import json

VERBOSE = False

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


PC_START_ADDR = 0x8000

@cocotb.test()
async def test_top(dut):
    """ Test Top """

    clock = Clock(signal=dut.clk, period=10, units='us')
    cocotb.start_soon(clock.start())

    trace = parse_cpu_state(Path(__file__).resolve().parent / 'traces' / 'div.jsonl')

    dut.btn_r.value = 0
    
    signals = {
        "PC": dut.cpu.o_program_counter,
        "stage": dut.cpu.r_stage,
        "instruction": dut.cpu.r_instruction,
        "reg_write_enable": dut.cpu.register_file.i_write_enable,
        "reg_write_dest": dut.cpu.register_file.i_write_dest,
        "reg_write_data": dut.cpu.register_file.i_write_data,
        "reg_read_src1": dut.cpu.register_file.i_read_src1,
        "reg_read_src2": dut.cpu.register_file.i_read_src2,
        "reg_read_data1": dut.cpu.register_file.o_read_data1,
        "reg_read_data2": dut.cpu.register_file.o_read_data2,
        "alu_out": dut.cpu.alu.o_out,
        "alu_condition_met": dut.cpu.w_alu_condition_met,
        "halt_flag": dut.halt_flag,
        "zero_flag": dut.zero_flag,
        "carry_flag": dut.carry_flag,
        "mem_address": dut.cpu.w_mem_address,
        "mem_write_data": dut.cpu.r_mem_write_data,
        "mem_write_enable": dut.cpu.w_mem_write_enable,
        "ram_address": dut.ram.i_address,
        "ram_write_enable": dut.ram.i_write_enable,
        "ram_write_data": dut.ram.i_write_data,
        "ram_read_data": dut.ram.o_read_data,
        "count_enable": dut.cpu.w_count_enable,
        "rst": dut.rst,
    }

    def print_state():
        for name, signal in signals.items():
            print(f"{name}: {signal.value} ({hex(signal.value)})")
        
        for i in range(8):
            val = dut.cpu.register_file.r_regs[i].value
            print(f"r{i}: {val} ({hex(val)})")

        print("-------------")
    
    trace_index = 0
    max_iters = 10 ** 6
    last_pc = 0
    i = 0

    while True:
        is_ready = dut.rst.value == 0 and dut.cpu.register_file.r_regs[0].value == 0 and dut.program_counter.value != PC_START_ADDR
        if is_ready:
            break
        else:
            await RisingEdge(dut.clk)

    while i < max_iters and dut.halt_flag.value != 1:
        pc = str(dut.program_counter.value)

        if pc == last_pc and signals['stage'].value != 0:
            await RisingEdge(dut.clk)
            # print_state()
            continue
            
        i += 1
        last_pc = pc

        if signals['stage'].value == 0:
            regs = [int(dut.cpu.register_file.r_regs[i].value) for i in range(8)]

            expected = trace[trace_index]
            
            if VERBOSE:
                print_state()
                print('expected', {k: hex(v) if isinstance(v, int) else v for k, v in expected.items()})

            trace_index += 1

            assert regs[0] == 0
            assert regs[7] == expected['pc'] 
            assert regs[1] == expected['r1']
            assert regs[2] == expected['r2']
            assert regs[3] == expected['r3']
            assert regs[4] == expected['r4']
            assert regs[5] == expected['tmp']
            assert regs[6] == expected['sp']
            assert signals['zero_flag'].value == expected['zero']
            assert signals['carry_flag'].value == expected['carry']
            assert signals['halt_flag'].value == expected['halt']

            await RisingEdge(dut.clk)
        

    if VERBOSE:
        print_state()

def test_top_runner():
    sim = os.getenv("SIM", "icarus")

    sources = [
        proj_path / "Top.sv",
        proj_path / "PPU.sv",
        proj_path / "CPU.sv",
        proj_path / "ALU.sv",
        proj_path / "RAM.sv",
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
