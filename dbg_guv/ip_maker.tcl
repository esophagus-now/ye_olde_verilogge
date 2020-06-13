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

# Fix up 'DUT_rst' interface
set_property enablement_dependency {spirit:decode(id('MODELPARAM_VALUE.DUT_RST_VAL')) = 1} [ipx::get_bus_interfaces DUT_rst -of_objects [ipx::current_core]]
ipx::add_bus_parameter POLARITY [ipx::get_bus_interfaces DUT_rst -of_objects [ipx::current_core]]
set_property VALUE ACTIVE_HIGH [ipx::get_bus_parameters POLARITY -of_objects [ipx::get_bus_interfaces DUT_rst -of_objects [ipx::current_core]]]

# Add 'DUT_rstn' interface
ipx::add_bus_interface DUT_resetn [ipx::current_core]
set_property abstraction_type_vlnv xilinx.com:signal:reset_rtl:1.0 [ipx::get_bus_interfaces DUT_resetn -of_objects [ipx::current_core]]
set_property bus_type_vlnv xilinx.com:signal:reset:1.0 [ipx::get_bus_interfaces DUT_resetn -of_objects [ipx::current_core]]
set_property interface_mode master [ipx::get_bus_interfaces DUT_resetn -of_objects [ipx::current_core]]
set_property enablement_dependency {spirit:decode(id('MODELPARAM_VALUE.DUT_RST_VAL')) = 0} [ipx::get_bus_interfaces DUT_resetn -of_objects [ipx::current_core]]
ipx::add_port_map RST [ipx::get_bus_interfaces DUT_resetn -of_objects [ipx::current_core]]
set_property physical_name DUT_rst [ipx::get_port_maps RST -of_objects [ipx::get_bus_interfaces DUT_resetn -of_objects [ipx::current_core]]]
set_property display_name DUT_resetn [ipx::get_bus_interfaces DUT_resetn -of_objects [ipx::current_core]]
ipx::add_bus_parameter POLARITY [ipx::get_bus_interfaces DUT_resetn -of_objects [ipx::current_core]]
set_property VALUE ACTIVE_LOW [ipx::get_bus_parameters POLARITY -of_objects [ipx::get_bus_interfaces DUT_resetn -of_objects [ipx::current_core]]]

# Fix up 'clk' interface
set_property VALUE {rst:DUT_rst} [ipx::get_bus_parameters ASSOCIATED_RESET -of_objects [ipx::get_bus_interfaces clk -of_objects [ipx::current_core]]]

# CNT_SIZE parameter
set_property display_name {Counter size} [ipgui::get_guiparamspec -name "CNT_SIZE" -component [ipx::current_core] ]
set_property tooltip {Width of drop_cnt and log_cnt} [ipgui::get_guiparamspec -name "CNT_SIZE" -component [ipx::current_core] ]
set_property widget {textEdit} [ipgui::get_guiparamspec -name "CNT_SIZE" -component [ipx::current_core] ]
set_property value 10 [ipx::get_user_parameters CNT_SIZE -of_objects [ipx::current_core]]
set_property value 10 [ipx::get_hdl_parameters CNT_SIZE -of_objects [ipx::current_core]]

# ADDR_WIDTH parameter
ipgui::remove_param -component [ipx::current_core] [ipgui::get_guiparamspec -name "ADDR_WIDTH" -component [ipx::current_core]]

# ADDR parameter
set_property display_name {Address} [ipgui::get_guiparamspec -name "ADDR" -component [ipx::current_core] ]
set_property tooltip {The unique address identifying this particular debug core} [ipgui::get_guiparamspec -name "ADDR" -component [ipx::current_core] ]
set_property widget {textEdit} [ipgui::get_guiparamspec -name "ADDR" -component [ipx::current_core] ]

# RESET_TYPE parameter
set_property display_name {Reset type} [ipgui::get_guiparamspec -name "RESET_TYPE" -component [ipx::current_core] ]
set_property tooltip {} [ipgui::get_guiparamspec -name "RESET_TYPE" -component [ipx::current_core] ]
set_property widget {comboBox} [ipgui::get_guiparamspec -name "RESET_TYPE" -component [ipx::current_core] ]
set_property value_validation_type pairs [ipx::get_user_parameters RESET_TYPE -of_objects [ipx::current_core]]
set_property value_validation_pairs {None 0 {Active high} 1 {Active low} 2} [ipx::get_user_parameters RESET_TYPE -of_objects [ipx::current_core]]

