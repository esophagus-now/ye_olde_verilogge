//Copyright 2020 Marco Merlini. This file modified from the fpga-bpf project,
//whose license information can be found at 
//https://github.com/UofT-HPRC/fpga-bpf/blob/master/LICENSE

`timescale 1ns / 1ps

/* 
inst_mem.v Instantiates an sdpram module and presents an interface with rd_en 
and wr_en (instead of clock_en and wr_en). 
*/


/*
sdpram:

A simple Verilog module that implements SDP (simple dual port) RAM. The reason 
for choosing SDP is because the FPGA's BRAMs already support it "at no extra 
cost". If instead I tried multiplexing the address port, I would add 
propagation delays and a bunch of extra logic.

(inst_mem module is below)

*/

//Undefine this for normal usage
//`define PRELOAD_TEST_PROGRAM


`ifdef ICARUS_VERILOG
`define localparam parameter
`else /*For Vivado*/
`define localparam localparam

//(* keep_hierarchy = "yes" *)
`endif

//sdpram doesn't infer correctly! This is a Vivado bug. We'll use true dual port
//instead, even though I don't like it...
module sdpram # (parameter
    ADDR_WIDTH = 10,
    DATA_WIDTH = 64 //TODO: I might try shrinking the opcodes at some point
)(
    input wire clk,
    input wire en, //Clock enable
    input wire [ADDR_WIDTH-1:0] wr_addr,
    input wire [DATA_WIDTH-1:0] wr_data,
    input wire wr_en,
    input wire [ADDR_WIDTH-1:0] rd_addr,
    output reg [DATA_WIDTH-1:0] rd_data
);
    `localparam DEPTH = 2**ADDR_WIDTH;

    reg [DATA_WIDTH-1:0] data[0:DEPTH-1];

    //For testing purposes, this preloads the memory with a program
    `ifdef PRELOAD_TEST_PROGRAM
    `include "axis_cpu_defs.vh"

    initial begin
        data[0]  = {`AXIS_CPU_LD, 1'b0, `AXIS_CPU_STREAM}; //IN
        data[1]  = {`AXIS_CPU_TAX, 4'b0}; //TAX
        data[2]  = {`AXIS_CPU_ALU, `ALU_SEL_X, 1'b0, `AXIS_CPU_ADD}; //ADD X
        data[3]  = {`AXIS_CPU_ST, 1'b1, 4'b1}; //OUT (and set TLAST)
        data[4]  = {`AXIS_CPU_SET_JMP_OFF, 4'd3};             //JA -5 (part 1). Select index 3 from the jump offset table (this is arbitrary; it depends on you loading -5 in two's complement into the table beforehand)
        data[5]  = {`AXIS_CPU_JMP, 1'b0, 1'b0, `AXIS_CPU_JA}; //JA -5 (part 2)
        
    end
    `endif

    always @(posedge clk) begin
        if (en) begin
            if (wr_en) begin
                data[wr_addr] <= wr_data;
            end
            rd_data <= data[rd_addr];
        end
    end

endmodule

module inst_mem # (
	parameter ADDR_WIDTH = 10,
    parameter DATA_WIDTH = 64
)(
    input wire clk,
    input wire [ADDR_WIDTH-1:0] wr_addr,
    input wire [DATA_WIDTH-1:0] wr_data,
    input wire wr_en,
    input wire [ADDR_WIDTH-1:0] rd_addr,
    output wire [DATA_WIDTH-1:0] rd_data,
    input wire rd_en
);

wire clock_en;
assign clock_en = rd_en | wr_en;

sdpram # (.ADDR_WIDTH(ADDR_WIDTH),.DATA_WIDTH(DATA_WIDTH)) myram (
    .clk(clk),
    .en(clock_en),
    .wr_addr(wr_addr),
    .wr_data(wr_data),
    .wr_en(wr_en),
    .rd_addr(rd_addr),
    .rd_data(rd_data)
);

endmodule

`undef localparam
