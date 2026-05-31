vlib work
vlog -f source_files.txt
vsim -gui work.PE_cluster_tb -voptargs=+acc
do stream_wave.do
run -all