# PIPE_STAGE parameter
set_property display_name {Enable pipe stage} [ipgui::get_guiparamspec -name "PIPE_STAGE" -component [ipx::current_core] ]
set_property tooltip {Adds a pipe stage to reduce fanout on command stream daisy chain} [ipgui::get_guiparamspec -name "PIPE_STAGE" -component [ipx::current_core] ]
set_property widget {checkBox} [ipgui::get_guiparamspec -name "PIPE_STAGE" -component [ipx::current_core] ]
set_property value true [ipx::get_user_parameters PIPE_STAGE -of_objects [ipx::current_core]]
set_property value true [ipx::get_hdl_parameters PIPE_STAGE -of_objects [ipx::current_core]]
set_property value_format bool [ipx::get_user_parameters PIPE_STAGE -of_objects [ipx::current_core]]
set_property value_format bool [ipx::get_hdl_parameters PIPE_STAGE -of_objects [ipx::current_core]]

# DUT_RST_VAL parameter
set_property display_name {DUT reset value} [ipgui::get_guiparamspec -name "DUT_RST_VAL" -component [ipx::current_core] ]
set_property tooltip {The value that, when applied to the DUT reset port, will cause it to reset} [ipgui::get_guiparamspec -name "DUT_RST_VAL" -component [ipx::current_core] ]
set_property widget {comboBox} [ipgui::get_guiparamspec -name "DUT_RST_VAL" -component [ipx::current_core] ]
set_property value_validation_type pairs [ipx::get_user_parameters DUT_RST_VAL -of_objects [ipx::current_core]]
set_property value_validation_pairs {{Active low} 0 {Active high} 1} [ipx::get_user_parameters DUT_RST_VAL -of_objects [ipx::current_core]]
# SATCNT_WIDTH parameter
set_property display_name {Saturating TREADY-low counter width} [ipgui::get_guiparamspec -name "SATCNT_WIDTH" -component [ipx::current_core] ]
set_property tooltip {Command receipts include a count of cycles since dout_TREADY was last active as a saturating counter. This parameter controls its width} [ipgui::get_guiparamspec -name "SATCNT_WIDTH" -component [ipx::current_core] ]
set_property widget {textEdit} [ipgui::get_guiparamspec -name "SATCNT_WIDTH" -component [ipx::current_core] ]

# DEFAULT_PAUSE parameter
set_property display_name {Pause on startup} [ipgui::get_guiparamspec -name "DEFAULT_PAUSE" -component [ipx::current_core] ]
set_property tooltip {On powerup, keep_pausing is 1. This takes precedence over keep_logging and keep_dropping} [ipgui::get_guiparamspec -name "DEFAULT_PAUSE" -component [ipx::current_core] ]
set_property widget {checkBox} [ipgui::get_guiparamspec -name "DEFAULT_PAUSE" -component [ipx::current_core] ]
set_property value false [ipx::get_user_parameters DEFAULT_PAUSE -of_objects [ipx::current_core]]
set_property value false [ipx::get_hdl_parameters DEFAULT_PAUSE -of_objects [ipx::current_core]]
set_property value_format bool [ipx::get_user_parameters DEFAULT_PAUSE -of_objects [ipx::current_core]]
set_property value_format bool [ipx::get_hdl_parameters DEFAULT_PAUSE -of_objects [ipx::current_core]]

# DEFAULT_LOG parameter
set_property display_name {Log on startup} [ipgui::get_guiparamspec -name "DEFAULT_LOG" -component [ipx::current_core] ]
set_property tooltip {At powerup, keep_logging is 1. Note that keep_pausing takes precedence} [ipgui::get_guiparamspec -name "DEFAULT_LOG" -component [ipx::current_core] ]
set_property widget {checkBox} [ipgui::get_guiparamspec -name "DEFAULT_LOG" -component [ipx::current_core] ]
set_property value false [ipx::get_user_parameters DEFAULT_LOG -of_objects [ipx::current_core]]
set_property value false [ipx::get_hdl_parameters DEFAULT_LOG -of_objects [ipx::current_core]]
set_property value_format bool [ipx::get_user_parameters DEFAULT_LOG -of_objects [ipx::current_core]]
set_property value_format bool [ipx::get_hdl_parameters DEFAULT_LOG -of_objects [ipx::current_core]]

