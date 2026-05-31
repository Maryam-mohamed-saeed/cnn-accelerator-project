vlib work
vlog -f source_files.txt
vsim -gui work.tb_cluster_group -voptargs=+acc
do wave.do
run -all
