/* 
A simple module to convert TKEEP encoding to a byte count. Note that the
output of this module is computed as (popcount(TKEEP) - 1). This takes
advantage of the fact that we disallow a TKEEP of 0 in order to reduce the
number of necessary bits.

This code assumes that there are no gaps between asserted TKEEP bits, and
that the TKEEP signal is "big-endian". In other words, 

TKEEP value     Comments
11011000        Invalid; gaps not allowed
11111000        Valid
00011111        Invalid; TKEEP is not left-aligned
00110011        Invalid; gaps and not left-aligned

*/

`include "macros.vh"
`define MAX(x,y) (((x)>(y))?(x):(y))

module tkeep_to_len # (
    parameter TKEEP_WIDTH = 8
) (
    input wire [TKEEP_WIDTH - 1:0] tkeep,
    
    output wire [`MAX($clog2(TKEEP_WIDTH),1) -1:0] len
);
    
    //Special cases for small TKEEP_WIDTH
`genif (TKEEP_WIDTH == 1) begin
    assign len = 0;
`else_genif( TKEEP_WIDTH == 2) begin
    assign len = tkeep[0];
`else_gen
    
    //This Verilog code is essentially a generic binary encoder
	localparam NUM_LEVELS = $clog2(TKEEP_WIDTH);

    //Pad TKEEP on the right with zeroes
	wire [2**NUM_LEVELS -1:0] tkeep_padded;
	localparam PAD_WIDTH = 2**NUM_LEVELS - TKEEP_WIDTH;
    if (PAD_WIDTH > 0) begin
        assign tkeep_padded = {tkeep, {PAD_WIDTH{1'b0}}};
    end else begin
        assign tkeep_padded = tkeep;
    end
    
    
    //Wire which stores the one-hot encoding of where the last TKEEP bit
    //is situated. This is "right-aligned".
	wire [2**NUM_LEVELS -1 -1:0] one_hot;
    
    //Use XORs between adjacent bits to find last set bit
	assign one_hot[0] = tkeep_padded[0];
    genvar i;
	for (i = 1; i < 2**NUM_LEVELS - 1; i = i + 1) begin
		assign one_hot[i] = tkeep_padded[i] ^ tkeep_padded[i - 1];
	end
    
    //Subsets of bits which have a '0' in a particular position of their 
    //index. Specifically, subsets[i] is the concatenation of
    //
    //  {one_hot[j] | the (NUM_LEVELS)-bit binary representation of j has a 
    //                zero in bit i}
    //
    //(hopefully that's clear)
	wire [2**(NUM_LEVELS-1) -1:0]subsets[NUM_LEVELS -1:0];
	genvar level;
	for (level = 0; level < NUM_LEVELS; level = level + 1) begin
        //The idea is we will now sweep out the set of indices that have a
        //one in bit LEVEL of their index. 
		for (i = 0; i < 2**(NUM_LEVELS - 1); i = i + 1) begin
			wire [NUM_LEVELS - 1 -1:0] other_bits = i;
            `define left_bits ((NUM_LEVELS -1) - level)
            `define right_bits (level)
            
            wire [NUM_LEVELS -1:0] idx;
            if (`right_bits > 0) begin
                if (`left_bits > 0) begin
                    assign idx = {
                        other_bits[NUM_LEVELS -1 -1 -: `left_bits],
                        1'b0,
                        other_bits[`right_bits -1 -: `right_bits]
                    };
                end else begin
                    assign idx = {
                        1'b0,
                        other_bits[`right_bits -1 -: `right_bits]
                    };
                end
            end else begin
                //Assume it's impossible for both to be zero
                assign idx = {
                    other_bits[NUM_LEVELS -1 -1 -: `left_bits],
                    1'b0
                };
            end
            
            `undef left_bits
            `undef right_bits
            assign subsets[level][i] = one_hot[idx];
		end
	end
    
    //Finally, take the OR-reduction of the subsets to get the length value
    for (i = 0; i < NUM_LEVELS; i = i + 1) begin
        assign len[i] = |subsets[i];
    end
`endgen

endmodule

`undef MAX
