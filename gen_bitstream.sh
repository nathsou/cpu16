#!/bin/bash
module="Top"

rm -f output/$module.json output/$module.asc output/$module.bin

firtool --format=fir -O=release --verilog \
    -disable-all-randomization -strip-debug-info \
    --lowering-options=disallowPackedArrays,disallowLocalVariables,emitBindComments \
    output/$module.fir -o output/$module.sv

yosys -p "verilog_defines -DENABLE_INITIAL_MEM_=1; read_verilog -sv output/$module.sv; check -assert; synth_ice40 -top Top -json output/$module.json"
nextpnr-ice40 --hx1k --json output/$module.json --pcf design/go.pcf --package vq100 --freq 25 --asc output/$module.asc

icepack output/$module.asc output/$module.bin
openFPGALoader -b ice40_generic output/$module.bin