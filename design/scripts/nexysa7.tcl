set cwd [pwd]
set projDir "$cwd/build/vivado"
set projName "top"
set topName Top
set device xc7a100tcsg324-1

if {[file exists "$projDir"]} { file delete -force "$projDir" }

create_project $projName "$projDir" -part $device

set_property design_mode RTL [get_filesets sources_1]

set verilogSources [list \
    "$cwd/Top.sv" \
]

# Enable memory initialization
set_property verilog_define [list ENABLE_INITIAL_MEM_] [get_filesets sources_1]

import_files -fileset [get_filesets sources_1] -force -norecurse -flat $verilogSources
set xdcSources [list "$cwd/nexysa7.xdc"]
read_xdc $xdcSources

set_property STEPS.WRITE_BITSTREAM.ARGS.BIN_FILE true [get_runs impl_1]
update_compile_order -fileset sources_1
launch_runs -runs synth_1 -jobs 16
wait_on_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 16
wait_on_run impl_1
