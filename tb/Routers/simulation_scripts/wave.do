onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /Router_Cluster_TOP_tb/weight_out_sel
add wave -noupdate /Router_Cluster_TOP_tb/weight_in_sel
add wave -noupdate /Router_Cluster_TOP_tb/weight0_glb_vld
add wave -noupdate /Router_Cluster_TOP_tb/weight0_glb_data
add wave -noupdate /Router_Cluster_TOP_tb/weight0_glb_addr
add wave -noupdate /Router_Cluster_TOP_tb/psum_out_sel
add wave -noupdate /Router_Cluster_TOP_tb/psum_in_sel
add wave -noupdate -label psum0_pe_out_vld /Router_Cluster_TOP_tb/psum0_pe_out_vld
add wave -noupdate -label psum0_pe_out /Router_Cluster_TOP_tb/psum0_pe_out
add wave -noupdate /Router_Cluster_TOP_tb/psum0_glb_vld
add wave -noupdate /Router_Cluster_TOP_tb/psum0_glb_in
add wave -noupdate /Router_Cluster_TOP_tb/iact_PE_sel
add wave -noupdate /Router_Cluster_TOP_tb/iact_PE_choice
add wave -noupdate /Router_Cluster_TOP_tb/iact_multicast
add wave -noupdate /Router_Cluster_TOP_tb/iact_data_out_sel
add wave -noupdate /Router_Cluster_TOP_tb/iact_data_in_sel
add wave -noupdate /Router_Cluster_TOP_tb/iact0_glb_vld
add wave -noupdate /Router_Cluster_TOP_tb/iact0_glb_rdy
add wave -noupdate /Router_Cluster_TOP_tb/iact0_glb_data
add wave -noupdate /Router_Cluster_TOP_tb/iact0_glb_addr
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {98887 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 331
configure wave -valuecolwidth 100
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
WaveRestoreZoom {98714 ps} {99486 ps}
