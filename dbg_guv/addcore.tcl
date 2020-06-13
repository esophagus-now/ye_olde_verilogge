# These procs are used to automatically insert dbg_guvs into a design

# Replaces the bd_intf_net n with a dbg_guv core named "inst"
proc add_dbg_core_to_net {n inst} {
    puts "add_dbg_core_to_net args:"
    puts "n = $n"
    puts "inst = $inst"
    
    # Get the two endpoints of this net
    set pins [get_bd_intf_pins -of_objects $n -quiet]
    set ports [get_bd_intf_ports -of_objects $n -quiet]
    
    # For some RIDICULOUS reason, a hierarchy port is both a port and a pin!
    # So we do a little band-aid fix here and remove any element from pins
    # that also appears in ports
    foreach p $ports {
        # see https://stackoverflow.com/questions/5701947/tcl-remove-an-element-from-a-list
        set idx [lsearch $pins $p]
        if {$idx != -1} {
            set pins [lreplace $pins $idx $idx]
        }
    } 
    
    set npins [llength $pins]
    set nports [llength $ports]
    
    # Check if it has the right number of endpoints
    if {[expr $npins + $nports] != 2} {
        puts "Warning: invalid net"
        return -1
    }
    
    # Name the two endpoints left and right
    if {$npins == 2} {
        set left [lindex $pins 0]
        set right [lindex $pins 1]
    } elseif {$npins == 1} {
        set left [lindex $pins 0]
        set right [lindex $ports 0]
    } else {
        set left [lindex $ports 0]
        set right [lindex $ports 1]
    }
    
    list_property $left
    list_property $right
    
    # Double-check that they are in fact AXI Stream
    if {[string compare [get_property VLNV $left] "xilinx.com:interface:axis_rtl:1.0"] != 0} {
        puts "Warning: this is not an AXI Stream interface"
        return -1
    }
    if {[string compare [get_property VLNV $right] "xilinx.com:interface:axis_rtl:1.0"] != 0} {
        puts "Warning: this is not an AXI Stream interface"
        return -1
    }
    
    # Quit early if there is already a dbg_guv at one endpoint of this net
    if {$npins > 0} {
        set left_vlnv [get_property VLNV [get_bd_cells -of_objects $left]]
        if {$left_vlnv == "mmerlini:yov:dbg_guv:1.0"} {
            puts "INFO: net already has a dbg_guv"
            return 0
        }
    }
    
    if {$npins == 2} {
        set right_vlnv [get_property VLNV [get_bd_cells -of_objects $right]]
        if {$right_vlnv == "mmerlini:yov:dbg_guv:1.0"} {
            puts "INFO: net already has a dbg_guv"
            return 0
        }
    }
    
    # Delete the original net
    delete_bd_objs $n
    
    # Instantiate the dbg_guv
    # We do an UGLY hack to deal with Vivado's annoying rules about hierarchies
    set prefix [lindex [regexp -inline {(.*)\/[^\/]*$} "[get_property PATH $n]"] 1]
    set g [create_bd_cell -vlnv mmerlini:yov:dbg_guv $prefix/$inst]
    
    set tdata_width [expr 8 * [get_property CONFIG.TDATA_NUM_BYTES $left]]
    set has_tkeep [get_property CONFIG.HAS_TKEEP $left]
    if {$has_tkeep} {
    	set has_tkeep {true}
    } else {
    	set has_tkeep {false}
    }
    set has_tlast [get_property CONFIG.HAS_TLAST $left]
    if {$has_tlast} {
    	set has_tlast {true}
    } else {
    	set has_tlast {false}
    }
    set tdest_width [get_property CONFIG.TDEST_WIDTH $left]
    set tid_width [get_property CONFIG.TID_WIDTH $left]
    
    set_property -dict [list CONFIG.DATA_WIDTH $tdata_width CONFIG.DATA_HAS_TKEEP $has_tkeep CONFIG.DATA_HAS_TLAST $has_tlast CONFIG.DEST_WIDTH $tdest_width CONFIG.ID_WIDTH $tid_width] [get_bd_cells $g]
    
    # Connect the dbg_guv to the loose endpoints
    if ![string compare [get_property MODE $left] Master] {
        connect_bd_intf_net $g/dout $right
        connect_bd_intf_net $left $g/din
    } else {
        connect_bd_intf_net $g/dout $left
        connect_bd_intf_net $right $g/din
    }
    
    return $g
}

