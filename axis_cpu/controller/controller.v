//Copyright 2020 Marco Merlini. This file is part of the fpga-bpf project,
//whose license information can be found at 
//https://github.com/UofT-HPRC/fpga-bpf/blob/master/LICENSE

`timescale 1ns / 1ps

/*
controller.v

Hooks up all the controller stages into one module
*/

`ifdef ICARUS_VERILOG
`include "stage0.v"
`include "stage0_point_5.v"
`include "stage1.v"
`include "stage2.v"
`default_nettype none
`endif
`include "axis_cpu_defs.vh"


`define genif generate if
`define endgen end endgenerate

module controller # (
    parameter CODE_ADDR_WIDTH = 10,
    parameter PESS = 0
) (
    input wire clk,
    input wire rst,
    
    //Inputs from datapath
    input wire eq,
    input wire gt,
    input wire ge,
    input wire set,
    input wire last,
    input wire ALU_vld,
    
    //Input stream handshaking signals (TDATA and TLAST go into datapath)
    input wire din_TVALID,
    output wire din_TREADY,
    
    //Interface to instruction memory
    input wire [7:0] instr_in,
    
    //Outputs to code memory
    output wire inst_rd_en,
    
    //Output stream handshaking signals (TDATA and TLAST come from datapath)
    output wire dout_TVALID,
    input wire dout_TREADY,
    
    //Outputs to datapath
    output wire branch_mispredict,
    //stage0 (and stage2)
    output wire PC_en,
    //stage1
    output wire B_sel,
    output wire [3:0] ALU_sel,
    output wire ALU_en,
    
    //stage2
    output wire [1:0] PC_sel, //branch_mispredict signifies when to use stage2's PC_sel over stage0's
    output wire [2:0] A_sel,
    output wire A_en,
    output wire [2:0] X_sel,
    output wire X_en,
    output wire regfile_sel, //selects A or X as input to register file
    output wire regfile_wr_en,
    output wire ALU_ack,
    output wire [3:0] utility_addr, //Used for setting jmp_off_sel or imm_sel
    output wire jmp_off_sel_en,
    output wire imm_sel_en,
    output wire last_out,
    output wire last_en,
    output wire [CODE_ADDR_WIDTH-1:0] jmp_correction,
    
    //Debug signals. Idea is that stage0 connects into to_guv, and from_guv 
    //connects into stage1
    output wire to_guv_TVALID,
    input wire to_guv_TREADY,
    
    input wire from_guv_TVALID,
    output wire from_guv_TREADY
);

    //Stage 0 outputs
    wire vld_stage0;
    
    //Stage 0.5 outputs (not always used)
    wire [7:0] instr_out_stage0_5;
    wire [5:0] ocount_stage0_5;
    wire rdy_stage0_5;
    wire vld_stage0_5;
    
    //Stage 1 outputs
    wire [7:0] instr_out_stage1;
    wire [5:0] ocount_stage1;
    wire rdy_stage1;
    wire vld_stage1;
    
    //Stage 2 outputs
    wire [1:0] PC_sel_stage2; //branch_mispredict signifies when to use stage2's PC_sel over stage0's
    //wire branch_mispredict;
    wire stage2_writes_A;
    wire stage2_writes_X;
    wire stage2_writes_imm;
    wire rdy_stage2;


`genif (PESS) begin : with_idle_stage
    stage0 fetch  (
        .clk(clk),
        .rst(rst),
        .branch_mispredict(branch_mispredict),
        .inst_rd_en(inst_rd_en),
        .PC_en(PC_en),
        .next_rdy(rdy_stage0_5),
        .vld(vld_stage0)
    );
    
    stage0_point_5 idle_stage  (
        .clk(clk),
        .rst(rst),
        .instr_in(instr_in),
        .instr_out(instr_out_stage0_5),
        .PC_en(PC_en),
        .icount(6'b0),
        .ocount(ocount_stage0_5),
        .branch_mispredict(branch_mispredict),
        .prev_vld(vld_stage0),
        .rdy(rdy_stage0_5),
        .next_rdy(to_guv_TREADY),
        .vld(to_guv_TVALID)
    );
    
    //Normally, stage0_point_5.vld goes into stage1.prev_vld and stage1.rdy
    //goes into stage0_5.next_rdy. Instead, we redirect these two signals
    //through the governor. (By the way, if debugging is disabled, axis_cpu.v
    //will just wire these back together)
    
    stage1 decode  (
		.clk(clk),
		.rst(rst),
        
		.instr_in(instr_out_stage0_5),
		.branch_mispredict(branch_mispredict),
        
        //Signals for stall logic
		.stage2_writes_A(stage2_writes_A),
		.stage2_writes_X(stage2_writes_X),
		.stage2_writes_imm(stage2_writes_imm),
        
        //Outputs from this stage:
		.B_sel(B_sel),
		.ALU_sel(ALU_sel),
		.ALU_en(ALU_en),
        
        //Outputs for next stage (registered in this module):
        //Simplification: just output the instruction and let stage 2 do the thinking
		.instr_out(instr_out_stage1),
        
        //count number of cycles instruction has been around for
		.PC_en(PC_en),
		.icount(ocount_stage0_5),
		.ocount(ocount_stage1),
        
        //Handshaking signals
		.prev_vld(from_guv_TVALID),
		.rdy(from_guv_TREADY),
		.next_rdy(rdy_stage2),
		.vld(vld_stage1)
    );
end else begin : no_idle_stage   
    stage0 fetch  (
        .clk(clk),
        .rst(rst),
        .branch_mispredict(branch_mispredict),
        .inst_rd_en(inst_rd_en),
        .PC_en(PC_en),
        .next_rdy(to_guv_TREADY),
        .vld(to_guv_TVALID)
    );
    
    
    //Normally, stage0.vld goes into stage1.prev_vld and stage1.rdy goes 
    //into stage0.next_rdy. Instead, we redirect these two signals through 
    //the governor. (By the way, if debugging is disabled, axis_cpu.v will 
    //just wire these back together)
    
    stage1 decode  (
		.clk(clk),
		.rst(rst),
        
		.instr_in(instr_in),
		.branch_mispredict(branch_mispredict),
        
        //Signals for stall logic
		.stage2_writes_A(stage2_writes_A),
		.stage2_writes_X(stage2_writes_X),
		.stage2_writes_imm(stage2_writes_imm),
        
        //Outputs from this stage:
		.B_sel(B_sel),
		.ALU_sel(ALU_sel),
		.ALU_en(ALU_en),
        
        //Outputs for next stage (registered in this module):
        //Simplification: just output the instruction and let stage 2 do the thinking
		.instr_out(instr_out_stage1),
        
        //count number of cycles instruction has been around for
		.PC_en(PC_en),
		.icount(6'b0),
		.ocount(ocount_stage1),
        
        //Handshaking signals
		.prev_vld(from_guv_TVALID),
		.rdy(from_guv_TREADY),
		.next_rdy(rdy_stage2),
		.vld(vld_stage1)
    );
`endgen


    stage2 # (
        .CODE_ADDR_WIDTH(CODE_ADDR_WIDTH)
    ) writeback (
		.clk(clk),
		.rst(rst),

        //Inputs from last stage:
		.instr_in(instr_out_stage1),
        
        //Inputs from outside world streams:
		.din_TVALID(din_TVALID),
		.dout_TREADY(dout_TREADY),
        
        //Inputs from datapath:
		.eq(eq),
		.gt(gt),
		.ge(ge),
		.set(set),
		.last(last),
		.ALU_vld(ALU_vld),
        
        //Outputs for this stage:
		.PC_sel(PC_sel_stage2), //branch_mispredict signifies when to use stage2's PC_sel over stage0's
		.A_sel(A_sel),
		.A_en(A_en),
		.X_sel(X_sel),
		.X_en(X_en),
		.regfile_sel(regfile_sel), //selects A or X as input to register file
		.regfile_wr_en(regfile_wr_en),
		.ALU_ack(ALU_ack),
		.branch_mispredict(branch_mispredict),
		.utility_addr(utility_addr), //Used for setting jmp_off_sel or imm_sel
		.jmp_off_sel_en(jmp_off_sel_en),
		.imm_sel_en(imm_sel_en),
		.last_out(last_out),
		.last_en(last_en),
        
        //Outputs to outside world streams
		.din_TREADY(din_TREADY),
		.dout_TVALID(dout_TVALID),
        
        //Signals for stall logic
		.stage2_writes_A(stage2_writes_A),
		.stage2_writes_X(stage2_writes_X),
		.stage2_writes_imm(stage2_writes_imm),
        
        
        //count number of cycles instruction has been around for
		.PC_en(PC_en),
		.icount(ocount_stage1),
		.jmp_correction(jmp_correction),
        
        //Handshaking signals
		.prev_vld(vld_stage1),
		.rdy(rdy_stage2)
    );

    //Arbitrate PC_sel and regfile_sel
    assign PC_sel = (branch_mispredict) ? PC_sel_stage2 : `PC_SEL_PLUS_1;

endmodule

`undef genif
`undef endgen