# DEFAULT_DROP parameter
set_property display_name {Drop on startup} [ipgui::get_guiparamspec -name "DEFAULT_DROP" -component [ipx::current_core] ]
set_property tooltip {On powerup, keep_dropping is on. Note that keep_pausing has higher precedence} [ipgui::get_guiparamspec -name "DEFAULT_DROP" -component [ipx::current_core] ]
set_property widget {checkBox} [ipgui::get_guiparamspec -name "DEFAULT_DROP" -component [ipx::current_core] ]
set_property value false [ipx::get_user_parameters DEFAULT_DROP -of_objects [ipx::current_core]]
set_property value false [ipx::get_hdl_parameters DEFAULT_DROP -of_objects [ipx::current_core]]
set_property value_format bool [ipx::get_user_parameters DEFAULT_DROP -of_objects [ipx::current_core]]
set_property value_format bool [ipx::get_hdl_parameters DEFAULT_DROP -of_objects [ipx::current_core]]
set_property value_validation_list value [ipx::get_user_parameters DEFAULT_DROP -of_objects [ipx::current_core]]
set_property value_validation_type none [ipx::get_user_parameters DEFAULT_DROP -of_objects [ipx::current_core]]

# DEFAULT_INJECT parameter
# Why did I even make this?
ipgui::remove_param -component [ipx::current_core] [ipgui::get_guiparamspec -name "DEFAULT_INJECT" -component [ipx::current_core]]

# DATA_HAS_TKEEP parameter
set_property display_name {Has TKEEP} [ipgui::get_guiparamspec -name "DATA_HAS_TKEEP" -component [ipx::current_core] ]
set_property tooltip {Mark as true if debugged stream has TKEEP} [ipgui::get_guiparamspec -name "DATA_HAS_TKEEP" -component [ipx::current_core] ]
set_property widget {checkBox} [ipgui::get_guiparamspec -name "DATA_HAS_TKEEP" -component [ipx::current_core] ]
set_property value true [ipx::get_user_parameters DATA_HAS_TKEEP -of_objects [ipx::current_core]]
set_property value true [ipx::get_hdl_parameters DATA_HAS_TKEEP -of_objects [ipx::current_core]]
set_property value_format bool [ipx::get_user_parameters DATA_HAS_TKEEP -of_objects [ipx::current_core]]
set_property value_format bool [ipx::get_hdl_parameters DATA_HAS_TKEEP -of_objects [ipx::current_core]]

# DATA_HAS_TLAST parameter
set_property display_name {Has TLAST} [ipgui::get_guiparamspec -name "DATA_HAS_TLAST" -component [ipx::current_core] ]
set_property tooltip {Mark true if underlying debugged stream has TLAST} [ipgui::get_guiparamspec -name "DATA_HAS_TLAST" -component [ipx::current_core] ]
set_property widget {checkBox} [ipgui::get_guiparamspec -name "DATA_HAS_TLAST" -component [ipx::current_core] ]
set_property value true [ipx::get_user_parameters DATA_HAS_TLAST -of_objects [ipx::current_core]]
set_property value true [ipx::get_hdl_parameters DATA_HAS_TLAST -of_objects [ipx::current_core]]
set_property value_format bool [ipx::get_user_parameters DATA_HAS_TLAST -of_objects [ipx::current_core]]
set_property value_format bool [ipx::get_hdl_parameters DATA_HAS_TLAST -of_objects [ipx::current_core]]

# DEST_WIDTH parameter
set_property display_name {TDEST Width} [ipgui::get_guiparamspec -name "DEST_WIDTH" -component [ipx::current_core] ]
set_property tooltip {Width of TDEST on debugged stream. Set to 0 to disable (the wire will still be visible, but Vivado will safely optimize it out)} [ipgui::get_guiparamspec -name "DEST_WIDTH" -component [ipx::current_core] ]
set_property widget {textEdit} [ipgui::get_guiparamspec -name "DEST_WIDTH" -component [ipx::current_core] ]
set_property value_validation_type range_long [ipx::get_user_parameters DEST_WIDTH -of_objects [ipx::current_core]]
set_property value_validation_range_minimum 0 [ipx::get_user_parameters DEST_WIDTH -of_objects [ipx::current_core]]
set_property value_validation_range_maximum 32 [ipx::get_user_parameters DEST_WIDTH -of_objects [ipx::current_core]]

# ID_WIDTH parameter
set_property display_name {TID Width} [ipgui::get_guiparamspec -name "ID_WIDTH" -component [ipx::current_core] ]
set_property tooltip {Width of TID on debugged stream. Set to 0 to disable (the wire will still be visible, but Vivado will safely optimize it out)} [ipgui::get_guiparamspec -name "ID_WIDTH" -component [ipx::current_core] ]
set_property widget {textEdit} [ipgui::get_guiparamspec -name "ID_WIDTH" -component [ipx::current_core] ]
set_property value_validation_type range_long [ipx::get_user_parameters ID_WIDTH -of_objects [ipx::current_core]]
set_property value_validation_range_minimum 0 [ipx::get_user_parameters ID_WIDTH -of_objects [ipx::current_core]]
set_property value_validation_range_maximum 32 [ipx::get_user_parameters ID_WIDTH -of_objects [ipx::current_core]]

