onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -color Cyan /psum_SRAM_tb/clock
add wave -noupdate -color Cyan /psum_SRAM_tb/reset
add wave -noupdate -color pink /psum_SRAM_tb/psum_data_in
add wave -noupdate /psum_SRAM_tb/psum_data_in_ready
add wave -noupdate /psum_SRAM_tb/psum_data_in_valid
add wave -noupdate -color pink /psum_SRAM_tb/psum_data_out
add wave -noupdate /psum_SRAM_tb/psum_data_out_ready
add wave -noupdate /psum_SRAM_tb/psum_data_out_valid
add wave -noupdate /psum_SRAM_tb/PSUM_DEPTH
add wave -noupdate -color pink /psum_SRAM_tb/psum_read_addr
add wave -noupdate -color {Slate Blue} /psum_SRAM_tb/dut/read_session_start
add wave -noupdate -color {Orange Red} /psum_SRAM_tb/dut/read_shake
add wave -noupdate /psum_SRAM_tb/psum_read_done
add wave -noupdate -color {Slate Blue} /psum_SRAM_tb/psum_read_en
add wave -noupdate -color pink /psum_SRAM_tb/psum_write_addr
add wave -noupdate /psum_SRAM_tb/psum_write_done
add wave -noupdate -color {Slate Blue} /psum_SRAM_tb/psum_write_en
add wave -noupdate -color pink /psum_SRAM_tb/expected_mem
add wave -noupdate /psum_SRAM_tb/test_case_count
add wave -noupdate -color pink /psum_SRAM_tb/dut/mem
add wave -noupdate -color {Slate Blue} /psum_SRAM_tb/dut/psum_read_address
add wave -noupdate -color {Slate Blue} /psum_SRAM_tb/dut/psum_write_address
add wave -noupdate /psum_SRAM_tb/dut/write_count
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {117 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 179
configure wave -valuecolwidth 56
configure wave -justifyvalue left
configure wave -signalnamewidth 1
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
WaveRestoreZoom {110 ns} {341 ns}
