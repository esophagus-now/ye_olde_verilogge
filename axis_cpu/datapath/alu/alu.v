//Copyright 2020 Marco Merlini. This file is part of the fpga-bpf project,
//whose license information can be found at 
//https://github.com/UofT-HPRC/fpga-bpf/blob/master/LICENSE

`timescale 1ns / 1ps
/*
alu.v
A simple ALU designed to match the needs of the BPF VM. 
*/

`ifdef ICARUS_VERILOG
`include "axis_cpu_defs.vh"
`include "macros.vh"
`endif

module alu # (
	parameter PESS = 0
)(
	input wire clk,
    input wire rst,
    input wire [31:0] A,
    input wire [31:0] B,
    input wire [3:0] ALU_sel,
    input wire ALU_en,
    output wire [31:0] ALU_out,
    output wire set,
    output wire eq,
    output wire gt,
    output wire ge,
    output wire ALU_vld,
    input wire ALU_ack
);
    
    

    
    /************************************/
    /**Forward-declare internal signals**/
    /************************************/
    wire [31:0] A_i;
    wire [31:0] B_i;
    wire [3:0] ALU_sel_i;
    reg  [3:0] ALU_sel_saved;
    wire ALU_en_i;
    
    wire [31:0] ADD_res;
    wire [31:0] SUB_res;
    wire [31:0] AND_res;
    wire [31:0] OR_res;
    wire [31:0] XOR_res;
    wire [31:0] NOT_res;
    wire [31:0] LSH_res;
    wire [31:0] RSH_res;
    
    wire [31:0] MUL_res;
    wire MUL_vld;
    
    wire [31:0] DIV_res;
    wire [31:0] MOD_res;
    wire divmod_vld;
    
    wire eq_i, gt_i, ge_i, set_i;
    wire ALU_vld_i;
    
    
    /****************/
    /**Helper wires**/
    /****************/
    
    wire is_one_cycle_op = ALU_en && (ALU_sel[3] == 0);
    wire is_mul = (ALU_sel_saved == `AXIS_CPU_MUL);
    wire is_div_mod = (ALU_sel_saved > `AXIS_CPU_MUL);
    
    /***************************************/
    /**Assign internal signals from inputs**/
    /***************************************/
    
    assign A_i = A;
    assign B_i = B;
    assign ALU_sel_i = is_one_cycle_op ? ALU_sel : ALU_sel_saved;
    assign ALU_en_i = ALU_en;
    
    
    /****************/
    /**Do the logic**/
    /****************/
    
    
    assign ADD_res = A_i + B_i;
    assign SUB_res = A_i - B_i;
    assign AND_res = A_i & B_i;
    assign  OR_res = A_i | B_i;
    assign XOR_res = A_i ^ B_i;
    assign NOT_res = ~A_i;
    assign LSH_res = A_i << B_i[5:0];
    assign ADD_res = A_i >> B_i[5:0];
    
    always @(*) begin
        case (ALU_sel_i)
        `AXIS_CPU_ADD:
            ALU_out_i <= ADD_res;
        `AXIS_CPU_SUB:
            ALU_out_i <= SUB_res;
        `AXIS_CPU_AND:
            ALU_out_i <= AND_res;
        `AXIS_CPU_OR:
            ALU_out_i <= OR_res;
        `AXIS_CPU_XOR:
            ALU_out_i <= XOR_res;
        `AXIS_CPU_NOT:
            ALU_out_i <= NOT_res;
        `AXIS_CPU_LSH:
            ALU_out_i <= LSH_res;
        `AXIS_CPU_RSH:
            ALU_out_i <= RSH_res;
        `AXIS_CPU_MUL:
            ALU_out_i <= MUL_res;
        `AXIS_CPU_DIV:
            ALU_out_i <= DIV_res;
        `AXIS_CPU_MOD:
            ALU_out_i <= MOD_res;
        default:
            ALU_out_i <= 32'h2BADDEAD;
        endcase
    end


    //These are used as the predicates for JMP instructions
    assign eq_i = (A_i == B_i) ? 1'b1 : 1'b0;
    assign gt_i = (A_i > B_i) ? 1'b1 : 1'b0;
    assign ge_i = gt_i | eq_i;
    assign set_i = ((A_i & B_i) != 32'h00000000) ? 1'b1 : 1'b0;

    assign ALU_vld_i = ALU_en_i;
    
    
    /****************************************/
    /**Assign outputs from internal signals**/
    /****************************************/
    
    reg [31:0] ALU_out_r = 0;
    reg eq_r = 0;
    reg gt_r = 0;
    reg ge_r = 0;
    reg set_r = 0;
    reg ALU_vld_r = 0;
    
    always @(posedge clk) begin
    	if (rst) begin
            ALU_vld_r <= 0;
    	end else begin
			if (ALU_en_i) begin
				ALU_vld_r <= ALU_vld_i;
			end else begin
				ALU_vld_r <= (ALU_ack) ? 0 : ALU_vld_r;
			end
		end
        if (ALU_en_i) begin
            ALU_out_r <= ALU_out_i;
            eq_r <= eq_i;
            gt_r <= gt_i;
            ge_r <= ge_i;
            set_r <= set_i;
        end 
    end
    
    assign ALU_out = ALU_out_r;
    assign eq = eq_r;
    assign gt = gt_r;
    assign ge = ge_r;
    assign set = set_r;
    assign ALU_vld = ALU_vld_r;

endmodule
