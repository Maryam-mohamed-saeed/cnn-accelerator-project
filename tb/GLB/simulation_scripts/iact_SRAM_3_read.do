vlib work
vlog iact_SRAM_3_read.v tb/iact_SRAM_3_read_tb.v
vsim -voptargs=+acc work.iact_SRAM_3_read_tb
do do_files/iact_SRAM_3_read_wave.do
run -all
#quit -sim