//Copyright 2020 Marco Merlini. This file is part of the fpga-bpf project,
//whose license information can be found at 
//https://github.com/UofT-HPRC/fpga-bpf/blob/master/LICENSE

`timescale 1ns / 1ps

/*

stage2.v

Implements the writeback stage. Can assert the branch_mispredict signal. 
Depending on the opcode, this stage may wait for a valid signal on the memory 
or ALU.

This stage also takes care of decrementing jump offsets (see the README in
this folder)

Even though the packet memory and ALU are all pipelined with an II of 1, I 
didn't feel the need to take advantage of it here; at any given moment, only 
one instruction can be waiting for the ALU or memory. This really simplifies 
the logic I have to write, and anyway, how often would a BPF program really 
benefit from pipelined ALU/memory? Let's remember that I only added pipelining 
for timing, not for performance.


Hmmmm, I forgot that stage1 and stage2 also fight over the scratch memory 
too... need to be careful for that. I think if stage2 outputs an extra bit to 
say when it is trying to use the regfile_sel bits, we should be ok. 

I'm not sure if it's correct to gate hot signals with prev_vld && rdy. 
Intuitively it makes sense, but I think I'll have to see the sim outputs to 
understand it for myself.

*/

`ifdef ICARUS_VERILOG
`include "axis_cpu_defs.vh"
`include "macros.vh"
`default_nettype none
`endif

