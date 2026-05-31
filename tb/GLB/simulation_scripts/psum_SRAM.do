vlib work
vlog psum_SRAM.v psum_SRAM_tb.v
vsim -voptargs=+acc work.psum_SRAM_tb
do psum_SRAM_wave.do
run -all
#quit -sim