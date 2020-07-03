//Copyright 2020 Marco Merlini. This file is part of the fpga-bpf project,
//whose license information can be found at 
//https://github.com/UofT-HPRC/fpga-bpf/blob/master/LICENSE

/* BIG LIST OF TODOS
    
[x] Edit and rename bpf_defs.vh to match new ISA
[x] Add MUL/DIV/MOD into ALU with proper handshaking
[x] Add immediate and jump offset memory to datapath
[x] Instantiate instruction memory in datapath
[ ] Implement instructions for setting imm and jmp_off
[ ] Implement instructions for reading/writing to stream 
    -> Include "PASS" instruction?
[ ] Add TLAST register and special jump type for it
[ ] Add in axis_reg_map register for single-stepping (gate inst_rd_en?)
[ ] Add logic to program instruction and immediate memory from axis_reg_map
[ ] Implement special logic to read jump amount 
[ ] Add code to send register values over debug stream
[ ] Update sims

*/

`timescale 1ns / 1ps

`ifdef ICARUS_VERILOG
`include "macros.vh"
`include "controller.v"
`include "datapath.v"
`default_nettype none
`endif

module axis_cpu # (
    parameter CODE_ADDR_WIDTH = 10,
    parameter PESS = 0
) (
    input wire clk,
    input wire rst,

    //Interface to outside world
    `in_axis_l(din, 32),
    `out_axis_l(dout, 32),
    
    //Programming ports
    input wire [31:0] cmd_in_TDATA,
    input wire cmd_in_TVALID,
    
    output wire [31:0] cmd_out_TDATA,
    output wire cmd_out_TVALID,
    
    //Debug ports
    `out_axis_l(dbg, 32)
);
    
    wire hold_in_rst; //TODO: hook this up to axis_reg_map
    
    //Controller outputs
    wire [1:0] PC_sel; 
    wire PC_en;
    wire inst_rd_en;
    wire B_sel;
    wire [3:0] ALU_sel;
    wire ALU_en;
    wire addr_sel;
    wire regfile_sel; //Whether A or X is written to the regfile
    wire regfile_wr_en;
    wire [3:0] regfile_wr_addr;
    wire [3:0] utility_addr; //Used for setting jmp_off_sel or imm_sel
    wire jmp_off_sel_en;
    wire imm_sel_en;
    wire [2:0] A_sel;
    wire A_en;
    wire [2:0] X_sel;
    wire X_en;
    wire ALU_ack;
    wire [CODE_ADDR_WIDTH -1:0] jmp_correction;
    
    //Datapath outputs
    wire eq;
    wire gt;
    wire ge;
    wire set;
    wire ALU_vld;
    wire [7:0] instr;
    
    controller # (
        .CODE_ADDR_WIDTH(CODE_ADDR_WIDTH),
        .PESS(PESS)
    ) ctrl (
        .clk(clk),
        .rst(rst || hold_in_rst),
        .eq(eq),
        .gt(gt),
        .ge(ge),
        .set(set),
        .ALU_vld(ALU_vld),
        .din_TVALID(din_TVALID),
        .din_TREADY(din_TREADY),
        .dout_TVALID(dout_TVALID),
        .dout_TREADY(dout_TREADY),
        .instr_in(instr),
        .inst_rd_en(inst_rd_en),
        .PC_en(PC_en),
        .B_sel(B_sel),
        .ALU_sel(ALU_sel),
        .ALU_en(ALU_en),
        .regfile_wr_addr(regfile_wr_addr),
        .regfile_wr_en(regfile_wr_en),
        .regfile_sel(regfile_sel),
        .PC_sel(PC_sel), 
        .A_sel(A_sel),
        .A_en(A_en),
        .X_sel(X_sel),
        .X_en(X_en),
        .ALU_ack(ALU_ack),
        .jmp_correction(jmp_correction)
    );

    datapath # (
        .CODE_ADDR_WIDTH(CODE_ADDR_WIDTH)
    ) dpath (
        .clk(clk),
        .rst(rst || hold_in_rst),
        .A_sel(A_sel),
        .A_en(A_en),
        .X_sel(X_sel),
        .X_en(X_en),
        .PC_sel(PC_sel),
        .PC_en(PC_en),
        .inst_rd_en(inst_rd_en),
        .instr(instr),
        .B_sel(B_sel),
        .ALU_sel(ALU_sel),
        .ALU_en(ALU_en),
        .eq(eq),
        .gt(gt),
        .ge(ge),
        .set(set),
        .ALU_vld(ALU_vld),
        .ALU_ack(ALU_ack),
        .utility_addr(utility_addr),
        .jmp_off_sel_en(jmp_off_sel_en),
        .imm_sel_en(imm_sel_en),
        .regfile_sel(regfile_sel),
        .regfile_wr_addr(regfile_wr_addr),
        .regfile_wr_en(regfile_wr_en),
        .jmp_correction(jmp_correction)
    );

endmodule

`undef localparam
