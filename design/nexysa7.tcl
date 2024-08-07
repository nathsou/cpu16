set cwd [pwd]
set projDir "$cwd/build/vivado"
set projName "cpu16"
set topName cpu16_Top
set device xc7a100tcsg324-1

if {[file exists "$projDir"]} { file delete -force "$projDir" }

create_project $projName "$projDir" -part $device

set_property design_mode RTL [get_filesets sources_1]

set verilogSources [list \
    "$cwd/build/ALU.sv" \
    "$cwd/build/CPU.sv" \
    "$cwd/build/RAM.sv" \
    "$cwd/build/RegisterFile.sv" \
    "$cwd/build/ResetConditioner.sv" \
    "$cwd/build/SevenSegment.sv" \
    "$cwd/build/PPU.sv" \
    "$cwd/build/UART.sv" \
    "$cwd/build/ButtonDebouncer.sv" \
    "$cwd/build/Top.sv" \
]

import_files -fileset [get_filesets sources_1] -force -norecurse -flat $verilogSources
set xdcSources [list "$cwd/nexysa7.xdc"]
read_xdc $xdcSources

# Add hex files to the project
set hexFiles [list \
    "$cwd/src/patternTable.hex" \
    "$cwd/src/progs/text.hex" \
]

import_files -fileset [get_filesets sources_1] -force -norecurse -flat $hexFiles

set_property STEPS.WRITE_BITSTREAM.ARGS.BIN_FILE true [get_runs impl_1]
update_compile_order -fileset sources_1
launch_runs -runs synth_1 -jobs 16
wait_on_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 16
wait_on_run impl_1