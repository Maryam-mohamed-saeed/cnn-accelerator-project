onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /PE_cluster_tb/dut/clock
add wave -noupdate /PE_cluster_tb/dut/reset
add wave -noupdate /PE_cluster_tb/PE_mode
add wave -noupdate /PE_cluster_tb/top_psum_stream_start_pe
add wave -noupdate /PE_cluster_tb/psum_stream_done_top
add wave -noupdate /PE_cluster_tb/dut/PE00/current_state
add wave -noupdate /PE_cluster_tb/dut/PE00_psum_stream_done
add wave -noupdate /PE_cluster_tb/dut/PE00/psum_spad_inst/spad_mem
add wave -noupdate /PE_cluster_tb/dut/PE11/current_state
add wave -noupdate /PE_cluster_tb/dut/PE11_psum_stream_done
add wave -noupdate /PE_cluster_tb/dut/PE11/psum_spad_inst/spad_mem
add wave -noupdate /PE_cluster_tb/dut/PE22/current_state
add wave -noupdate /PE_cluster_tb/dut/PE22_psum_stream_done
add wave -noupdate /PE_cluster_tb/dut/PE22/psum_spad_inst/spad_mem
add wave -noupdate /PE_cluster_tb/dut/PE33/current_state
add wave -noupdate /PE_cluster_tb/dut/PE33_psum_stream_done
add wave -noupdate /PE_cluster_tb/dut/PE33/psum_spad_inst/spad_mem
add wave -noupdate /PE_cluster_tb/dut/PE40/current_state
add wave -noupdate /PE_cluster_tb/dut/PE40_psum_stream_done
add wave -noupdate /PE_cluster_tb/dut/PE40/psum_spad_inst/spad_mem
add wave -noupdate /PE_cluster_tb/dut/PE51/current_state
add wave -noupdate /PE_cluster_tb/dut/PE51_psum_stream_done
add wave -noupdate /PE_cluster_tb/dut/PE51/psum_spad_inst/spad_mem
add wave -noupdate /PE_cluster_tb/dut/PE62/current_state
add wave -noupdate /PE_cluster_tb/dut/PE62_psum_stream_done
add wave -noupdate /PE_cluster_tb/dut/PE62/psum_spad_inst/spad_mem
add wave -noupdate /PE_cluster_tb/dut/PE73/current_state
add wave -noupdate /PE_cluster_tb/dut/PE73_psum_stream_done
add wave -noupdate /PE_cluster_tb/dut/PE73/psum_spad_inst/spad_mem
add wave -noupdate /PE_cluster_tb/dut/PE80/current_state
add wave -noupdate /PE_cluster_tb/dut/PE80_psum_stream_done
add wave -noupdate /PE_cluster_tb/dut/PE80/psum_spad_inst/spad_mem
add wave -noupdate /PE_cluster_tb/dut/PE83_psum_stream_done
add wave -noupdate /PE_cluster_tb/dut/PE83/current_state
add wave -noupdate /PE_cluster_tb/dut/PE83/psum_spad_inst/spad_mem
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {5818 ns} 0}
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
WaveRestoreZoom {5707 ns} {5863 ns}
