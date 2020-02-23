`timescale 1ns / 1ps

//This is just supposed to be QUICK and DIRTY.
//It will not work if both strobes are high on the same cycle (but this will 
//never happen in the specific case I plan to use this module)

`include "macros.vh"

module regs2cmd # (
    parameter RESET_TYPE = `NO_RESET
) (
    input wire clk,
    input wire rst,
    
    input wire [31:0] cmd_lo,
    input wire cmd_lo_strobe,
    input wire [31:0] cmd_hi,
    input wire cmd_hi_strobe,
    
    output wire [63:0] cmd_TDATA,
    output wire cmd_TVALID
);

    reg lo_vld = 0;
    reg hi_vld = 0;
    
    assign cmd_TDATA = {cmd_hi, cmd_lo};
    assign cmd_TVALID = (lo_vld && cmd_hi_strobe) || (hi_vld && cmd_lo_strobe);
    
    `wire_rst_sig;

`genif (RESET_TYPE == `NO_RESET) begin
    always @(posedge clk) begin
        if (cmd_TVALID) begin
            lo_vld <= 0;
            hi_vld <= 0;
        end else begin
            lo_vld <= lo_vld || cmd_lo_strobe;
            hi_vld <= hi_vld || cmd_hi_strobe;
        end
    end
`else_gen
    always @(posedge clk) begin
        if (cmd_TVALID || rst_sig) begin
            lo_vld <= 0;
            hi_vld <= 0;
        end else begin
            lo_vld <= lo_vld || cmd_lo_strobe;
            hi_vld <= hi_vld || cmd_hi_strobe;
        end
    end
`endgen
endmodule
