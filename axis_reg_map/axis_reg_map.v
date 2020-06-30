`timescale 1ns / 1ps


/*
This file was obtained by copying out my command FSM code from the dbg_guv
and then editing it slightly

*/

`ifdef ICARUS_VERILOG
`include "macros.vh"
`endif

module axis_reg_map # (
    parameter REG_ADDR_WIDTH = 4,
    parameter ADDR_WIDTH = 12,
    parameter [ADDR_WIDTH -1:0] ADDR = 0, //Set this to be different for each 
    parameter RESET_TYPE = `NO_RESET,
    parameter PIPE_STAGE = 1
) (
    input wire clk,
    input wire rst,
    
    //Input command stream
    input wire [31:0] cmd_in_TDATA,
    input wire cmd_in_TVALID,
    
    //All the reg_maps are daisy-chained. 
    output wire [31:0] cmd_out_TDATA,
    output wire cmd_out_TVALID,
    
    //Register update outputs, used by whatever is instantiating this module
    output wire [REG_ADDR_WIDTH -1:0] reg_addr,
    output wire [31:0] reg_data,
    output wire reg_strb
);

    //Named subfields of command
    wire [ADDR_WIDTH -1:0] cmd_core_addr = cmd_in_TDATA[ADDR_WIDTH + REG_ADDR_WIDTH -1 -: ADDR_WIDTH];
    wire [REG_ADDR_WIDTH -1:0] cmd_reg_addr = cmd_in_TDATA[REG_ADDR_WIDTH -1:0];  
    //We need to know if this message was meant for us
    wire msg_for_us = (cmd_core_addr == ADDR);
    
    `wire_rst_sig;
    
    `localparam [1:0] CMD_FSM_ADDR = 0;
    `localparam [1:0] CMD_FSM_DATA = 1;
    `localparam [1:0] CMD_FSM_IGNORE = 2;
    
    reg [1:0] cmd_fsm_state = CMD_FSM_ADDR;
    reg [REG_ADDR_WIDTH -1:0] saved_reg_addr = 0;
    
`genif (RESET_TYPE == `NO_RESET) begin
    always @(posedge clk) begin
        if (cmd_in_TVALID) begin
            case (cmd_fsm_state)
                CMD_FSM_ADDR: begin
                    cmd_fsm_state <= msg_for_us ? 
                        CMD_FSM_DATA : 
                        CMD_FSM_IGNORE
                    ;
                        
                    saved_reg_addr <= cmd_reg_addr;
                end CMD_FSM_DATA: begin
                    cmd_fsm_state <= CMD_FSM_ADDR;
                end CMD_FSM_IGNORE: begin
                    cmd_fsm_state <= CMD_FSM_ADDR;
                end
            endcase
        end
    end
`else_gen //HAS_RST
    always @(posedge clk) begin
        if (rst_sig) begin
            cmd_fsm_state <= CMD_FSM_ADDR;
        end else if (cmd_in_TVALID) begin
            case (cmd_fsm_state)
                CMD_FSM_ADDR: begin
                    cmd_fsm_state <= msg_for_us ? 
                        CMD_FSM_DATA : 
                        CMD_FSM_IGNORE
                    ;
                        
                    saved_reg_addr <= cmd_reg_addr;
                end CMD_FSM_DATA: begin
                    cmd_fsm_state <= CMD_FSM_ADDR;
                end CMD_FSM_IGNORE: begin
                    cmd_fsm_state <= CMD_FSM_ADDR;
                end
            endcase
        end
    end
`endgen
    
    assign reg_addr = saved_reg_addr;
    assign reg_data = cmd_in_TDATA;
    assign reg_strb = cmd_in_TVALID && (cmd_fsm_state == CMD_FSM_DATA);
    
    //Assign cmd_out according to whether the user turned on the pipe stage
`genif (PIPE_STAGE) begin
    //Delay by one cycle for timing
    reg [31:0] cmd_out_TDATA_r = 0;
    reg cmd_out_TVALID_r = 0;
    
    always @(posedge clk) begin
        cmd_out_TDATA_r <= cmd_in_TDATA;
        cmd_out_TVALID_r <= cmd_in_TVALID;
    end
    
    assign cmd_out_TDATA = cmd_out_TDATA_r;
    assign cmd_out_TVALID = cmd_out_TVALID_r;
`else_gen 
    assign cmd_out_TDATA = cmd_in_TDATA;
    assign cmd_out_TVALID = cmd_in_TVALID;
`endgen   

endmodule
