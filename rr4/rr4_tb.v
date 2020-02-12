`timescale 1ns / 1ps

/*
testbench_template.v

Replace innards with desired logic
*/

`include "rr4.v"
`include "macros.vh"

module rr4_tb # (
    parameter DATA_WIDTH = 8,
    parameter PIPE_STAGE = 1,
    parameter RESET_TYPE = `NO_RESET,
    parameter TLAST_ARB = 1
);
	reg clk = 0;
    reg rst = 0;
    //Other variables connected to your instance
    `sim_in_axis_l(s0, DATA_WIDTH);
    `sim_in_axis_l(s1, DATA_WIDTH);
    `sim_in_axis_l(s2, DATA_WIDTH);
    `sim_in_axis_l(s3, DATA_WIDTH);
    `sim_out_axis_l(o, DATA_WIDTH);
    
    //Makes sim easier to read
    wire [1:0] who = o_TDATA[1:0];
    wire o_flit = `axis_flit(o);
    
    integer fd, dummy;
    
    initial begin
        $dumpfile("rr4.vcd");
        $dumpvars;
        $dumplimit(512000);
        
        s0_TDATA = 0;
        s1_TDATA = 1;
        s2_TDATA = 2;
        s3_TDATA = 3;
        
        s0_TVALID = 0;
        s1_TVALID = 0;
        s2_TVALID = 0;
        s3_TVALID = 0;
        
        s0_TLAST = 0;
        s1_TLAST = 0;
        s2_TLAST = 0;
        s3_TLAST = 0;
        
        fd = $fopen("rr4_drivers.mem", "r");
        if (fd == 0) begin
            $display("Could not open file");
            $finish;
        end
        
        while ($fgetc(fd) != "\n") begin
            if ($feof(fd)) begin
                $display("Error: file is in incorrect format");
                $finish;
            end
        end
    end
    
    always #5 clk <= ~clk;
    
    always @(posedge clk) begin
        if ($feof(fd)) begin
            $display("Reached end of drivers file");
            #20
            $finish;
        end
        
        //#0.01
        //dummy = $fscanf(fd, "%F%O%R%M%A%T", /* list of variables */);
        #600
        $finish;
    end
    
    //Quick and dirty test vectors
    always @(posedge clk) begin
        if (`axis_flit(s0))
            s0_TDATA <= s0_TDATA + 4;
        if (`axis_flit(s1))
            s1_TDATA <= s1_TDATA + 4;
        if (`axis_flit(s2))
            s2_TDATA <= s2_TDATA + 4;
        if (`axis_flit(s3))
            s3_TDATA <= s3_TDATA + 4;
        
        s0_TVALID <= $random;
        s1_TVALID <= $random;
        s2_TVALID <= $random;
        s3_TVALID <= $random;
        s0_TLAST <= $random;
        s1_TLAST <= $random;
        s2_TLAST <= $random;
        s3_TLAST <= $random;
        o_TREADY <= $random;
    end

    rr4 # (
		.DATA_WIDTH(DATA_WIDTH),
		.PIPE_STAGE(PIPE_STAGE),
		.RESET_TYPE(RESET_TYPE),
		.TLAST_ARB(TLAST_ARB)
    ) DUT (
        clk, rst,
        
        `ports_axis_l(s0),
        `ports_axis_l(s1),
        `ports_axis_l(s2),
        `ports_axis_l(s3),
        
        `ports_axis_l(o)
    );


endmodule
