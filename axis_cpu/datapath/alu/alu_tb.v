//Copyright 2020 Marco Merlini. This file modified from the fpga-bpf project,
//whose license information can be found at 
//https://github.com/UofT-HPRC/fpga-bpf/blob/master/LICENSE

`timescale 1ns / 1ps

/*
alu_tb.v

A testbench for alu.v
*/

`include "alu.v"
`include "axis_cpu_defs.vh"
`include "macros.vh"

`define stringify(x) `"x`"

module alu_tb;
	reg clk;
    reg [31:0] A;
    reg [31:0] B;
    reg [3:0] ALU_sel;
    reg ALU_en;
    wire [31:0] ALU_out;
    wire set;
    wire eq;
    wire gt;
    wire ge;
    wire ALU_vld;
    reg ALU_ack;
    
    //Wires for storing expected outputs
    reg [31:0] ALU_out_exp = 0;
    reg set_exp = 0;
    reg eq_exp = 0;
    reg gt_exp = 0;
    reg ge_exp = 0;
    reg ALU_vld_exp = 0;
    
    `auto_tb_decls;
    
    initial begin
        $dumpfile("alu.vcd");
        $dumpvars;
        $dumplimit(512000);
        
        clk <= 0;
        A <= 0;
        B <= 0;
        ALU_sel <= 0;
        ALU_en <= 0;
        ALU_ack <= 0;
        
        `open_drivers_file("alu_drivers.mem");
    end
    
    always #5 clk <= ~clk;
    
    `auto_tb_read_loop(clk)
        `dummy = $fscanf(`fd, "%d%d%b%b%b%d%b%b%b%b%b", 
            A, B, ALU_sel, ALU_en, ALU_ack,
            ALU_out_exp, ALU_vld_exp, set_exp, eq_exp, gt_exp, ge_exp
        );
    `auto_tb_read_end
    
    `auto_tb_test_loop(clk)
        //Check expected values against sim values
        `test(ALU_out,ALU_out_exp);
        `test(ALU_vld,ALU_vld_exp);
        `test(set,set_exp);
        `test(eq,eq_exp);
        `test(gt,gt_exp);
        `test(ge,ge_exp);
    `auto_tb_test_end
    
    alu DUT (
        .clk(clk),
        .rst(1'b0),
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


endmodule
