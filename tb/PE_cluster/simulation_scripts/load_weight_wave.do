onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /PE_cluster_tb/clock
add wave -noupdate /PE_cluster_tb/reset
add wave -noupdate /PE_cluster_tb/top_load_PEs_weight_pe
add wave -noupdate /PE_cluster_tb/load_PEs_weight_done_top
add wave -noupdate /PE_cluster_tb/dut/PE00/load_weight
add wave -noupdate /PE_cluster_tb/dut/PE00/weight_done
add wave -noupdate /PE_cluster_tb/dut/PE00/weight_spad_inst/mem
add wave -noupdate /PE_cluster_tb/dut/PE83/load_weight
add wave -noupdate /PE_cluster_tb/dut/PE83/weight_done
add wave -noupdate /PE_cluster_tb/dut/PE83/weight_spad_inst/mem
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ns} 0}
quietly wave cursor active 0
configure wave -namecolwidth 281
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
WaveRestoreZoom {0 ns} {181 ns}
