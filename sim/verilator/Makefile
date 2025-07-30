# Adapted from https://projectf.io/posts/verilog-sim-verilator-sdl/

VFLAGS = -O3 -DENABLE_INITIAL_MEM_ --x-assign fast --x-initial fast --noassert

all: VTop

VTop.mk: Top.sv
	verilator ${VFLAGS} -I./ Top.sv --top-module Top -cc --exe -j 0 wrapper.cpp -o sim

VTop: VTop.mk
	make -C ./obj_dir -f VTop.mk

Top.fir:
	cd ../.. && npx yodl@0.0.6 design/src/TopNandlandGo.yodl "write_firrtl sim/verilator/Top.fir"

Top.sv: Top.fir
	firtool -O=release --format=fir --verilog Top.fir -o Top.sv

clean:
	rm -rf obj_dir sim Top.sv Top.fir VTop.mk
