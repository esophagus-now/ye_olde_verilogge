//Copyright 2020 Marco Merlini. This file is part of the fpga-bpf project,
//whose license information can be found at 
//https://github.com/UofT-HPRC/fpga-bpf/blob/master/LICENSE

`timescale 1ns / 1ps


`ifdef ICARUS_VERILOG
`include "axis_cpu_defs.vh"
`include "axis_cpu.v"
`endif


module axis_cpu_tb # (
    parameter CODE_ADDR_WIDTH = 10,
    parameter REG_ADDR_WIDTH = 4, //Seems good enough
    parameter CPU_ID_WIDTH = 12,
    parameter [CPU_ID_WIDTH-1:0] CPU_ID = 0, //Basically like a base address, used for AXIS register map
    parameter PESS = 0
);        
    reg clk = 0;
    reg rst = 0;
    
    //Interface to outside world
    `sim_in_axis_l(din, 32);
    `sim_out_axis_l(dout, 32);
    
    //Programming ports
    reg [31:0] cmd_in_TDATA;
    reg cmd_in_TVALID;
    
    wire [31:0] cmd_out_TDATA;
    wire cmd_out_TVALID;
    
    //Debug ports
    `sim_out_axis(to_guv, 80);
    `sim_in_axis(from_guv, 80);
    
    `auto_tb_decls;
    
    initial begin
        $dumpfile("axis_cpu.vcd");
        $dumpvars;
        $dumplimit(512000);
        
        `open_drivers_file("axis_cpu_drivers.mem");
        
        //Just to prevent simulation going forever
        #10000 
        $display("Simulation timeout");
        $finish;
    end
    
    always #5 clk <= ~clk;
    
    `auto_tb_read_loop(clk)
        `dummy = $fscanf(`fd, "%h%b%d%b%b%b%d%b%b%b", 
            cmd_in_TDATA,
            cmd_in_TVALID,
            
            din_TDATA,
            din_TVALID,
            din_TREADY_exp,
            din_TLAST,
            
            dout_TDATA_exp,
            dout_TVALID_exp,
            dout_TREADY,
            dout_TLAST_exp
        );
    `auto_tb_read_end
    
    `auto_tb_test_loop(clk)
        `test(din_TREADY, din_TREADY_exp);
        `test(dout_TVALID, dout_TVALID_exp);
        if (`axis_flit(dout)) begin
            `test(dout_TDATA, dout_TDATA_exp);
            `test(dout_TLAST, dout_TLAST_exp);
        end
    `auto_tb_test_end
    
    axis_cpu # (
		.CODE_ADDR_WIDTH(CODE_ADDR_WIDTH),
		.REG_ADDR_WIDTH(REG_ADDR_WIDTH),
		.CPU_ID_WIDTH(CPU_ID_WIDTH),
		.CPU_ID(0), 
		.PESS(PESS)
    ) DUT (
		.clk(clk),
		.rst(rst),

        //Interface to outside world
        `inst_axis_l(din, din),
        `inst_axis_l(dout, dout),
        
        //Programming ports
		.cmd_in_TDATA(cmd_in_TDATA),
		.cmd_in_TVALID(cmd_in_TVALID),
        
		.cmd_out_TDATA(cmd_out_TDATA),
		.cmd_out_TVALID(cmd_out_TVALID),
        
        //Debug ports
        `inst_axis(to_guv, to_guv),
        `inst_axis(from_guv, from_guv)
    );

endmodule