module stage2 # (
    parameter CODE_ADDR_WIDTH = 10
) (
    input wire clk,
    input wire rst,

    //Inputs from last stage:
    input wire [7:0] instr_in,
    
    //Inputs from outside world streams:
    input wire din_TVALID,
    input wire dout_TREADY,
    
    //Inputs from datapath:
    input wire eq,
    input wire gt,
    input wire ge,
    input wire set,
    input wire last,
    input wire ALU_vld,
    
    //Outputs for this stage:
    output wire [1:0] PC_sel, //branch_mispredict signifies when to use stage2's PC_sel over stage0's
    output wire [2:0] A_sel,
    output wire A_en,
    output wire [2:0] X_sel,
    output wire X_en,
    output wire regfile_sel, //selects A or X as input to register file
    output wire [3:0] regfile_wr_addr,
    output wire regfile_wr_en,
    output wire ALU_ack,
    output wire branch_mispredict,
    output wire [3:0] utility_addr, //Used for setting jmp_off_sel or imm_sel
    output wire jmp_off_sel_en,
    output wire imm_sel_en,
    output wire last_out,
    output wire last_en,
    
    //Outputs to outside world streams
    output wire din_TREADY,
    output wire dout_TVALID,
    
    //Signals for stall logic
    output wire stage2_writes_A,
    output wire stage2_writes_X,
    output wire stage2_writes_imm,
    
    
    //count number of cycles instruction has been around for
    input wire PC_en,
    input wire [5:0] icount,
    output wire [CODE_ADDR_WIDTH-1:0] jmp_correction,
    
    //Handshaking signals
    input wire prev_vld,
    output wire rdy
);
    
    /************************************/
    /**Forward-declare internal signals**/
    /************************************/
    
    //Inputs from datapath:
    wire mem_vld_i;
    wire eq_i;
    wire gt_i;
    wire ge_i;
    wire set_i;
    wire ALU_vld_i;
    
    //Outputs for this stage:
    wire [1:0] PC_sel_i; //branch_mispredict signifies when to use stage2's PC_sel over stage0's
    `logic [2:0] A_sel_i;
    `logic A_en_i;
    `logic [2:0] X_sel_i;
    `logic X_en_i;
    wire regfile_sel_i; //Selects A or X for writing to regfile
    wire regfile_wr_en_i;
    wire ALU_ack_i;
    wire branch_mispredict_i;
    wire [3:0] utility_addr_i; //Used for setting registers, jmp_off_sel, or imm_sel
    wire jmp_off_sel_en_i;
    wire imm_sel_en_i;
    wire last_out_i;
    wire last_en_i;
    wire last_i;
    
    //Stall signals
    wire stage2_writes_A_i;
    wire stage2_writes_X_i;
    wire stage2_writes_imm_i;
    
    //count number of cycles instruction has been around for
    wire PC_en_i;
    wire [CODE_ADDR_WIDTH-1:0] jmp_correction_i;
    
    
    /***************************************/
    /**Assign internal signals from inputs**/
    /***************************************/
    
    //count_i has special rules: see logic section
    
    //Inputs from datapath:
    assign eq_i       = eq;
    assign gt_i       = gt;
    assign ge_i       = ge;
    assign set_i      = set;
    assign last_i     = last;
    assign ALU_vld_i  = ALU_vld;
    
    assign PC_en_i = PC_en;
    
    
    /************************************/
    /**Helpful names for neatening code**/
    /************************************/
    
    wire [2:0] jmp_type = instr_in[2:0];
    wire [2:0] addr_type = instr_in[2:0];
    
    //Helper booleans
    wire is_lda = (instr_in[7:5] == `AXIS_CPU_LD);
    wire is_ldx = (instr_in[7:5] == `AXIS_CPU_LDX);
    wire is_sta = (instr_in[7:5] == `AXIS_CPU_ST);
    wire is_stx = (instr_in[7:5] == `AXIS_CPU_STX);
    wire is_alu = (instr_in[7:5] == `AXIS_CPU_ALU);
    wire is_jmp = (instr_in[7:5] == `AXIS_CPU_JMP);
    wire is_cond_jmp = is_jmp && (jmp_type != `AXIS_CPU_JA);
    wire is_tax = (instr_in[7:4] == `AXIS_CPU_TAX);
    wire is_txa = (instr_in[7:4] == `AXIS_CPU_TXA);
    wire is_set_jmp = (instr_in[7:4] == `AXIS_CPU_SET_JMP_OFF);
    wire is_set_imm = (instr_in[7:4] == `AXIS_CPU_SET_IMM);
    wire is_outa = is_sta && (instr_in[4] == `AXIS_CPU_ST_STREAM);
    wire is_outx = is_stx && (instr_in[4] == `AXIS_CPU_ST_STREAM);
    
    wire alu_b_sel_x = instr_in[4]; //1 for X, 0 for IMM
    wire jmp_cmp_x = instr_in[4]; //1 for X, 0 for IMM
    
    //If we are awaiting streams or ALU
    wire awaiting_ALU = is_alu || (is_jmp && jmp_type != `AXIS_CPU_JA);
    wire awaiting_in = (is_lda || is_ldx) && (addr_type == `AXIS_CPU_STREAM);
    wire awaiting_out = (is_outa || is_outx);
    
    //If a jump should be taken
    wire jump_taken = 
        (jmp_type == `AXIS_CPU_JA) ||
        (jmp_type == `AXIS_CPU_JEQ && eq_i) ||
        (jmp_type == `AXIS_CPU_JGT && gt_i) ||
        (jmp_type == `AXIS_CPU_JGE && ge_i) ||
        (jmp_type == `AXIS_CPU_JSET && set_i) ||
        (jmp_type == `AXIS_CPU_JLAST && last_i)
    ;
    
    /****************/
    /**Do the logic**/
    /****************/
    
    //regfile_sel_i, regfilewr_addr_i, and regfile_wr_en_i
    assign regfile_sel_i = (is_stx) ? `REGFILE_IN_X : `REGFILE_IN_A;
    assign regfile_wr_en_i = (is_sta || is_stx);
    
    //rdy
    //this stage is always ready unless it is an ALU or memory access instruction.
    assign rdy = !(awaiting_ALU && !ALU_vld_i) && 
                 !(awaiting_in && !din_TVALID) &&
                 !(awaiting_out && !dout_TREADY)
    ;
    
    //PC_sel_i and branch_mispredict_i
    assign PC_sel_i = (prev_vld && is_jmp && jump_taken) ? `PC_SEL_PLUS_IMM : `PC_SEL_PLUS_1;
    assign branch_mispredict_i = (prev_vld && is_jmp && jump_taken);
    
    //A_sel_i and A_en_i
    always @(*) begin
        if (is_lda) begin
            A_en_i <= 1;
            case (addr_type)
                `AXIS_CPU_IMM:
                    A_sel_i <= `A_SEL_IMM;
                `AXIS_CPU_STREAM:
                    A_sel_i <= `A_SEL_STREAM;
                `AXIS_CPU_MEM:
                    A_sel_i <= `A_SEL_MEM;
                default:
                    A_sel_i <= 0; //Error
            endcase
        end else if (is_alu) begin
            A_en_i <= 1;
            A_sel_i <= `A_SEL_ALU;
        end else if (is_txa) begin
            A_en_i <= 1;
            A_sel_i <= `A_SEL_X;
        end else begin
            A_en_i <= 0;
            A_sel_i <= 0; //Don't synthesize a latch
        end
    end
    
    //X_sel_i and X_en_i
    always @(*) begin
        if (is_ldx) begin
            X_en_i <= 1;
            case (addr_type)
                `AXIS_CPU_IMM:
                    X_sel_i <= `X_SEL_IMM;
                `AXIS_CPU_STREAM:
                    X_sel_i <= `X_SEL_STREAM;
                `AXIS_CPU_MEM:
                    X_sel_i <= `X_SEL_MEM;
                default:
                    X_sel_i <= 0; //Error
            endcase
        end else if (is_tax) begin 
            X_en_i <= 1;
            X_sel_i <= `X_SEL_A;
        end else begin
            X_en_i <= 0;
            X_sel_i <= 0; //Don't synthesize a latch
        end
    end
    
    //regfile_sel_i
    assign regfile_sel_i = instr_in[3:0];
    
    //ALU_ack_i
    assign ALU_ack_i = (awaiting_ALU && ALU_vld_i);
    
    //Setting jump offset or immediate offset
    assign utility_addr_i = instr_in[3:0];
    assign imm_sel_en_i = is_set_imm;
    assign jmp_off_sel_en_i = is_set_jmp;
    
    //last signals
    assign last_out_i = instr_in[0]; //Get output TLAST from LSB of instruction
    assign last_en_i = awaiting_in; //Quick and dirty! Just keep overwriting
                                    //last_r (in the datapath) until the flit
                                    //actually goes through
    
    //jmp_correction_i
`genif (CODE_ADDR_WIDTH > 6) begin
    assign jmp_correction_i = $signed(icount);
end else begin
    assign jmp_correction_i = icount;
`endgen
    
    //Stall signals
    assign stage2_writes_A_i = A_en_i;
    assign stage2_writes_X_i = X_en_i;
    assign stage2_writes_imm_i = imm_sel_en_i;
    
    /****************************************/
    /**Assign outputs from internal signals**/
    /****************************************/
    
    //Note that "hot" control signals are gated with prev_vld and rdy
    wire enable_hot;
    assign enable_hot = prev_vld && rdy && !rst;
    
    //Outputs for this stage:
    assign PC_sel             = PC_sel_i;
    assign A_sel              = A_sel_i;
    assign A_en               = A_en_i && enable_hot;
    assign X_sel              = X_sel_i;
    assign X_en               = X_en_i && enable_hot;
    assign regfile_sel        = regfile_sel_i;
    assign regfile_wr_en      = regfile_wr_en_i;
    assign ALU_ack            = ALU_ack_i && enable_hot;
    assign branch_mispredict  = branch_mispredict_i && enable_hot;
    assign utility_addr       = utility_addr_i;
    assign imm_sel_en         = imm_sel_en_i && enable_hot;
    assign jmp_off_sel_en     = jmp_off_sel_en_i && enable_hot;
    assign last_en            = last_en_i && enable_hot;
    assign last_out           = last_out_i;
    
    assign jmp_correction = jmp_correction_i;
    
    //Note that stall signals are gated with prev_vld. This is because they are
    //computed combinationally from the output of the last stage.
    //Stall signals
    assign stage2_writes_A = stage2_writes_A_i && prev_vld;
    assign stage2_writes_X = stage2_writes_X_i && prev_vld;
    assign stage2_writes_imm = stage2_writes_imm_i && prev_vld;
    
endmodule
