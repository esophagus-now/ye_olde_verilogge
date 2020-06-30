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

`define stringify(x) `"x`"

`define mktest(x) \
if (x != x``_exp) begin\
    $display("%t ps, variable x: expected %h but got %h", $time, x``_exp, x);\
    #5 $finish;\
end\
dummy = 1

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
    
    integer fd, dummy;
    
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
        
        fd = $fopen("alu_drivers.mem", "r");
        if (fd == 0) begin
            $display("Could not open drivers file");
            $finish;
        end
        
        //Skip first line of comments
        while ($fgetc(fd) != "\n") begin
            if ($feof(fd)) begin
                $display("Error: drivers file is in incorrect format");
                $finish;
            end
        end
    end
    
    always #5 clk <= ~clk;
    
    always @(posedge clk) begin
        if ($feof(fd)) begin
            $display("Reached end of drivers file");
            #20
            $finish;
        end
        
        //Check expected values against sim values
        `mktest(ALU_out);
        `mktest(ALU_vld);
        `mktest(set);
        `mktest(eq);
        `mktest(gt);
        `mktest(ge);
        
        #0.01
        dummy = $fscanf(fd, "%d%d%b%b%b%d%b%b%b%b%b", 
            A, B, ALU_sel, ALU_en, ALU_ack,
            ALU_out_exp, ALU_vld_exp, set_exp, eq_exp, gt_exp, ge_exp
        );
        
        //Skip comments at end of line
        while (!$feof(fd) && $fgetc(fd) != "\n") ;
    end

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
