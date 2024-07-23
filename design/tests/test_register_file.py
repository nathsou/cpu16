import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
import random

@cocotb.test()
async def test_register_file(dut):
    """ Test RegisterFile """

    clock = Clock(signal=dut.i_clk, period=10, units="ns")
    cocotb.start_soon(clock.start())

    dut.i_rst.value = 1
    await RisingEdge(dut.i_clk)

    dut.i_count_enable.value = 0
    dut.i_write_enable.value = 0
    dut.i_write_dest.value = 0
    dut.i_write_data.value = 0
    dut.i_read_src1.value = 0
    dut.i_read_src2.value = 0
    dut.i_rst.value = 0

    for i in range(0, 8):
        dut.i_write_enable.value = 1
        dut.i_write_dest.value = i
        rand_val = random.randint(0, 65535)
        dut.i_write_data.value = rand_val
        await RisingEdge(dut.i_clk)
        dut.i_write_enable.value = 0
        dut.i_read_src1.value = i
        await RisingEdge(dut.i_clk)

        expected_val = rand_val if i != 0 else 0

        assert dut.o_read_data1.value == expected_val, f"Read data1 mismatch for address {i}"

    # test the program counter
    dut.i_write_enable.value = 1
    dut.i_write_dest.value = 7
    dut.i_write_data.value = 0
    await RisingEdge(dut.i_clk)
    dut.i_write_enable.value = 0
    dut.i_count_enable.value = 1
    await RisingEdge(dut.i_clk)
    dut.i_count_enable.value = 0
    await RisingEdge(dut.i_clk)
    assert dut.o_program_counter.value == 1, "Program counter mismatch"


    dut._log.info("Test complete")
