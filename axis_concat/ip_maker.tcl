# Call as:
# vivado -mode tcl -nolog -nojournal -source scripts/ip_package.tcl -tclargs $out_dir $ip_name $part_name

set out_dir [lindex $argv 0]
set ip_name [lindex $argv 1]
set part_name [lindex $argv 2]
set project_name ${ip_name}_tmp_proj
create_project ${project_name} ${project_name} -part ${part_name}
add_files ${out_dir}/src
ipx::package_project -root_dir ${out_dir} -vendor mmerlini -library yov -taxonomy /UserIP

# Set conditional portds in AXI Streams. I hope this plays nicely with the rest
# of Vivado!
set_property enablement_dependency {spirit:decode(id('MODELPARAM_VALUE.IN_ENABLE_ID')) = 1} [ipx::get_ports left_TID -of_objects [ipx::current_core]]
set_property enablement_dependency {spirit:decode(id('MODELPARAM_VALUE.IN_ENABLE_DEST')) = 1} [ipx::get_ports left_TDEST -of_objects [ipx::current_core]]
set_property enablement_dependency {spirit:decode(id('MODELPARAM_VALUE.IN_ENABLE_KEEP')) = 1} [ipx::get_ports left_TKEEP -of_objects [ipx::current_core]]
set_property enablement_dependency {spirit:decode(id('MODELPARAM_VALUE.IN_ENABLE_LAST')) = 1} [ipx::get_ports left_TLAST -of_objects [ipx::current_core]]
set_property enablement_dependency {spirit:decode(id('MODELPARAM_VALUE.IN_ENABLE_USER')) = 1} [ipx::get_ports left_TUSER -of_objects [ipx::current_core]]
set_property driver_value 0 [ipx::get_ports right_TID -of_objects [ipx::current_core]]
set_property enablement_dependency {spirit:decode(id('MODELPARAM_VALUE.OUT_ENABLE_ID')) = 1} [ipx::get_ports right_TID -of_objects [ipx::current_core]]
set_property driver_value 0 [ipx::get_ports right_TDEST -of_objects [ipx::current_core]]
set_property enablement_dependency {spirit:decode(id('MODELPARAM_VALUE.OUT_ENABLE_DEST')) = 1} [ipx::get_ports right_TDEST -of_objects [ipx::current_core]]
set_property driver_value 0 [ipx::get_ports right_TKEEP -of_objects [ipx::current_core]]
set_property enablement_dependency {spirit:decode(id('MODELPARAM_VALUE.OUT_ENABLE_KEEP')) = 1} [ipx::get_ports right_TKEEP -of_objects [ipx::current_core]]
set_property driver_value 0 [ipx::get_ports right_TLAST -of_objects [ipx::current_core]]
set_property enablement_dependency {spirit:decode(id('MODELPARAM_VALUE.OUT_ENABLE_LAST')) = 1} [ipx::get_ports right_TLAST -of_objects [ipx::current_core]]
set_property driver_value 0 [ipx::get_ports right_TUSER -of_objects [ipx::current_core]]
set_property enablement_dependency {spirit:decode(id('MODELPARAM_VALUE.OUT_ENABLE_USER')) = 1} [ipx::get_ports right_TUSER -of_objects [ipx::current_core]]

# IN_ENABLE_LAST
set_property display_name {Enable TLAST} [ipgui::get_guiparamspec -name "IN_ENABLE_LAST" -component [ipx::current_core] ]
set_property tooltip {Enable TLAST input} [ipgui::get_guiparamspec -name "IN_ENABLE_LAST" -component [ipx::current_core] ]
set_property widget {checkBox} [ipgui::get_guiparamspec -name "IN_ENABLE_LAST" -component [ipx::current_core] ]
set_property value false [ipx::get_user_parameters IN_ENABLE_LAST -of_objects [ipx::current_core]]
set_property value false [ipx::get_hdl_parameters IN_ENABLE_LAST -of_objects [ipx::current_core]]
set_property value_format bool [ipx::get_user_parameters IN_ENABLE_LAST -of_objects [ipx::current_core]]
set_property value_format bool [ipx::get_hdl_parameters IN_ENABLE_LAST -of_objects [ipx::current_core]]

