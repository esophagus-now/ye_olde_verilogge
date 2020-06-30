//Copyright 2020 Marco Merlini. This file is part of the fpga-bpf project,
//whose license information can be found at 
//https://github.com/UofT-HPRC/fpga-bpf/blob/master/LICENSE

/* BIG LIST OF TODOS
    
[ ] Edit and rename bpf_defs.vh to match new ISA
[ ] Add MUL/DIV/MOD into ALU with proper handshaking
[ ] Add TLAST register and special jump type for it
[ ] Add in axis_reg_map register for single-stepping (gate inst_rd_en?)
[ ] Instantiate instruction memory in here
[ ] Add immediate memory to datapath
[ ] Add logic to program instruction and immediate memory from axis_reg_map
[ ] Implement special logic to read jump amount 
[ ] Implement instructions for reading/writing to stream 
    -> Include "PASS" instruction?
[ ] Add code to send register values over debug stream
[ ] Update sims

*/

`timescale 1ns / 1ps

`ifdef ICARUS_VERILOG
`include "macros.vh"
`endif

module axis_cpu # (
    parameter CODE_ADDR_WIDTH = 10,
    parameter CODE_DATA_WIDTH = 8,
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
    `out_axis_l(dbg, 32),
    
    //Interface to intruction memory
    output wire [CODE_ADDR_WIDTH-1:0] inst_rd_addr,
    output wire inst_rd_en,
    input wire [CODE_DATA_WIDTH-1:0] instr_in

);
    
    //Controller outputs
    wire [1:0] PC_sel; 
    wire PC_en;
    wire B_sel;
    wire [3:0] ALU_sel;
    wire ALU_en;
    wire addr_sel;
    wire regfile_wr_en;
    wire [31:0] imm_stage1;
    wire [7:0] jt;
    wire [7:0] jf;
    wire [2:0] A_sel;
    wire A_en;
    wire [2:0] X_sel;
    wire X_en;
    wire [3:0] regfile_sel;
    wire [31:0] imm_stage2;
    wire ALU_ack;
    wire [CODE_ADDR_WIDTH-1:0] jmp_correction;
    
    //Datapath outputs
    wire eq;
    wire gt;
    wire ge;
    wire set;
    wire ALU_vld;
    
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
        .instr_in(instr_in),
        .mem_vld(resized_mem_data_vld), //TODO: add caching to cpu_adapter
        .inst_rd_en(inst_rd_en),
        .rd_en(cpu_rd_en),
        .acc(cpu_acc),
        .rej(cpu_rej),
        .PC_en(PC_en),
        .B_sel(B_sel),
        .ALU_sel(ALU_sel),
        .ALU_en(ALU_en),
        .addr_sel(addr_sel),
        .transfer_sz(transfer_sz),
        .regfile_wr_en(regfile_wr_en),
        .imm_stage1(imm_stage1),
        .jt(jt),
        .jf(jf),
        .PC_sel(PC_sel), 
        .A_sel(A_sel),
        .A_en(A_en),
        .X_sel(X_sel),
        .X_en(X_en),
        .regfile_sel(regfile_sel),
        .imm_stage2(imm_stage2),
        .ALU_ack(ALU_ack),
        .jmp_correction(jmp_correction)
    );

    datapath # (
        .BYTE_ADDR_WIDTH(BYTE_ADDR_WIDTH),
        .CODE_ADDR_WIDTH(CODE_ADDR_WIDTH),
        .PLEN_WIDTH(PLEN_WIDTH)
    ) dpath (
        .clk(clk),
        .rst(rst || hold_in_rst),
        .A_sel(A_sel),
        .A_en(A_en),
        .X_sel(X_sel),
        .X_en(X_en),
        .PC_sel(PC_sel),
        .PC_en(PC_en),
        .inst_rd_addr(inst_rd_addr),
        .B_sel(B_sel),
        .ALU_sel(ALU_sel),
        .ALU_en(ALU_en),
        .eq(eq),
        .gt(gt),
        .ge(ge),
        .set(set),
        .ALU_vld(ALU_vld),
        .ALU_ack(ALU_ack),
        .regfile_sel(regfile_sel),
        .regfile_wr_en(regfile_wr_en),
        .addr_sel(addr_sel),
        .packet_rd_addr(byte_rd_addr),
        .packet_data(resized_mem_data),
        .packet_len(cpu_byte_len),
        .imm_stage1(imm_stage1),
        .imm_stage2(imm_stage2),
        .jt(jt),
        .jf(jf),
        .jmp_correction(jmp_correction)
    );

endmodule

`undef localparam
