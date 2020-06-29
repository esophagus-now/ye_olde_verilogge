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


# Fix up 'rst' interface
set_property enablement_dependency {spirit:decode(id('MODELPARAM_VALUE.RESET_TYPE')) = 1} [ipx::get_bus_interfaces rst -of_objects [ipx::current_core]]
ipx::add_bus_parameter POLARITY [ipx::get_bus_interfaces rst -of_objects [ipx::current_core]]
set_property VALUE ACTIVE_HIGH [ipx::get_bus_parameters POLARITY -of_objects [ipx::get_bus_interfaces rst -of_objects [ipx::current_core]]]

# Add 'rstn' interface
ipx::add_bus_interface rstn [ipx::current_core]
set_property abstraction_type_vlnv xilinx.com:signal:reset_rtl:1.0 [ipx::get_bus_interfaces rstn -of_objects [ipx::current_core]]
set_property bus_type_vlnv xilinx.com:signal:reset:1.0 [ipx::get_bus_interfaces rstn -of_objects [ipx::current_core]]
set_property enablement_dependency {spirit:decode(id('MODELPARAM_VALUE.RESET_TYPE')) = 2} [ipx::get_bus_interfaces rstn -of_objects [ipx::current_core]]
ipx::add_port_map RST [ipx::get_bus_interfaces rstn -of_objects [ipx::current_core]]
set_property physical_name rst [ipx::get_port_maps RST -of_objects [ipx::get_bus_interfaces rstn -of_objects [ipx::current_core]]]
ipx::add_bus_parameter POLARITY [ipx::get_bus_interfaces rstn -of_objects [ipx::current_core]]
set_property VALUE ACTIVE_LOW [ipx::get_bus_parameters POLARITY -of_objects [ipx::get_bus_interfaces rstn -of_objects [ipx::current_core]]]


ipx::create_xgui_files [ipx::current_core]
ipx::update_checksums [ipx::current_core]
ipx::save_core [ipx::current_core]
close_project 
exit

