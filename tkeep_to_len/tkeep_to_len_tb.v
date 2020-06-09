`timescale 1ns / 1ps

/*
testbench_template.v

Replace innards with desired logic
*/

`include "tkeep_to_len.v"

module tkeep_to_len_tb # (
    parameter TKEEP_WIDTH = 8
);
    reg clk = 0;
    always #5 clk <= ~clk;
    
    reg [TKEEP_WIDTH -1:0] tkeep = 0;
    wire [$clog2(TKEEP_WIDTH) -1:0] len;

    
    initial begin
        $dumpfile("tkeep_to_len.vcd");
        $dumpvars;
        $dumplimit(512000);
        
        #1000
        $finish;
    end
    
    integer i;
    reg [$clog2(TKEEP_WIDTH):0] expected_len = 0;
    always @(posedge clk) begin
        expected_len = expected_len + 1;
        if (expected_len > TKEEP_WIDTH) expected_len = 0;
        for (i = 0; i < TKEEP_WIDTH; i = i + 1) begin
            tkeep[TKEEP_WIDTH -1 - i] <= (i <= expected_len) ? 1'b1 : 1'b0;
        end
    end

    tkeep_to_len # (
       .TKEEP_WIDTH(TKEEP_WIDTH)
    ) DUT (
        .tkeep(tkeep),
        
        .len(len)
    );

endmodule
