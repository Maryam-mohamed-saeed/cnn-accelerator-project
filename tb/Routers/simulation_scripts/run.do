vlib work
vlog -f source_files.txt
vsim -gui work.Router_Cluster_TOP_tb -voptargs=+acc
do wave.do
run -all
