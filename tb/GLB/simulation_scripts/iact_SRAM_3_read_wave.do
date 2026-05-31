onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -color {Cornflower Blue} /iact_SRAM_3_read_tb/clock
add wave -noupdate -color {Cornflower Blue} /iact_SRAM_3_read_tb/reset
add wave -noupdate /iact_SRAM_3_read_tb/data_in
add wave -noupdate /iact_SRAM_3_read_tb/data_in_ready
add wave -noupdate /iact_SRAM_3_read_tb/data_in_valid
add wave -noupdate -color pink /iact_SRAM_3_read_tb/data_out_0
add wave -noupdate -color pink /iact_SRAM_3_read_tb/data_out_1
add wave -noupdate -color pink /iact_SRAM_3_read_tb/data_out_2
add wave -noupdate /iact_SRAM_3_read_tb/data_out_ready_0
add wave -noupdate /iact_SRAM_3_read_tb/data_out_ready_1
add wave -noupdate /iact_SRAM_3_read_tb/data_out_ready_2
add wave -noupdate /iact_SRAM_3_read_tb/data_out_valid_0
add wave -noupdate /iact_SRAM_3_read_tb/data_out_valid_1
add wave -noupdate /iact_SRAM_3_read_tb/data_out_valid_2
add wave -noupdate -color pink /iact_SRAM_3_read_tb/expected_mem
add wave -noupdate -color pink /iact_SRAM_3_read_tb/read_addr_0
add wave -noupdate -color pink /iact_SRAM_3_read_tb/read_addr_1
add wave -noupdate -color pink /iact_SRAM_3_read_tb/read_addr_2
add wave -noupdate /iact_SRAM_3_read_tb/read_done_0
add wave -noupdate /iact_SRAM_3_read_tb/read_done_1
add wave -noupdate /iact_SRAM_3_read_tb/read_done_2
add wave -noupdate -color {Slate Blue} /iact_SRAM_3_read_tb/read_en_0
add wave -noupdate -color {Slate Blue} /iact_SRAM_3_read_tb/read_en_1
add wave -noupdate -color {Slate Blue} /iact_SRAM_3_read_tb/read_en_2
add wave -noupdate -color pink /iact_SRAM_3_read_tb/write_addr
add wave -noupdate /iact_SRAM_3_read_tb/write_done
add wave -noupdate -color {Slate Blue} /iact_SRAM_3_read_tb/write_en
add wave -noupdate /iact_SRAM_3_read_tb/test_case_count
add wave -noupdate -color pink /iact_SRAM_3_read_tb/dut/mem
add wave -noupdate -color {Slate Blue} /iact_SRAM_3_read_tb/dut/read_address_0
add wave -noupdate -color {Slate Blue} /iact_SRAM_3_read_tb/dut/read_address_1
add wave -noupdate -color {Slate Blue} /iact_SRAM_3_read_tb/dut/read_address_2
add wave -noupdate -color {Slate Blue} /iact_SRAM_3_read_tb/dut/write_address
add wave -noupdate /iact_SRAM_3_read_tb/read_and_verify/valid_sig
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {2665000 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 167
configure wave -valuecolwidth 40
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
configure wave -timelineunits ps
update
WaveRestoreZoom {10213422 ps} {10441399 ps}