# Searches current BD to get next ID to use for a dbg_guv
proc get_next_dbg_core_id {} {
    puts "get_next_dbg_core_id args:"
    puts "----"
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

# Searches current BD to get next ID to use for an rr_tree
proc get_next_rr_tree_id {} {
    puts "get_next_dbg_core_id args:"
    puts "----"
    set cells [get_bd_cells -hierarchical -filter {NAME =~ RR_TREE*} -quiet]
    set next_id 0
    foreach c $cells {
        set name [get_property NAME $c]
        if {[string first "RR_TREE_" $name] == 0} {
            set idnum [string range $name 9 [string length $name]]
            if [string is integer $idnum] {
                set next_id [expr max($next_id,$idnum+1)]
            }
        }
    }
    return $next_id
}

# Given a list of AXI Stream masters (with only TDATA, TREADY, TVALID, and TLAST)
# hooks up an automatically sized arbiter tree
# Returns a reference to the top-level hierarchy cell
proc rr_tree {msts {data_w 32}} {
    puts "rr_tree args:"
    puts "msts = $msts"
    puts "data_w = $data_w"
    puts "----"
    
    # Quit gracefully if there is no tree to add
    if {[llength $msts] == 0} {
        return
    }
    
    startgroup
    # We need to keep track of the port at the root of the arbitration tree
    # If the user called this function with only one dbg_guv, then no tree will
    # be generated. Otherwise, if we go on to generate a tree, this variable 
    # will be updated
    set arbiter_out [lindex $msts 0]
    
    # Number of rr4 nodes needed to construct the tree
    set nnodes [expr ([llength $msts]+1)/3]    
    
    set slvs {}
    set nodes {}
    while {$nnodes > 0} {
        set node [create_bd_cell -vlnv Marco_Merlini:fpga_bpf:rr4 -name node_$nnodes]
        
        # Don't bother with reset lines. They only make timing harder to close,
        # and for these little infrstructure IPs I don't really care
        set_property CONFIG.RESET_TYPE 0 $node
        # Set the width
        set_property CONFIG.DATA_WIDTH $data_w $node
        
        lappend nodes $node
        lappend slvs [get_bd_intf_pins $node/s0]
        lappend slvs [get_bd_intf_pins $node/s1]
        lappend slvs [get_bd_intf_pins $node/s2]
        lappend slvs [get_bd_intf_pins $node/s3]
        incr nnodes -1
        if {$nnodes > 0} {
            lappend msts [get_bd_intf_pins $node/o ]
        }
    }
    
    while {[llength $msts] > 0 && [llength $slvs] > 0} {
        connect_bd_intf_net [lindex $msts 0] [lindex $slvs 0]
        set msts [lreplace $msts 0 0]
        set slvs [lreplace $slvs 0 0]
    }
    
    
    if {[llength $nodes] > 0} {
        # The user is not allowed to use this name
        set h [create_bd_cell -type hier -name RR_TREE_[get_next_rr_tree_id]]
        
        move_bd_cells $h $nodes
        
        create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 $h/o
        connect_bd_intf_net [get_bd_intf_pins $h/o] [get_bd_intf_pins $h/node_1/o]
        create_bd_pin -dir I $h/clk
        
        connect_bd_net [list [get_bd_pins $h/*/clk] [get_bd_pins $h/clk]]
        
        # Update arbiter_out now that the tree is generated
        set arbiter_out [get_bd_intf_pins $h/o]
    }
    endgroup
    
    return $h
}

proc del_dbg_core {c} {
    startgroup
    
    set left [get_bd_intf_nets -of_objects [get_bd_intf_pins $c/din]]
    set mst [get_bd_intf_pins -of_objects $left -filter "PATH !~ $c/din" -quiet]
    if {[llength $mst] == 0} {
        set mst [get_bd_intf_ports -of_objects $left -filter "PATH !~ $c/din" -quiet]
    }
    
    set right [get_bd_intf_nets -of_objects [get_bd_intf_pins $c/dout]]
    set slv [get_bd_intf_pins -of_objects $right -filter "PATH !~ $c/dout" -quiet]
    if {[llength $slv] == 0} {
        set slv [get_bd_intf_ports -of_objects $right -filter "PATH !~ $c/din" -quiet]
    }
    
    delete_bd_objs [get_bd_intf_nets $left] [get_bd_intf_nets $right]
    delete_bd_objs $c
    
    connect_bd_intf_net $mst $slv
    
    highlight_objects -color_index 3 [get_bd_intf_nets -of_objects $mst]
    
    endgroup
}

proc del_all_dbg_cores {} {
    startgroup
    delete_bd_objs [get_bd_cells -hierarchical -filter {NAME =~ RR_TREE*} -quiet] -quiet
    delete_bd_objs [get_bd_cells DBG_GUV_UNCONCAT -quiet] -quiet
    set dbg_guvs [get_bd_cells -hierarchical -filter {VLNV =~ "*dbg_guv*"} -quiet]
    foreach d $dbg_guvs {
        set nets [get_bd_intf_nets -of_objects $d -quiet]
        delete_bd_objs [get_bd_intf_nets $d/log_catted -quiet] -quiet
        delete_bd_objs [get_bd_intf_nets $d/cmd_out -quiet] -quiet
        del_dbg_core $d
    }
    endgroup
}

# Given a list of nets, instrument each one with a dbg_guv. This code handles a
# number of common issues, such as not adding dbg_guvs if there is already one 
# there, checking if the net is actually an AXI Stream, and of course, the 
# frustrating special cases of port vs. pin. 
proc add_dbg_core_to_list {nets} {
    puts "add_dbg_core_to_list args:"
    puts "nets = $nets"
    puts "----"
    startgroup
    
    # Stores the list of log outputs to run through the arbiter tree
    set log_outs {}
    
    # Stores the previous cmd_out
    set last_cmd {}
    
    # Stores the first cmd_in in the daisy chain
    set first_cmd_in {}
    
    foreach n $nets {
        # Choose an ID. get_next_dbg_core_id guarantees it will be unique, and 
        # if some dbg_guvs don't get added (e.g. if the highlighted net was 
        # invalid), it also makes sure that IDs don't get skipped
        set next_id [get_next_dbg_core_id]
        
        # g holds a reference to the newly create dbg_guv cell
        set g [add_dbg_core_to_net $n GUV_$next_id]
        if {$g == 0} {
            # add_dbg_core_to_net (correctly) did not add a dbg_guv
            continue
        } elseif {$g == -1} {
            # add_dbg_core_to_net encountered an error
            puts "Warning: I can no longer guarantee that the debug cores will work! You may need to add them manually"
            continue
        }
        
        set_property CONFIG.ADDR $next_id $g
        
        # Add $g/log to the list of log outputs
        lappend log_outs $g/logs_receipts
        
        # If last_cmd is not empty, connect its cmd_out to $g/cmd_in
        if {[llength $last_cmd] == 1} {
            connect_bd_intf_net [get_bd_intf_pins $last_cmd] [get_bd_intf_pins $g/cmd_in]
        } else {
            set first_cmd_in [get_bd_intf_pins $g/cmd_in]
        }
        
        # Update last_cmd
        set last_cmd $g/cmd_out
    }
    
    # Connect up the clocks
    # TODO: If I ever plan to allow multiple clock domains, this will have to 
    # change
    if {[llength $log_outs] > 1} {
        # Put in the arbiter tree
        set tree_cell [rr_tree $log_outs 32]
        
        connect_bd_net [list [get_bd_pins -of_objects [get_bd_cells -hierarchical  -filter {VLNV == mmerlini:yov:dbg_guv:1.0}] -filter {NAME == clk}] [get_bd_pins $tree_cell/clk]]
    }
    
    endgroup
}

proc add_dbg_core_to_highlighted {} {
    del_all_dbg_cores
    add_dbg_core_to_list [get_bd_intf_nets [get_highlighted_objects]]
}


proc del_highlighted_dbg_cores {} {
    startgroup
    set cores [get_highlighted_objects]
    foreach c $cores {
        if {[get_property VLNV $c] != "mmerlini:yov:dbg_guv:1.0"} {
            puts "Warning, trying to delete an IP which is not a dbg_guv"
            continue
        }
        
        del_dbg_core $c

    }
    endgroup
}