# Try to arrange things nicely in the GUI window
ipgui::add_group -name {Details of debugged stream} -component [ipx::current_core] -parent [ipgui::get_pagespec -name "Page 0" -component [ipx::current_core] ] -display_name {Details of debugged stream}
ipgui::move_param -component [ipx::current_core] -order 0 [ipgui::get_guiparamspec -name "DATA_WIDTH" -component [ipx::current_core]] -parent [ipgui::get_groupspec -name "Details of debugged stream" -component [ipx::current_core]]
ipgui::move_group -component [ipx::current_core] -order 0 [ipgui::get_groupspec -name "Details of debugged stream" -component [ipx::current_core]] -parent [ipgui::get_pagespec -name "Page 0" -component [ipx::current_core]]
ipgui::move_param -component [ipx::current_core] -order 0 [ipgui::get_guiparamspec -name "DATA_HAS_TKEEP" -component [ipx::current_core]] -parent [ipgui::get_groupspec -name "Details of debugged stream" -component [ipx::current_core]]
ipgui::move_param -component [ipx::current_core] -order 1 [ipgui::get_guiparamspec -name "DATA_HAS_TKEEP" -component [ipx::current_core]] -parent [ipgui::get_groupspec -name "Details of debugged stream" -component [ipx::current_core]]
ipgui::move_param -component [ipx::current_core] -order 1 [ipgui::get_guiparamspec -name "DATA_HAS_TLAST" -component [ipx::current_core]] -parent [ipgui::get_pagespec -name "Page 0" -component [ipx::current_core]]
ipgui::move_param -component [ipx::current_core] -order 1 [ipgui::get_guiparamspec -name "DATA_HAS_TLAST" -component [ipx::current_core]] -parent [ipgui::get_groupspec -name "Details of debugged stream" -component [ipx::current_core]]
ipgui::move_param -component [ipx::current_core] -order 2 [ipgui::get_guiparamspec -name "DATA_HAS_TLAST" -component [ipx::current_core]] -parent [ipgui::get_groupspec -name "Details of debugged stream" -component [ipx::current_core]]
ipgui::move_param -component [ipx::current_core] -order 2 [ipgui::get_guiparamspec -name "DEST_WIDTH" -component [ipx::current_core]] -parent [ipgui::get_groupspec -name "Details of debugged stream" -component [ipx::current_core]]
ipgui::move_param -component [ipx::current_core] -order 3 [ipgui::get_guiparamspec -name "DEST_WIDTH" -component [ipx::current_core]] -parent [ipgui::get_groupspec -name "Details of debugged stream" -component [ipx::current_core]]
ipgui::move_param -component [ipx::current_core] -order 3 [ipgui::get_guiparamspec -name "ID_WIDTH" -component [ipx::current_core]] -parent [ipgui::get_groupspec -name "Details of debugged stream" -component [ipx::current_core]]
ipgui::move_param -component [ipx::current_core] -order 4 [ipgui::get_guiparamspec -name "ID_WIDTH" -component [ipx::current_core]] -parent [ipgui::get_groupspec -name "Details of debugged stream" -component [ipx::current_core]]
ipgui::move_param -component [ipx::current_core] -order 4 [ipgui::get_guiparamspec -name "DUT_RST_VAL" -component [ipx::current_core]] -parent [ipgui::get_groupspec -name "Details of debugged stream" -component [ipx::current_core]]
ipgui::move_param -component [ipx::current_core] -order 5 [ipgui::get_guiparamspec -name "DUT_RST_VAL" -component [ipx::current_core]] -parent [ipgui::get_groupspec -name "Details of debugged stream" -component [ipx::current_core]]
ipgui::add_group -name {Debug governor parameters} -component [ipx::current_core] -parent [ipgui::get_pagespec -name "Page 0" -component [ipx::current_core] ] -display_name {Debug governor parameters}
ipgui::move_group -component [ipx::current_core] -order 0 [ipgui::get_groupspec -name "Debug governor parameters" -component [ipx::current_core]] -parent [ipgui::get_pagespec -name "Page 0" -component [ipx::current_core]]
ipgui::move_param -component [ipx::current_core] -order 0 [ipgui::get_guiparamspec -name "ADDR" -component [ipx::current_core]] -parent [ipgui::get_groupspec -name "Debug governor parameters" -component [ipx::current_core]]
ipgui::move_param -component [ipx::current_core] -order 0 [ipgui::get_guiparamspec -name "SATCNT_WIDTH" -component [ipx::current_core]] -parent [ipgui::get_groupspec -name "Debug governor parameters" -component [ipx::current_core]]
ipgui::move_param -component [ipx::current_core] -order 1 [ipgui::get_guiparamspec -name "SATCNT_WIDTH" -component [ipx::current_core]] -parent [ipgui::get_groupspec -name "Debug governor parameters" -component [ipx::current_core]]
ipgui::move_param -component [ipx::current_core] -order 1 [ipgui::get_guiparamspec -name "CNT_SIZE" -component [ipx::current_core]] -parent [ipgui::get_groupspec -name "Debug governor parameters" -component [ipx::current_core]]
ipgui::move_param -component [ipx::current_core] -order 0 [ipgui::get_guiparamspec -name "DEFAULT_DROP" -component [ipx::current_core]] -parent [ipgui::get_groupspec -name "Details of debugged stream" -component [ipx::current_core]]
ipgui::move_param -component [ipx::current_core] -order 2 [ipgui::get_guiparamspec -name "DEFAULT_DROP" -component [ipx::current_core]] -parent [ipgui::get_groupspec -name "Debug governor parameters" -component [ipx::current_core]]
ipgui::move_param -component [ipx::current_core] -order 3 [ipgui::get_guiparamspec -name "DEFAULT_DROP" -component [ipx::current_core]] -parent [ipgui::get_groupspec -name "Debug governor parameters" -component [ipx::current_core]]
ipgui::move_param -component [ipx::current_core] -order 2 [ipgui::get_guiparamspec -name "DEFAULT_PAUSE" -component [ipx::current_core]] -parent [ipgui::get_groupspec -name "Debug governor parameters" -component [ipx::current_core]]
ipgui::move_param -component [ipx::current_core] -order 3 [ipgui::get_guiparamspec -name "DEFAULT_PAUSE" -component [ipx::current_core]] -parent [ipgui::get_groupspec -name "Debug governor parameters" -component [ipx::current_core]]
ipgui::move_param -component [ipx::current_core] -order 4 [ipgui::get_guiparamspec -name "DEFAULT_LOG" -component [ipx::current_core]] -parent [ipgui::get_groupspec -name "Debug governor parameters" -component [ipx::current_core]]
ipgui::move_param -component [ipx::current_core] -order 5 [ipgui::get_guiparamspec -name "PIPE_STAGE" -component [ipx::current_core]] -parent [ipgui::get_groupspec -name "Debug governor parameters" -component [ipx::current_core]]
ipgui::move_param -component [ipx::current_core] -order 6 [ipgui::get_guiparamspec -name "PIPE_STAGE" -component [ipx::current_core]] -parent [ipgui::get_groupspec -name "Debug governor parameters" -component [ipx::current_core]]
ipgui::move_param -component [ipx::current_core] -order 1 [ipgui::get_guiparamspec -name "DUT_RST_VAL" -component [ipx::current_core]] -parent [ipgui::get_groupspec -name "Debug governor parameters" -component [ipx::current_core]]
ipgui::move_param -component [ipx::current_core] -order 4 [ipgui::get_guiparamspec -name "DUT_RST_VAL" -component [ipx::current_core]] -parent [ipgui::get_groupspec -name "Details of debugged stream" -component [ipx::current_core]]
ipgui::move_param -component [ipx::current_core] -order 5 [ipgui::get_guiparamspec -name "DUT_RST_VAL" -component [ipx::current_core]] -parent [ipgui::get_groupspec -name "Details of debugged stream" -component [ipx::current_core]]
ipgui::move_param -component [ipx::current_core] -order 0 [ipgui::get_guiparamspec -name "RESET_TYPE" -component [ipx::current_core]] -parent [ipgui::get_groupspec -name "Debug governor parameters" -component [ipx::current_core]]
ipgui::move_param -component [ipx::current_core] -order 2 [ipgui::get_guiparamspec -name "RESET_TYPE" -component [ipx::current_core]] -parent [ipgui::get_groupspec -name "Debug governor parameters" -component [ipx::current_core]]
ipgui::move_param -component [ipx::current_core] -order 1 [ipgui::get_guiparamspec -name "RESET_TYPE" -component [ipx::current_core]] -parent [ipgui::get_groupspec -name "Debug governor parameters" -component [ipx::current_core]]


ipx::create_xgui_files [ipx::current_core]
ipx::update_checksums [ipx::current_core]
ipx::save_core [ipx::current_core]
close_project 
exit