# IN_ENABLE_KEEP
set_property display_name {Enable TKEEP} [ipgui::get_guiparamspec -name "IN_ENABLE_KEEP" -component [ipx::current_core] ]
set_property tooltip {Enable TKEEP input} [ipgui::get_guiparamspec -name "IN_ENABLE_KEEP" -component [ipx::current_core] ]
set_property widget {checkBox} [ipgui::get_guiparamspec -name "IN_ENABLE_KEEP" -component [ipx::current_core] ]
set_property value false [ipx::get_user_parameters IN_ENABLE_KEEP -of_objects [ipx::current_core]]
set_property value false [ipx::get_hdl_parameters IN_ENABLE_KEEP -of_objects [ipx::current_core]]
set_property value_format bool [ipx::get_user_parameters IN_ENABLE_KEEP -of_objects [ipx::current_core]]
set_property value_format bool [ipx::get_hdl_parameters IN_ENABLE_KEEP -of_objects [ipx::current_core]]

# IN_ENABLE_DEST
set_property display_name {Enable TDEST} [ipgui::get_guiparamspec -name "IN_ENABLE_DEST" -component [ipx::current_core] ]
set_property tooltip {Enable TDEST input} [ipgui::get_guiparamspec -name "IN_ENABLE_DEST" -component [ipx::current_core] ]
set_property widget {checkBox} [ipgui::get_guiparamspec -name "IN_ENABLE_DEST" -component [ipx::current_core] ]
set_property value false [ipx::get_user_parameters IN_ENABLE_DEST -of_objects [ipx::current_core]]
set_property value false [ipx::get_hdl_parameters IN_ENABLE_DEST -of_objects [ipx::current_core]]
set_property value_format bool [ipx::get_user_parameters IN_ENABLE_DEST -of_objects [ipx::current_core]]
set_property value_format bool [ipx::get_hdl_parameters IN_ENABLE_DEST -of_objects [ipx::current_core]]

# IN_ENABLE_ID
set_property display_name {Enable TID} [ipgui::get_guiparamspec -name "IN_ENABLE_ID" -component [ipx::current_core] ]
set_property tooltip {Enable TID input} [ipgui::get_guiparamspec -name "IN_ENABLE_ID" -component [ipx::current_core] ]
set_property widget {checkBox} [ipgui::get_guiparamspec -name "IN_ENABLE_ID" -component [ipx::current_core] ]
set_property value false [ipx::get_user_parameters IN_ENABLE_ID -of_objects [ipx::current_core]]
set_property value false [ipx::get_hdl_parameters IN_ENABLE_ID -of_objects [ipx::current_core]]
set_property value_format bool [ipx::get_user_parameters IN_ENABLE_ID -of_objects [ipx::current_core]]
set_property value_format bool [ipx::get_hdl_parameters IN_ENABLE_ID -of_objects [ipx::current_core]]

# IN_ENABLE_USER
set_property display_name {Enable TUSER} [ipgui::get_guiparamspec -name "IN_ENABLE_USER" -component [ipx::current_core] ]
set_property tooltip {Enable TUSER input} [ipgui::get_guiparamspec -name "IN_ENABLE_USER" -component [ipx::current_core] ]
set_property widget {checkBox} [ipgui::get_guiparamspec -name "IN_ENABLE_USER" -component [ipx::current_core] ]
set_property value false [ipx::get_user_parameters IN_ENABLE_USER -of_objects [ipx::current_core]]
set_property value false [ipx::get_hdl_parameters IN_ENABLE_USER -of_objects [ipx::current_core]]
set_property value_format bool [ipx::get_user_parameters IN_ENABLE_USER -of_objects [ipx::current_core]]
set_property value_format bool [ipx::get_hdl_parameters IN_ENABLE_USER -of_objects [ipx::current_core]]

