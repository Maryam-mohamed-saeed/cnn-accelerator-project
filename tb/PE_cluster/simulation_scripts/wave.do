onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /PE_cluster_tb/clock
add wave -noupdate /PE_cluster_tb/reset
add wave -noupdate /PE_cluster_tb/load_PEs_weight_done_top
add wave -noupdate /PE_cluster_tb/top_filter_mode
add wave -noupdate /PE_cluster_tb/top_load_PEs_weight_pe
add wave -noupdate /PE_cluster_tb/dut/PE00/weight_done
add wave -noupdate /PE_cluster_tb/dut/PE00/load_weight
add wave -noupdate /PE_cluster_tb/dut/PE83/load_weight
add wave -noupdate /PE_cluster_tb/dut/PE83/weight_done
add wave -noupdate /PE_cluster_tb/load_PEs_iact_done_top
add wave -noupdate /PE_cluster_tb/top_load_PEs_iact_pe
add wave -noupdate /PE_cluster_tb/dut/PE00/load_iact
add wave -noupdate /PE_cluster_tb/dut/PE00/iact_done
add wave -noupdate /PE_cluster_tb/dut/PE83/iact_done
add wave -noupdate /PE_cluster_tb/dut/PE83/load_iact
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {137891 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 302
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
configure wave -timelineunits ps
update
WaveRestoreZoom {0 ps} {336219 ps}
