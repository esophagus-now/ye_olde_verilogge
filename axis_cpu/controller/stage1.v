//Copyright 2020 Marco Merlini. This file is part of the fpga-bpf project,
//whose license information can be found at 
//https://github.com/UofT-HPRC/fpga-bpf/blob/master/LICENSE

`timescale 1ns / 1ps

/*

stage1.v

Implements the decode stage. Also responsible for a few datapath signals:
        - B_sel, ALU_sel, ALU_en
        - din_TREADY
        - utility_addr, jmp_off_sel_en, imm_sel_en
    
This is the most complicated stage, since it must also deal with buffered 
handshaking.

Note: the outputs of a stage are combinational on the inputs. All the "hot" bus 
signals (such as write enables) are only asserted on the single cycle when 
valid and ready are high (on the input side).

TODO: 
[ ] Support for stream input operation and correct stalling
[ ] Edit stage2_reads_A and stage2_reads_X to handle stream output
[ ] New instructions for setting imm_sel and jmp_offset_sel

*/

`ifdef ICARUS_VERILOG
`include "axis_cpu_defs.vh"
`include "macros.vh"
`include "bhand_cycle_count.v"
`default_nettype none
`endif

module stage1 (
    input wire clk,
    input wire rst,
    
    input wire [7:0] instr_in,
    input wire branch_mispredict,
    
    //Signals for stall logic
    input wire stage2_writes_A,
    input wire stage2_writes_X,
    
    //Outputs from this stage:
    output wire B_sel,
    output wire [3:0] ALU_sel,
    output wire ALU_en,
    output wire rd_en,
    output wire [3:0] utility_addr, //Used for setting jmp_off_sel or imm_sel
    output wire jmp_off_sel_en,
    output wire imm_sel_en,
    
    //Outputs for next stage (registered in this module):
    //Simplification: just output the instruction and let stage 2 do the thinking
    output wire [7:0] instr_out,
    
    //count number of cycles instruction has been around for
    input wire PC_en,
    input wire [5:0] icount,
    output wire [5:0] ocount,
    
    //Handshaking signals
    input wire prev_vld,
    output wire rdy,
    input wire next_rdy,
    output wire vld
);
    
    /************************************/
    /**Forward-declare internal signals**/
    /************************************/
    
    wire stalled_i;
    
    wire [7:0] instr_in_i;
    wire branch_mispredict_i;
    
    wire B_sel_i;
    wire [3:0] ALU_sel_i;
    wire ALU_en_i;
    wire regfile_sel_i;
    wire regfile_wr_en_i;
    wire [3:0] utility_addr_i;
    
    wire [7:0] instr_out_i;
    
    wire PC_en_i;
    
    wire [5:0] icount_i;
    wire [5:0] ocount_i;
    
    wire prev_vld_i;
    wire rdy_i;
    wire next_rdy_i;
    wire vld_i;
    
    
    /***************************************/
    /**Assign internal signals from inputs**/
    /***************************************/
    
    assign instr_in_i = instr_in;
    assign branch_mispredict_i = branch_mispredict;
    
    assign PC_en_i = PC_en;
    assign icount_i = icount;
    
    assign prev_vld_i = prev_vld;
    assign next_rdy_i = next_rdy;
    
    
    /************************************/
    /**Helpful names for neatening code**/
    /************************************/
    
    wire [2:0] jmp_type = instr_in[2:0];
    
    //Helper booleans
    wire is_lda = (instr_in[7:5] == `AXIS_CPU_LD);
    wire is_ldx = (instr_in[7:5] == `AXIS_CPU_LDX);
    wire is_sta = (instr_in[7:5] == `AXIS_CPU_ST);
    wire is_stx = (instr_in[7:5] == `AXIS_CPU_STX);
    wire is_alu = (instr_in[7:5] == `AXIS_CPU_ALU);
    wire is_jmp = (instr_in[7:5] == `AXIS_CPU_JMP);
    wire is_tax = (instr_in[7:4] == `AXIS_CPU_TAX);
    wire is_txa = (instr_in[7:4] == `AXIS_CPU_TXA);
    wire is_set_jmp = (instr_in[7:4] == `AXIS_CPU_SET_JMP_OFF);
    wire is_set_imm = (instr_in[7:4] == `AXIS_CPU_SET_IMM);
    
    wire alu_b_sel_x = instr_in[4]; //1 for X, 0 for IMM
    wire jmp_cmp_x = instr_in[4]; //1 for X, 0 for IMM
    
    //For determining when we are stalled
    wire we_read_A; 
    assign we_read_A = is_alu || is_jmp;
    wire we_read_X;
    assign we_read_X = (is_alu && alu_b_sel_x) || (is_jmp && jmp_cmp_x);
    
    //Some instructions don't need to make it into stage 2
    wire early_exit = (is_set_jmp || is_set_imm);
    
    /****************/
    /**Do the logic**/
    /****************/
    
    assign B_sel_i = instr_in[4];
    
    assign ALU_sel_i = instr_in[3:0];
    assign ALU_en_i = is_alu || (is_jmp && jmp_type != `AXIS_CPU_JA);
    
    assign utility_addr_i = instr_in[3:0];
    
    //Stall signals
    assign stalled_i = 
                        (we_read_A && stage2_writes_A)
                      ||(we_read_X && stage2_writes_X)
                      || !rdy_i;
    
    //This performs the buffered handshaking
    bhand_cycle_count # (
        .DATA_WIDTH(8),
        .ENABLE_COUNT(1),
        .COUNT_WIDTH(6)
    ) handshaker (
        .clk(clk),
        .rst(rst || branch_mispredict_i),
            
        .idata(instr_in_i),
        .idata_vld(prev_vld_i && !stalled_i), //ugly hack (see right below)
        .idata_rdy(rdy_i),
            
        .odata(instr_out_i),
        .odata_vld(vld_i),
        .odata_rdy(next_rdy_i),
        
        .cnt_en(PC_en_i),
        .icount(icount_i),
        .ocount(ocount_i)
    );
    
    //When this stage is stalled, it does not read the next instruction. I 
    //already gated the rdy output (see assigning outputs from internal signals)
    //but I didn't realize I would also need to tell the handshaking module to
    //also not read the input. The quick and dirty way to prevent the handshaker
    //from reading the input is to gate its valid input. At some point I might
    //just add a shift_in_enable and a shift_out_enable to the handshaker.
    
    
    /****************************************/
    /**Assign outputs from internal signals**/
    /****************************************/
    
    //This stage's control bus outputs
    //Note that "hot" control signals are gated with prev_vld and rdy and not stalled
    wire enable_hot;
    assign enable_hot = prev_vld && rdy && !stalled_i && !rst;
    
    assign B_sel              = B_sel_i;
    assign ALU_sel            = ALU_sel_i;
    assign ALU_en             = ALU_en_i && enable_hot;
    assign utility_addr       = utility_addr_i;
    
    assign instr_out = instr_out_i;
    
    assign ocount = ocount_i;
    
    //Handshaking signals
    //We are not ready if we are stalled
    assign vld = vld_i;
    assign rdy = rdy_i && !stalled_i;

endmodule