# OUT_ENABLE_LAST
set_property display_name {Keep TLAST as separate side channel} [ipgui::get_guiparamspec -name "OUT_ENABLE_LAST" -component [ipx::current_core] ]
set_property tooltip {} [ipgui::get_guiparamspec -name "OUT_ENABLE_LAST" -component [ipx::current_core] ]
set_property widget {checkBox} [ipgui::get_guiparamspec -name "OUT_ENABLE_LAST" -component [ipx::current_core] ]
set_property value false [ipx::get_user_parameters OUT_ENABLE_LAST -of_objects [ipx::current_core]]
set_property value false [ipx::get_hdl_parameters OUT_ENABLE_LAST -of_objects [ipx::current_core]]
set_property enablement_tcl_expr {$IN_ENABLE_LAST != 0} [ipx::get_user_parameters OUT_ENABLE_LAST -of_objects [ipx::current_core]]
set_property value_format bool [ipx::get_user_parameters OUT_ENABLE_LAST -of_objects [ipx::current_core]]
set_property value_format bool [ipx::get_hdl_parameters OUT_ENABLE_LAST -of_objects [ipx::current_core]]

# OUT_ENABLE_KEEP
set_property display_name {Keep TKEEP as separate side channel} [ipgui::get_guiparamspec -name "OUT_ENABLE_KEEP" -component [ipx::current_core] ]
set_property tooltip {} [ipgui::get_guiparamspec -name "OUT_ENABLE_KEEP" -component [ipx::current_core] ]
set_property widget {checkBox} [ipgui::get_guiparamspec -name "OUT_ENABLE_KEEP" -component [ipx::current_core] ]
set_property value false [ipx::get_user_parameters OUT_ENABLE_KEEP -of_objects [ipx::current_core]]
set_property value false [ipx::get_hdl_parameters OUT_ENABLE_KEEP -of_objects [ipx::current_core]]
set_property enablement_tcl_expr {$IN_ENABLE_KEEP != 0} [ipx::get_user_parameters OUT_ENABLE_KEEP -of_objects [ipx::current_core]]
set_property value_format bool [ipx::get_user_parameters OUT_ENABLE_KEEP -of_objects [ipx::current_core]]
set_property value_format bool [ipx::get_hdl_parameters OUT_ENABLE_KEEP -of_objects [ipx::current_core]]

# OUT_ENABLE_DEST
set_property display_name {Keep TDEST as separate side channel} [ipgui::get_guiparamspec -name "OUT_ENABLE_DEST" -component [ipx::current_core] ]
set_property tooltip {} [ipgui::get_guiparamspec -name "OUT_ENABLE_DEST" -component [ipx::current_core] ]
set_property widget {checkBox} [ipgui::get_guiparamspec -name "OUT_ENABLE_DEST" -component [ipx::current_core] ]
set_property value false [ipx::get_user_parameters OUT_ENABLE_DEST -of_objects [ipx::current_core]]
set_property value false [ipx::get_hdl_parameters OUT_ENABLE_DEST -of_objects [ipx::current_core]]
set_property enablement_tcl_expr {$IN_ENABLE_DEST != 0} [ipx::get_user_parameters OUT_ENABLE_DEST -of_objects [ipx::current_core]]
set_property value_format bool [ipx::get_user_parameters OUT_ENABLE_DEST -of_objects [ipx::current_core]]
set_property value_format bool [ipx::get_hdl_parameters OUT_ENABLE_DEST -of_objects [ipx::current_core]]

