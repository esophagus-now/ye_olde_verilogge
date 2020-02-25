# This script copied out from Vivado HLS and modified to work in this folder
#
# Call as:
# 
#   vivado_hls -f hls.tcl -tclargs ip_name part_no
#

# WTF why does vivado_hls have different argv indices than Vivado?
# For some ridiculous reason argv is the following list (when you use the 
# prescribed command for vivado_hls given above):
#   [-f, hls.tcl, tg_axilite_intf, xczu19eg-ffvc1760-2-i]
# That is asinine!

set ip_name [lindex $argv 2]
set part_name [lindex $argv 3]

# puts "Here comes argv!!!"
# puts $argv

open_project -reset tg_axilite_intf_tmp_proj
set_top tg_axi_intf
add_files tg_axi_intf.cpp
open_solution "solution1"
set_part "${part_name}" -tool vivado
create_clock -period 3.103 -name default
config_export -format ip_catalog -rtl verilog
#source "./tg_axilite_intf/solution1/directives.tcl"
#csim_design
csynth_design
#cosim_design
export_design -vendor mmerlini.ca -library yov -rtl verilog -format ip_catalog

quit
