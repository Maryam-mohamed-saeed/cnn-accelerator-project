onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /PE_cluster_tb/clock
add wave -noupdate /PE_cluster_tb/reset
add wave -noupdate /PE_cluster_tb/dut/top_load_PEs_iact_pe
add wave -noupdate /PE_cluster_tb/load_PEs_iact_done_top
add wave -noupdate /PE_cluster_tb/dut/PE00/load_iact
add wave -noupdate /PE_cluster_tb/dut/PE00/iact_done
add wave -noupdate /PE_cluster_tb/dut/PE00/iact_spad_inst/mem
add wave -noupdate /PE_cluster_tb/dut/PE83/load_iact
add wave -noupdate /PE_cluster_tb/dut/PE83/iact_done
add wave -noupdate /PE_cluster_tb/dut/PE83/iact_spad_inst/mem
add wave -noupdate /PE_cluster_tb/dut/PE83/iact_spad_inst/write_ptr
add wave -noupdate /PE_cluster_tb/dut/PE83/current_state
add wave -noupdate /PE_cluster_tb/dut/PE00/current_state
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {1085 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 271
configure wave -valuecolwidth 40
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {950 ns} {1134 ns}
