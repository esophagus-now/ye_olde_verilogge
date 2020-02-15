# Replaces the bd_intf_net n with a dbg_guv core named "inst"
proc add_dbg_core_to_net {n inst} {
    # Get the two endpoints of this net
    set pins [get_bd_intf_pins -of_objects $n]
    # Check if it has the right number of endpoints
    if {[llength $pins] != 2} {
        puts "Warning: invalid net"
        return -1
    }
    
    # Name the two endpoints left and right
    set left [lindex $pins 0]
    set right [lindex $pins 1]
    
    # Double-check that they are in fact AXI Stream
    if {[string compare [get_property VLNV $left] "xilinx.com:interface:axis_rtl:1.0"] != 0} {
        puts "Warning: this is not an AXI Stream interface"
        return -1
    }
    
    # Quit early if there is already a dbg_guv at one endpoint of this net
    set left_vlnv [get_property VLNV [get_bd_cells -of_objects $left]]
    set right_vlnv [get_property VLNV [get_bd_cells -of_objects $right]]
    if {$left_vlnv == "mmerlini:yov:dbg_guv:1.0" || $right_vlnv == "mmerlini:yov:dbg_guv:1.0"} {
        puts "INFO: net already has a dbg_guv"
        return 0
    }
    
    # Delete the original net
    delete_bd_objs $n
    
    # Instantiate the dbg_guv
    set g [create_bd_cell -vlnv mmerlini:yov:dbg_guv $inst]

    # Connect the dbg_guv to the loose endpoints
    if ![string compare [get_property MODE $left] Master] {
        connect_bd_intf_net -intf_net GUV_${inst}_mst $g/out $right
        connect_bd_intf_net -intf_net GUV_${inst}_slv $left $g/in
    } else {
        connect_bd_intf_net -intf_net GUV_${inst}_mst $g/out $left
        connect_bd_intf_net -intf_net GUV_${inst}_slv $right $g/in
    }
    
    return 0
}

# Searches current BD to get next ID to use for a dbg_guv
proc get_next_dbg_core_id {} {
    set cells [get_bd_cells -hierarchical -filter {VLNV == mmerlini:yov:dbg_guv:1.0} -quiet]
    set next_id 0
    foreach c $cells {
        set name [get_property NAME $c]
        if {[string first "GUV_" $name] == 0} {
            set idnum [string range $name 4 [string length $name]]
            if [string is integer $idnum] {
                set next_id [expr max($next_id,$idnum+1)]
            }
        }
    }
    return $next_id
}

proc add_dbg_core_to_highlighted {} {
    startgroup
    set nets [get_bd_intf_nets [get_highlighted_objects]]
    foreach n $nets {
        set next_id [get_next_dbg_core_id]
        add_dbg_core_to_net $n GUV_$next_id
    }
    endgroup
}

proc del_highlighted_dbg_cores {} {
    
}
