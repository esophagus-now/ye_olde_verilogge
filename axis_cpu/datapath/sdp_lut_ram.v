//From Vivado Synthesis User Guide UG901 2018.3
//But I hated the original coding style so much I cleaned it up to my usual
//standard and added parameters. I have tested this in Vivado to make sure
//it synthesizes to LUTRAM for the following parameters:
//
// DATA_WIDTH = 32, ADDR_WIDTH = 4, Uses 24 LUTs
// DATA_WIDTH = 32, ADDR_WIDTH = 6, Uses 40 LUTs
//
// Simple Dual-Port RAM with Asynchronous Read (Distributed RAM)
module sdp_lut_ram #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 4
)(
    input wire clk, 
    input wire wr_en, 
    input wire [ADDR_WIDTH -1:0] rd_addr, 
    input wire [ADDR_WIDTH -1:0] wr_addr, 
    input wire [DATA_WIDTH -1:0] din,
    output wire [DATA_WIDTH -1:0] rd_data_out
);
    reg [DATA_WIDTH-1:0] ram [0:2**(ADDR_WIDTH)-1];
    
    genvar i;
    for (i = 0; i < 2**ADDR_WIDTH; i = i + 1) begin
        initial ram[i] <= 0;
    end
    
    always @(posedge clk) begin
        if (wr_en)
        ram[wr_addr] <= din;
    end
    
    assign rd_data_out = ram[rd_addr];
endmodule
