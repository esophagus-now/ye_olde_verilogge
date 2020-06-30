//Copyright 2020 Marco Merlini. This file is part of the fpga-bpf project,
//whose license information can be found at 
//https://github.com/UofT-HPRC/fpga-bpf/blob/master/LICENSE

`timescale 1ns / 1ps
/*
alu.v
A simple ALU designed to match the needs of the AXIS CPU. 
*/

`ifdef ICARUS_VERILOG
`default_nettype none
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
    
    wire [3:0] ALU_sel_i;
    reg  [3:0] ALU_sel_saved = 0;
    reg ALU_en_r[0:4]; //Shift register for ALU_en_r
        initial ALU_en_r[0] = 0;
        initial ALU_en_r[1] = 0;
        initial ALU_en_r[2] = 0;
        initial ALU_en_r[3] = 0;
        initial ALU_en_r[4] = 0;
    
    wire [31:0] ADD_res;
    wire [31:0] SUB_res;
    wire [31:0] AND_res;
    wire [31:0] OR_res;
    wire [31:0] XOR_res;
    wire [31:0] NOT_res;
    wire [31:0] LSH_res;
    wire [31:0] RSH_res;
    wire one_cycle_op_vld = ALU_en_r[0];
    
    wire [63:0] MUL_res;
    wire MUL_vld = ALU_en_r[4]; //Multiplies take a lot of cycles...
    
    wire [31:0] DIV_res;
    wire [31:0] MOD_res;
    wire divmod_vld; //...but not nearly as many as divisions!
    
    wire eq_i, gt_i, ge_i, set_i;
    `logic [31:0] ALU_out_i;
    wire ALU_vld_i;
    
    
    /****************/
    /**Helper wires**/
    /****************/
    
    wire is_one_cycle_op = ALU_en && (ALU_sel[3] == 0);
    wire ALU_sel_saved_is_one_cycle_op = (ALU_sel_saved[3] == 0);
    wire is_mul = (ALU_sel_saved == `AXIS_CPU_MUL);
    wire is_div_mod = (ALU_sel_saved > `AXIS_CPU_MUL);
    
    /****************/
    /**Do the logic**/
    /****************/
    
    //We use ALU_en delayed by 4 to get MUL_vld
    always @(posedge clk) begin
        if(rst) begin
            ALU_en_r[0] <= 0;
        end else begin
            ALU_en_r[0] <= ALU_en;
        end
    end
    genvar i;
    for (i = 1; i < 5; i = i + 1) begin
        always @(posedge clk) begin
            if (rst) begin
                ALU_en_r[i] <= 0;
            end else begin
                ALU_en_r[i] <= ALU_en_r[i - 1];
            end
        end
    end
    
    always @(posedge clk) begin
        if (ALU_en) begin
            ALU_sel_saved <= ALU_sel;
        end
    end
    
    assign ALU_sel_i = is_one_cycle_op ? ALU_sel : ALU_sel_saved;  
    
    mult_unsigned # (32,32) mult (clk, A, B, MUL_res);
    
    divmod divider (
		.clk(clk),
		.rst(rst),
        
		.A(A),
		.B(B),
		.start(ALU_en),
        
		.div(DIV_res),
		.mod(MOD_res),
		.res_vld(divmod_vld)
    );
    
    assign ADD_res = A + B;
    assign SUB_res = A - B;
    assign AND_res = A & B;
    assign  OR_res = A | B;
    assign XOR_res = A ^ B;
    assign NOT_res = ~A;
    assign LSH_res = A << B[5:0];
    assign RSH_res = A >> B[5:0];
    
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
            ALU_out_i <= MUL_res[31:0];
        `AXIS_CPU_DIV:
            ALU_out_i <= DIV_res;
        `AXIS_CPU_MOD:
            ALU_out_i <= MOD_res;
        default:
            ALU_out_i <= 32'h2BADDEAD;
        endcase
    end

    //These are used as the predicates for JMP instructions
    assign eq_i = (A == B) ? 1'b1 : 1'b0;
    assign gt_i = (A > B) ? 1'b1 : 1'b0;
    assign ge_i = gt_i | eq_i;
    assign set_i = ((A & B) != 32'h00000000) ? 1'b1 : 1'b0;

    assign ALU_vld_i = is_one_cycle_op | (is_mul ? MUL_vld : is_div_mod && divmod_vld);
    
    
    /****************************************/
    /**Assign outputs from internal signals**/
    /****************************************/
    
    reg [31:0] ALU_out_r = 0;
    reg ALU_vld_r = 0;
    reg eq_r = 0;
    reg gt_r = 0;
    reg ge_r = 0;
    reg set_r = 0;
    
    always @(posedge clk) begin
        if (ALU_vld_i) begin
            ALU_out_r <= ALU_out_i;
        end
    end
    
    always @(posedge clk) begin
    	if (rst) begin
            ALU_vld_r <= 0;
    	end else begin
            ALU_vld_r <= ALU_vld_i | ((ALU_ack) ? 0 : ALU_vld_r);
		end
        if (ALU_vld_i) begin
            ALU_out_r <= ALU_out_i;
        end 
        if (ALU_en) begin
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

//Quick-n-dirty divmod 
module divmod(
    input wire clk,
    input wire rst,
    
    input wire [31:0] A,
    input wire [31:0] B,
    input wire start,
    
    output wire [31:0] div,
    output wire [31:0] mod,
    output wire res_vld
);
    
    reg [31:0] mod_r = 0;
    reg [31:0] div_r = 0;
    
    reg [62:0] div_shifted = 0;
    wire upper_zeroes = !(|div_shifted[62:32]); //Not really efficient, but who cares?
    wire [31:0] subtrahend = div_shifted[31:0];
    
    wire do_subtract = upper_zeroes && (mod_r > subtrahend);
    
    reg [4:0] cycles_left = 0;
    //Pulses on the cycle when the outputs are ready
    reg calc_done = 0;
    
    always @(posedge clk) begin
        if (rst) begin
            cycles_left <= 0;
            calc_done <= 0;
        end else begin
            calc_done <= (cycles_left == 1);
            if (start) begin
                cycles_left <= 'd31;
                div_shifted <= {B, {31{1'b0}}};
                mod_r <= A;
                div_r <= 0;
            end else if(cycles_left != 0) begin
                div_r <= {div_r[30:0], do_subtract};
                div_shifted <= {1'b0, div_shifted[62:1]};
                if (do_subtract) begin
                    mod_r <= mod_r - subtrahend;
                end
                if (cycles_left > 0) begin
                    cycles_left <= cycles_left - 1;
                end
            end
        end
    end
    
    assign div = div_r;
    assign mod = mod_r;
    assign res_vld = calc_done;

endmodule


//Taken from UG901 Vivado Synthesis User Guide (2018.3)
//It looks ugly because the example code doesn't have
//great indentation, and because I copied out of a PDF
// Unsigned 16x24-bit Multiplier
// 1 latency stage on operands
// 4 latency stages after the multiplication
// File: mult_unsigned.v
//
module mult_unsigned (clk, A, B, RES);
parameter WIDTHA = 16;
parameter WIDTHB = 24;
input clk;
input [WIDTHA-1:0] A;
input [WIDTHB-1:0] B;
output [WIDTHA+WIDTHB-1:0] RES;
reg [WIDTHA-1:0] rA;
reg [WIDTHB-1:0] rB;
reg [WIDTHA+WIDTHB-1:0] M [3:0];
integer i;
always @(posedge clk)
 begin
 rA <= A;
 rB <= B;
 M[0] <= rA * rB;
 for (i = 0; i < 3; i = i+1)
 M[i+1] <= M[i];
 end
assign RES = M[3];
endmodule


