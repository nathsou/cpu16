# Adapted from https://projectf.io/posts/verilog-sim-verilator-sdl/

VFLAGS = -O3 -DENABLE_INITIAL_MEM_ --x-assign fast --x-initial fast --noassert
SDL_CFLAGS = `sdl2-config --cflags`
SDL_LDFLAGS = `sdl2-config --libs`

all: VTop

VTopSim.mk: Top.sv
	verilator ${VFLAGS} -I./ Top.sv --top-module TopSim \
		-cc --exe -j 0 wrapper.cpp -o sim \
		-CFLAGS "${SDL_CFLAGS}" -LDFLAGS "${SDL_LDFLAGS}"

VTop: VTopSim.mk
	make -C ./obj_dir -f VTopSim.mk

Top.fir:
	mkdir -p resources
	cp -r ../../design/src/resources/ resources/ 
	cd ../.. && bunx yodl@0.0.6 design/src/Sim.yodl "write_firrtl sim/verilator/Top.fir"

Top.sv: Top.fir
	firtool -O=release --format=fir --verilog Top.fir -o Top.sv

clean:
	rm -rf obj_dir sim Top.sv Top.fir VTopSim.mk
