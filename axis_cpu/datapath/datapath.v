//Copyright 2020 Marco Merlini. This file is part of the fpga-bpf project,
//whose license information can be found at 
//https://github.com/UofT-HPRC/fpga-bpf/blob/master/LICENSE

`timescale 1ns / 1ps

`ifdef ICARUS_VERILOG
`include "macros.vh"
`include "axis_cpu_defs.vh"
`include "alu.v"
`include "regfile.v"
`include "sdp_lut_ram.v"
`include "inst_mem.v"
`default_nettype none
`endif

module datapath # (
    parameter CODE_ADDR_WIDTH = 10
) (
    input wire clk,
    input wire rst,
    
    //Signals for instruction memory
    input wire inst_rd_en,
    output wire [7:0] instr,
    
    //Inputs for A register
    input wire [2:0] A_sel,
    input wire A_en,
    
    //Inputs for X register
    input wire [2:0] X_sel,
    input wire X_en,
    
    //Signals for PC register
    input wire [1:0] PC_sel,
    input wire PC_en,
    
    //Signals to/from ALU
    input wire B_sel,
    input wire [3:0] ALU_sel,
    input wire ALU_en,
    output wire eq,
    output wire gt,
    output wire ge,
    output wire set,
    output wire ALU_vld,
    input wire ALU_ack,
    
    //Signals to/from external streams
    input wire [31:0] din_TDATA,
    input wire din_TLAST,
    output wire [31:0] dout_TDATA,
    output wire dout_TLAST,
    
    //Signals to from controller for dealing with last
    input wire last_en,
    input wire last_out, //Seems kind of silly to take this as input only to
                         //to turn around and put in on dout_TLAST
    output wire last,
    
    //The bottom four bits of an instruction, used for addressing the reg
    //file, jmp table, or imm table
    input wire [3:0] utility_addr,
    
    //Signals for reading/writing register file
    input wire regfile_sel, //Selects A or X as input to the register file (HACK: also selects A or X for stream out)
    input wire regfile_wr_en,
    
    //Signals for imm_sel register
    input wire imm_sel_en,
    //These are for reprogramming the immediates table
    input wire [31:0] imm_wr_data,
    input wire [3:0] imm_wr_addr,
    input wire imm_wr_en,
    
    //Signals for jmp_off_sel register
    input wire jmp_off_sel_en,
    //These are for reprogramming the jump offsets table
    input wire [7:0] jmp_off_wr_data,
    input wire [3:0] jmp_off_wr_addr,
    input wire jmp_off_wr_en,
    
    //Signals for writing new instructions
    input wire [CODE_ADDR_WIDTH -1:0] inst_mem_wr_addr,
    input wire [7:0] inst_mem_wr_data,
    input wire inst_mem_wr_en,
    
    //This is my little hack for dealing with the effects of pipelining.
    //Basically, the jump offsets are relative to the jump instruction 
    //itself, but we may have already started working on the next instructions
    input wire [CODE_ADDR_WIDTH -1:0] jmp_correction,
    
    //Debug signals
    output wire [79:0] to_guv_TDATA
);

    //Registers
    reg [31:0] A = 0;
    reg [31:0] X = 0;
    reg [CODE_ADDR_WIDTH-1:0] PC = 0;
    reg [3:0] jmp_off_sel_r = 0;
    reg [3:0] imm_sel_r = 0;
    
    reg last_r = 0;
    
    //Forward-declare wires
    wire [31:0] regfile_idata;
    wire [31:0] regfile_odata;
    wire [31:0] B;
    wire [31:0] ALU_out;
    wire [31:0] imm;
    wire [CODE_ADDR_WIDTH -1:0] jmp_off;
    
    //Accumulator's new value
    always @(posedge clk) begin
        if (A_en == 1'b1) begin
            case (A_sel)
                `A_SEL_IMM:
                    A <= imm;
                `A_SEL_MEM:
                    A <= regfile_odata; 
                `A_SEL_ALU:
                    A <= ALU_out;
                `A_SEL_STREAM: //For INA instruction
                    A <= din_TDATA;
                `A_SEL_X: //for TXA instruction
                    A <= X;
            endcase
        end
    end

    //Auxiliary (X) register's new value
    always @(posedge clk) begin
        if (X_en == 1'b1) begin
            case (X_sel)
                `X_SEL_IMM:
                    X <= imm; 
                `X_SEL_MEM:
                    X <= regfile_odata;
                `X_SEL_STREAM: //For INX instruction
                    A <= din_TDATA;
                `X_SEL_A: //for TAX instruction
                    X <= A;
                default:
                    X <= 0; //Does this even make sense?
            endcase
        end
    end
    
    //Program Counter (PC) register's new value
    //jt, jf, and imm (as per the BPF standard) are interpreted as offsets from
    //the NEXT instruction
    always @(posedge clk) begin
        if (rst) PC <= 0;
        else if (PC_en == 1'b1) begin
            case (PC_sel)
                `PC_SEL_PLUS_1:
                    PC <= PC + 1;
                `PC_SEL_PLUS_IMM:
                    PC <= PC + jmp_off - jmp_correction; 
            endcase
        end
    end
    
    //ALU
    assign B = (B_sel == `ALU_B_SEL_IMM) ? imm : X; 
    alu the_alu (
        .clk(clk),
        .rst(rst),
        .A(A),
        .B(B),
        .ALU_sel(ALU_sel),
        .ALU_en(ALU_en),
        .ALU_out(ALU_out),
        .set(set),
        .eq(eq),
        .gt(gt),
        .ge(ge),
        .ALU_vld(ALU_vld),
        .ALU_ack(ALU_ack)
    );
    
    //Register file
    assign regfile_idata = (regfile_sel == `REGFILE_IN_A) ? A : X;
    regfile scratch_mem (
        .clk(clk),
        .rst(rst),
        .addr(utility_addr),
        .idata(regfile_idata),
        .wr_en(regfile_wr_en),
        .odata(regfile_odata)
    );
    
    //Stream out
    //HACK: use regfile_idata for dout_TDATA
    assign dout_TDATA = regfile_idata;
    
    //last signals
    always @(posedge clk) begin
        if (rst) begin
            last_r <= 0;
        end else begin
            if (last_en)
                last_r <= din_TLAST;
        end
    end
    assign last = last_r;
    assign dout_TLAST = last_out;
    
    //Jump offset table
    always @(posedge clk) begin
        if (jmp_off_sel_en) 
            jmp_off_sel_r <= utility_addr;
    end
    
    wire [7:0] jmp_off_unextended;
    localparam SIGN_BITS = CODE_ADDR_WIDTH - 8;
    
    sdp_lut_ram #(
        .DATA_WIDTH(8),
        .ADDR_WIDTH(4)
    ) jmp_table (
		.clk(clk), 
		.wr_en(jmp_off_wr_en), 
		.rd_addr(jmp_off_sel_r), 
		.wr_addr(jmp_off_wr_addr), 
		.din(jmp_off_wr_data),
		.rd_data_out(jmp_off_unextended)
    );
    
`genif(SIGN_BITS <= 0) begin
    assign jmp_off = jmp_off_unextended[CODE_ADDR_WIDTH -1:0];
`else_gen 
    assign jmp_off = {{SIGN_BITS{1'b1}}, jmp_off_unextended};
`endgen
    
    //Immediate table
    always @(posedge clk) begin
        if (imm_sel_en) 
            imm_sel_r <= utility_addr;
    end
    
    sdp_lut_ram #(
        .DATA_WIDTH(32),
        .ADDR_WIDTH(4)
    ) imm_table (
		.clk(clk), 
		.wr_en(imm_wr_en), 
		.rd_addr(imm_sel_r), 
		.wr_addr(imm_wr_addr), 
		.din(imm_wr_data),
		.rd_data_out(imm)
    );
    
    //Instruction memory
    inst_mem # (
        .ADDR_WIDTH(CODE_ADDR_WIDTH),
        .DATA_WIDTH(8)
    ) insts (
		.clk(clk),
		.wr_addr(inst_mem_wr_addr),
		.wr_data(inst_mem_wr_data),
		.wr_en(inst_mem_wr_en),
		.rd_addr(PC),
		.rd_data(instr),
		.rd_en(inst_rd_en)
    );
    
    //Debug signals
    assign to_guv_TDATA = {A, X, jmp_off_sel_r, imm_sel_r, instr};
endmodule