# OUT_ENABLE_ID
set_property display_name {Keep TID as separate side channel} [ipgui::get_guiparamspec -name "OUT_ENABLE_ID" -component [ipx::current_core] ]
set_property tooltip {} [ipgui::get_guiparamspec -name "OUT_ENABLE_ID" -component [ipx::current_core] ]
set_property widget {checkBox} [ipgui::get_guiparamspec -name "OUT_ENABLE_ID" -component [ipx::current_core] ]
set_property value false [ipx::get_user_parameters OUT_ENABLE_ID -of_objects [ipx::current_core]]
set_property value false [ipx::get_hdl_parameters OUT_ENABLE_ID -of_objects [ipx::current_core]]
set_property enablement_tcl_expr {$IN_ENABLE_ID != 0} [ipx::get_user_parameters OUT_ENABLE_ID -of_objects [ipx::current_core]]
set_property value_format bool [ipx::get_user_parameters OUT_ENABLE_ID -of_objects [ipx::current_core]]
set_property value_format bool [ipx::get_hdl_parameters OUT_ENABLE_ID -of_objects [ipx::current_core]]

# OUT_ENABLE_USER
set_property display_name {Keep TUSER as separate side channel} [ipgui::get_guiparamspec -name "OUT_ENABLE_USER" -component [ipx::current_core] ]
set_property tooltip {} [ipgui::get_guiparamspec -name "OUT_ENABLE_USER" -component [ipx::current_core] ]
set_property widget {checkBox} [ipgui::get_guiparamspec -name "OUT_ENABLE_USER" -component [ipx::current_core] ]
set_property value false [ipx::get_user_parameters OUT_ENABLE_USER -of_objects [ipx::current_core]]
set_property value false [ipx::get_hdl_parameters OUT_ENABLE_USER -of_objects [ipx::current_core]]
set_property enablement_tcl_expr {$IN_ENABLE_USER != 0} [ipx::get_user_parameters OUT_ENABLE_USER -of_objects [ipx::current_core]]
set_property value_format bool [ipx::get_user_parameters OUT_ENABLE_USER -of_objects [ipx::current_core]]
set_property value_format bool [ipx::get_hdl_parameters OUT_ENABLE_USER -of_objects [ipx::current_core]]

# DEST_WIDTH
set_property widget {textEdit} [ipgui::get_guiparamspec -name "DEST_WIDTH" -component [ipx::current_core] ]
set_property enablement_tcl_expr {$IN_ENABLE_DEST != 0} [ipx::get_user_parameters DEST_WIDTH -of_objects [ipx::current_core]]

# ID_WIDTH
set_property widget {textEdit} [ipgui::get_guiparamspec -name "ID_WIDTH" -component [ipx::current_core] ]
set_property enablement_tcl_expr {$IN_ENABLE_ID != 0} [ipx::get_user_parameters ID_WIDTH -of_objects [ipx::current_core]]

# USER_WIDTH
set_property widget {textEdit} [ipgui::get_guiparamspec -name "USER_WIDTH" -component [ipx::current_core] ]
set_property enablement_tcl_expr {$IN_ENABLE_USER != 0} [ipx::get_user_parameters USER_WIDTH -of_objects [ipx::current_core]]

