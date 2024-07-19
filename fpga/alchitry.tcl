set cwd [pwd]
set projDir "$cwd/build/vivado"
set projName "cpu16"
set topName Top
set device xc7a35tftg256-1

if {[file exists "$projDir"]} { file delete -force "$projDir" }

create_project $projName "$projDir" -part $device

set_property design_mode RTL [get_filesets sources_1]
set_property verilog_define "ALCHITRY_AU=1" [get_filesets sources_1]

set verilogSources [list \
    "$cwd/src/Top.sv" \
    "$cwd/src/CPU.sv" \
    "$cwd/src/ALU.sv" \
    "$cwd/src/ButtonDebouncer.sv" \
    "$cwd/src/RAM.sv" \
    "$cwd/src/ROM.sv" \
    "$cwd/src/RegisterFile.sv" \
    "$cwd/src/ResetConditioner.sv" \
    "$cwd/src/SevenSegment.sv" \
    "$cwd/src/SevenSegment4.sv" \
]

import_files -fileset [get_filesets sources_1] -force -norecurse $verilogSources
set xdcSources [list "$cwd/alchitry.xdc"]
read_xdc $xdcSources
set_property STEPS.WRITE_BITSTREAM.ARGS.BIN_FILE true [get_runs impl_1]
update_compile_order -fileset sources_1
launch_runs -runs synth_1 -jobs 16
wait_on_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 16
wait_on_run impl_1