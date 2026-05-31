onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /PE_cluster_tb/dut/clock
add wave -noupdate /PE_cluster_tb/dut/reset
add wave -noupdate /PE_cluster_tb/dut/top_mac_en_pe
add wave -noupdate /PE_cluster_tb/psum_spad_write_index
add wave -noupdate /PE_cluster_tb/weight_spad_index
add wave -noupdate /PE_cluster_tb/dut/mac_done_top
add wave -noupdate /PE_cluster_tb/dut/PE00_mac_done
add wave -noupdate /PE_cluster_tb/dut/PE11_mac_done
add wave -noupdate /PE_cluster_tb/dut/PE22_mac_done
add wave -noupdate /PE_cluster_tb/dut/PE33_mac_done
add wave -noupdate /PE_cluster_tb/dut/PE40_mac_done
add wave -noupdate /PE_cluster_tb/dut/PE51_mac_done
add wave -noupdate /PE_cluster_tb/dut/PE62_mac_done
add wave -noupdate /PE_cluster_tb/dut/PE73_mac_done
add wave -noupdate /PE_cluster_tb/dut/PE83_mac_done
add wave -noupdate /PE_cluster_tb/dut/PE00/iact_spad_inst/mem
add wave -noupdate /PE_cluster_tb/dut/PE00/weight_spad_inst/mem
add wave -noupdate /PE_cluster_tb/dut/PE00/psum_spad_inst/spad_mem
add wave -noupdate /PE_cluster_tb/dut/PE83/iact_spad_inst/mem
add wave -noupdate /PE_cluster_tb/dut/PE83/weight_spad_inst/mem
add wave -noupdate /PE_cluster_tb/dut/PE83/psum_spad_inst/spad_mem
add wave -noupdate /PE_cluster_tb/dut/PE01/psum_spad_inst/spad_mem
add wave -noupdate /PE_cluster_tb/dut/PE41/psum_spad_inst/spad_mem
add wave -noupdate /PE_cluster_tb/dut/PE80/psum_spad_inst/spad_mem
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {5395 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 297
configure wave -valuecolwidth 86
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
WaveRestoreZoom {5297 ns} {5453 ns}