# Fix up order in GUI window. I made a lot of mistakes (along with corrections)
# so this TCL is not the most efficient. But it should work.
ipgui::move_param -component [ipx::current_core] -order 0 [ipgui::get_guiparamspec -name "IN_ENABLE_LAST" -component [ipx::current_core]] -parent [ipgui::get_pagespec -name "Page 0" -component [ipx::current_core]]
ipgui::move_param -component [ipx::current_core] -order 1 [ipgui::get_guiparamspec -name "OUT_ENABLE_LAST" -component [ipx::current_core]] -parent [ipgui::get_pagespec -name "Page 0" -component [ipx::current_core]]
ipgui::add_group -name {TLAST} -component [ipx::current_core] -parent [ipgui::get_pagespec -name "Page 0" -component [ipx::current_core] ] -display_name {TLAST}
ipgui::move_group -component [ipx::current_core] -order 0 [ipgui::get_groupspec -name "TLAST" -component [ipx::current_core]] -parent [ipgui::get_pagespec -name "Page 0" -component [ipx::current_core]]
ipgui::move_param -component [ipx::current_core] -order 0 [ipgui::get_guiparamspec -name "IN_ENABLE_LAST" -component [ipx::current_core]] -parent [ipgui::get_groupspec -name "TLAST" -component [ipx::current_core]]
ipgui::move_param -component [ipx::current_core] -order 0 [ipgui::get_guiparamspec -name "OUT_ENABLE_LAST" -component [ipx::current_core]] -parent [ipgui::get_groupspec -name "TLAST" -component [ipx::current_core]]
ipgui::move_param -component [ipx::current_core] -order 1 [ipgui::get_guiparamspec -name "OUT_ENABLE_LAST" -component [ipx::current_core]] -parent [ipgui::get_groupspec -name "TLAST" -component [ipx::current_core]]
ipgui::add_group -name {TKEEP} -component [ipx::current_core] -parent [ipgui::get_pagespec -name "Page 0" -component [ipx::current_core] ] -display_name {TKEEP}
ipgui::move_group -component [ipx::current_core] -order 1 [ipgui::get_groupspec -name "TKEEP" -component [ipx::current_core]] -parent [ipgui::get_groupspec -name "TLAST" -component [ipx::current_core]]
ipgui::move_group -component [ipx::current_core] -order 1 [ipgui::get_groupspec -name "TKEEP" -component [ipx::current_core]] -parent [ipgui::get_pagespec -name "Page 0" -component [ipx::current_core]]
ipgui::move_param -component [ipx::current_core] -order 0 [ipgui::get_guiparamspec -name "IN_ENABLE_KEEP" -component [ipx::current_core]] -parent [ipgui::get_groupspec -name "TKEEP" -component [ipx::current_core]]
ipgui::move_param -component [ipx::current_core] -order 0 [ipgui::get_guiparamspec -name "OUT_ENABLE_KEEP" -component [ipx::current_core]] -parent [ipgui::get_groupspec -name "TKEEP" -component [ipx::current_core]]
ipgui::move_param -component [ipx::current_core] -order 2 [ipgui::get_guiparamspec -name "OUT_ENABLE_KEEP" -component [ipx::current_core]] -parent [ipgui::get_pagespec -name "Page 0" -component [ipx::current_core]]
ipgui::move_param -component [ipx::current_core] -order 0 [ipgui::get_guiparamspec -name "OUT_ENABLE_KEEP" -component [ipx::current_core]] -parent [ipgui::get_groupspec -name "TKEEP" -component [ipx::current_core]]
ipgui::move_param -component [ipx::current_core] -order 0 [ipgui::get_guiparamspec -name "IN_ENABLE_KEEP" -component [ipx::current_core]] -parent [ipgui::get_groupspec -name "TKEEP" -component [ipx::current_core]]
ipgui::add_group -name {TDEST} -component [ipx::current_core] -parent [ipgui::get_pagespec -name "Page 0" -component [ipx::current_core] ] -display_name {TDEST}
ipgui::move_group -component [ipx::current_core] -order 2 [ipgui::get_groupspec -name "TDEST" -component [ipx::current_core]] -parent [ipgui::get_pagespec -name "Page 0" -component [ipx::current_core]]
ipgui::move_param -component [ipx::current_core] -order 0 [ipgui::get_guiparamspec -name "OUT_ENABLE_DEST" -component [ipx::current_core]] -parent [ipgui::get_groupspec -name "TDEST" -component [ipx::current_core]]
ipgui::move_param -component [ipx::current_core] -order 0 [ipgui::get_guiparamspec -name "IN_ENABLE_DEST" -component [ipx::current_core]] -parent [ipgui::get_groupspec -name "TDEST" -component [ipx::current_core]]
ipgui::move_param -component [ipx::current_core] -order 1 [ipgui::get_guiparamspec -name "DEST_WIDTH" -component [ipx::current_core]] -parent [ipgui::get_groupspec -name "TDEST" -component [ipx::current_core]]
ipgui::add_group -name {TID} -component [ipx::current_core] -parent [ipgui::get_pagespec -name "Page 0" -component [ipx::current_core] ] -display_name {TID}
ipgui::move_group -component [ipx::current_core] -order 3 [ipgui::get_groupspec -name "TID" -component [ipx::current_core]] -parent [ipgui::get_pagespec -name "Page 0" -component [ipx::current_core]]
ipgui::move_param -component [ipx::current_core] -order 0 [ipgui::get_guiparamspec -name "OUT_ENABLE_ID" -component [ipx::current_core]] -parent [ipgui::get_groupspec -name "TID" -component [ipx::current_core]]
ipgui::move_param -component [ipx::current_core] -order 0 [ipgui::get_guiparamspec -name "IN_ENABLE_ID" -component [ipx::current_core]] -parent [ipgui::get_groupspec -name "TID" -component [ipx::current_core]]
ipgui::move_param -component [ipx::current_core] -order 0 [ipgui::get_guiparamspec -name "ID_WIDTH" -component [ipx::current_core]] -parent [ipgui::get_groupspec -name "TID" -component [ipx::current_core]]
ipgui::move_param -component [ipx::current_core] -order 0 [ipgui::get_guiparamspec -name "IN_ENABLE_ID" -component [ipx::current_core]] -parent [ipgui::get_groupspec -name "TID" -component [ipx::current_core]]
ipgui::move_param -component [ipx::current_core] -order 0 [ipgui::get_guiparamspec -name "DATA_WIDTH" -component [ipx::current_core]] -parent [ipgui::get_pagespec -name "Page 0" -component [ipx::current_core]]
ipgui::add_group -name {TUSER} -component [ipx::current_core] -parent [ipgui::get_pagespec -name "Page 0" -component [ipx::current_core] ] -display_name {TUSER}
ipgui::move_group -component [ipx::current_core] -order 2 [ipgui::get_groupspec -name "TUSER" -component [ipx::current_core]] -parent [ipgui::get_groupspec -name "TID" -component [ipx::current_core]]
ipgui::move_group -component [ipx::current_core] -order 3 [ipgui::get_groupspec -name "TUSER" -component [ipx::current_core]] -parent [ipgui::get_groupspec -name "TID" -component [ipx::current_core]]
ipgui::move_group -component [ipx::current_core] -order 5 [ipgui::get_groupspec -name "TUSER" -component [ipx::current_core]] -parent [ipgui::get_pagespec -name "Page 0" -component [ipx::current_core]]
ipgui::move_param -component [ipx::current_core] -order 0 [ipgui::get_guiparamspec -name "OUT_ENABLE_USER" -component [ipx::current_core]] -parent [ipgui::get_groupspec -name "TUSER" -component [ipx::current_core]]
ipgui::move_param -component [ipx::current_core] -order 0 [ipgui::get_guiparamspec -name "IN_ENABLE_USER" -component [ipx::current_core]] -parent [ipgui::get_groupspec -name "TUSER" -component [ipx::current_core]]
ipgui::move_param -component [ipx::current_core] -order 0 [ipgui::get_guiparamspec -name "USER_WIDTH" -component [ipx::current_core]] -parent [ipgui::get_groupspec -name "TUSER" -component [ipx::current_core]]
ipgui::move_param -component [ipx::current_core] -order 0 [ipgui::get_guiparamspec -name "IN_ENABLE_USER" -component [ipx::current_core]] -parent [ipgui::get_groupspec -name "TUSER" -component [ipx::current_core]]

ipx::create_xgui_files [ipx::current_core]
ipx::update_checksums [ipx::current_core]
ipx::save_core [ipx::current_core]
close_project 
exit
