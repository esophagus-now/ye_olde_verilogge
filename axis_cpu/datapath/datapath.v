//Copyright 2020 Marco Merlini. This file is part of the fpga-bpf project,
//whose license information can be found at 
//https://github.com/UofT-HPRC/fpga-bpf/blob/master/LICENSE

`timescale 1ns / 1ps

`ifdef ICARUS_VERILOG
`include "axis_cpu_defs.vh"
`endif

module datapath # (
    parameter BYTE_ADDR_WIDTH = 12,
    parameter CODE_ADDR_WIDTH = 10,
    parameter PLEN_WIDTH = 32
) (
    input wire clk,
    input wire rst,
    
    input wire [2:0] A_sel,
    input wire A_en,
    
    input wire [2:0] X_sel,
    input wire X_en,
    
    input wire [1:0] PC_sel,
    input wire PC_en,
    output wire [CODE_ADDR_WIDTH-1:0] inst_rd_addr,
    
    input wire B_sel,
    input wire [3:0] ALU_sel,
    input wire ALU_en,
    output wire eq,
    output wire gt,
    output wire ge,
    output wire set,
    output wire ALU_vld,
    input wire ALU_ack,
    
    input wire [3:0] regfile_sel,
    input wire regfile_wr_en,
    
    input wire [7:0] jt,
    input wire [CODE_ADDR_WIDTH-1:0] jmp_correction
);

    //Registers
    reg [31:0] A = 0;
    reg [31:0] X = 0;
    reg [CODE_ADDR_WIDTH-1:0] PC = 0;

    //Forward-declare wires
    wire [31:0] regfile_idata;
    wire [31:0] regfile_odata;
    wire [31:0] B;
    wire [31:0] ALU_out;
    
    //Accumulator's new value
    always @(posedge clk) begin
        if (A_en == 1'b1) begin
            case (A_sel)
                `A_SEL_IMM:
                    A <= <?>; //Note use of imm_stage2
                `A_SEL_MEM:
                    A <= regfile_odata; 
                `A_SEL_ALU:
                    A <= ALU_out;
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
                    X <= <?>; //Note use of imm_stage2
                `X_SEL_MEM:
                    X <= regfile_odata;
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
                `PC_SEL_PLUS_JT:
                    PC <= PC + jt - jmp_correction; 
                `PC_SEL_PLUS_IMM:
                    PC <= PC + <?> - jmp_correction; //Note use of stage2
            endcase
        end
    end
    assign inst_rd_addr = PC;
    
    //ALU
    assign B = (B_sel == `ALU_B_SEL_IMM) ? <?> : X; //Note use of stage1
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
        .addr(<?>[3:0]), //Note use of imm_stage1
        .idata(regfile_idata),
        .wr_en(regfile_wr_en),
        .odata(regfile_odata)
    );
endmodule
