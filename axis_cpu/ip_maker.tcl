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

# Hide debug ports when not enabled
set_property enablement_dependency {spirit:decode(id('MODELPARAM_VALUE.ENABLE_DEBUG')) != 0} [ipx::get_bus_interfaces from_guv -of_objects [ipx::current_core]]
set_property enablement_dependency {spirit:decode(id('MODELPARAM_VALUE.ENABLE_DEBUG')) != 0} [ipx::get_bus_interfaces to_guv -of_objects [ipx::current_core]]

# Fix 'rst' interface
ipx::add_bus_parameter POLARITY [ipx::get_bus_interfaces rst -of_objects [ipx::current_core]]
set_property VALUE ACTIVE_HIGH [ipx::get_bus_parameters POLARITY -of_objects [ipx::get_bus_interfaces rst -of_objects [ipx::current_core]]]

# CODE_ADDR_WIDTH parameter
set_property display_name {Code Address Width} [ipgui::get_guiparamspec -name "CODE_ADDR_WIDTH" -component [ipx::current_core] ]
set_property tooltip {Number of instructions is two to the power of this number} [ipgui::get_guiparamspec -name "CODE_ADDR_WIDTH" -component [ipx::current_core] ]
set_property widget {textEdit} [ipgui::get_guiparamspec -name "CODE_ADDR_WIDTH" -component [ipx::current_core] ]

# REG_ADDR_WIDTH parameter
ipgui::remove_param -component [ipx::current_core] [ipgui::get_guiparamspec -name "REG_ADDR_WIDTH" -component [ipx::current_core]]

# CPU_ID_WIDTH parameter
ipgui::remove_param -component [ipx::current_core] [ipgui::get_guiparamspec -name "CPU_ID_WIDTH" -component [ipx::current_core]]

# PESS parameter
set_property display_name {Enable pessimistic timing registers} [ipgui::get_guiparamspec -name "PESS" -component [ipx::current_core] ]
set_property tooltip {Adds some register delays in key places to help ease timing} [ipgui::get_guiparamspec -name "PESS" -component [ipx::current_core] ]
set_property widget {checkBox} [ipgui::get_guiparamspec -name "PESS" -component [ipx::current_core] ]
set_property value false [ipx::get_user_parameters PESS -of_objects [ipx::current_core]]
set_property value false [ipx::get_hdl_parameters PESS -of_objects [ipx::current_core]]
set_property value_format bool [ipx::get_user_parameters PESS -of_objects [ipx::current_core]]
set_property value_format bool [ipx::get_hdl_parameters PESS -of_objects [ipx::current_core]]

# ENABLE_DEBUG parameter
set_property tooltip {Allows you plug in a debug governor. Alternatively, simply wire to_guv into from_guv and use an ILA} [ipgui::get_guiparamspec -name "ENABLE_DEBUG" -component [ipx::current_core] ]
set_property widget {checkBox} [ipgui::get_guiparamspec -name "ENABLE_DEBUG" -component [ipx::current_core] ]
set_property value false [ipx::get_user_parameters ENABLE_DEBUG -of_objects [ipx::current_core]]
set_property value false [ipx::get_hdl_parameters ENABLE_DEBUG -of_objects [ipx::current_core]]
set_property value_format bool [ipx::get_user_parameters ENABLE_DEBUG -of_objects [ipx::current_core]]
set_property value_format bool [ipx::get_hdl_parameters ENABLE_DEBUG -of_objects [ipx::current_core]]

ipx::create_xgui_files [ipx::current_core]
ipx::update_checksums [ipx::current_core]
ipx::save_core [ipx::current_core]
close_project 
exit

