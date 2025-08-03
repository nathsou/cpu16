#!/bin/bash
fileName="TopNandlandGo"
module="Top"

set -e # Exit on error

mkdir -p output

rm -f output/$module.json output/$module.asc output/$module.bin

cp -r design/src/resources/ output/resources/

bunx yodl@0.0.6 design/src/$fileName.yodl "write_firrtl output/$module.fir"

cd output

firtool --format=fir -O=release --verilog \
    -disable-all-randomization -strip-debug-info \
    --lowering-options=disallowPackedArrays,disallowLocalVariables,emitBindComments \
    $module.fir -o $module.sv

yosys -p "verilog_defines -DENABLE_INITIAL_MEM_=1; read_verilog -sv $module.sv; check -assert; synth_ice40 -top Top -json $module.json"
nextpnr-ice40 --hx1k --json $module.json --pcf ../design/constraints/go.pcf --package vq100 --freq 25 --asc $module.asc
# nextpnr-ice40 --hx8k --json $module.json --pcf ../design/constraints/cu.pcf --package cb132 --freq 50 --asc $module.asc

icepack $module.asc $module.bin
openFPGALoader -b ice40_generic $module.bin
