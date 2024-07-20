#!/bin/bash

# Script to build the project for the Alchitry Au board from WSL with Vivado for Windows installed

# use the temp windows folder
tmp_dir=$(wslpath $(wslvar TEMP))/cpu16_build
cwd=$(pwd)

rm -rf $tmp_dir
cp -rf . $tmp_dir
cd $tmp_dir
powershell.exe -Command ".\build_alchitry_au.bat"

# copy the bin file back to the linux folder
cd $cwd
mkdir -p build/alchitry_au
cp -f $tmp_dir/build/vivado/cpu16.runs/impl_1/*.bin build/alchitry_au/
