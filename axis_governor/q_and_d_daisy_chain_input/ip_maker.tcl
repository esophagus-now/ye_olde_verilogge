# Call as:
# vivado -mode tcl -nolog -nojournal -source scripts/ip_package.tcl -tclargs $out_dir $ip_name $part_name

# start_gui

set out_dir [lindex $argv 0]
set ip_name [lindex $argv 1]
set part_name [lindex $argv 2]
set project_name ${ip_name}_tmp_proj
create_project ${project_name} ${project_name} -part ${part_name}
add_files ${out_dir}/src
ipx::package_project -root_dir ${out_dir} -vendor mmerlini -library yov -taxonomy /UserIP

# Fix associated clock on cmd bus
set_property VALUE {s_axi:cmd} [ipx::get_bus_parameters ASSOCIATED_BUSIF -of_objects [ipx::get_bus_interfaces axi_aclk -of_objects [ipx::current_core ]]]


ipx::create_xgui_files [ipx::current_core]
ipx::update_checksums [ipx::current_core]
ipx::save_core [ipx::current_core]
close_project 
exit
