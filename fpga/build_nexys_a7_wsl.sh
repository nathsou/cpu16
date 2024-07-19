#!/bin/bash

# Script to build the project for the Nexys A7 board from WSL with Vivado for Windows installed

# use the temp windows folder
tmp_dir=$(wslpath $(wslvar TEMP))/cpu16_build
cwd=$(pwd)

rm -rf $tmp_dir
cp -rf . $tmp_dir
cd $tmp_dir
powershell.exe -Command ".\build_nexys_a7.bat"

# copy the bin file back to the linux folder
mkdir -p build/nexys_a7
cd $cwd
cp -f $tmp_dir/build/vivado/cpu16.runs/impl_1/*.bin build/nexys_a7/
