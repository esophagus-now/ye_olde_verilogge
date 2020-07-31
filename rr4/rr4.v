/*
A four-to-one round-robin AXI Stream Switch. 

Parameters:
    DATA_WIDTH - Width of TDATA field
    RESET_TYPE - Set to 0 for no reset, 1 for active-high, 2 for active-low
    PIPE_STAGE - Set to 1 to enable output pipeline registers
    TLAST_ARB  - Set to 1 to only arbitrate on TLAST

To use this in IP Integrator, you might have to concat your sidechannels into 
your TDATA. The axis_tdata_concat core is a nice way to do this

UPDATE July 31 / 2020: 

This module has a combinational path from TVALID to TREADY, whic is of course 
allowed by the AXI spec. Things get a little messy though because all of the 
TREADYs have a combinational path from all the TVALIDs. I think this is still 
technically okay, but the problem is that I use this rr4 module with debug 
guvs, which are combinational all the way. Anyway, I kept getting combinational 
loop errors if the user was trying to debug a design that had combinational 
paths from one stream to another, even if all streams followed the "no path 
from ready to valid" rule.

So, the cleanest solution I could find was to add parameters to the rr4 to 
enable optional pipe stages on the inputs, and to modify the addcore.tcl script 
to use it in the right places.


*/

`ifdef ICARUS_VERILOG
`include "bhand.v" //Make sure to use -I switch in iverilog command
`endif

`include "macros.vh"

module rr4 # (
    parameter DATA_WIDTH = 32,
    parameter PIPE_STAGE = 1,
    parameter RESET_TYPE = `NO_RESET,
    parameter TLAST_ARB = 1,
    parameter S0_PIPE = 0,
    parameter S1_PIPE = 0,
    parameter S2_PIPE = 0,
    parameter S3_PIPE = 0
) (
    input wire clk,
    input wire rst,
    
    //If not arbitrating on TLAST, the TLAST inputs are ignored
    `in_axis_l(s0, DATA_WIDTH),
    `in_axis_l(s1, DATA_WIDTH),
    `in_axis_l(s2, DATA_WIDTH),
    `in_axis_l(s3, DATA_WIDTH),
    
    `out_axis_l(o, DATA_WIDTH)
);

    //State variables used for deciding who gets the grant signal
    reg [3:0] sel_r = 'b0001;
    wire [3:0] sel;
    reg undecided = 1;
    
    ///////////////////////////////////////////
    // Add pipe stage to inputs if requested //
    ///////////////////////////////////////////

    `wire_axis_l(s0_i, DATA_WIDTH);
    `wire_axis_l(s1_i, DATA_WIDTH);
    `wire_axis_l(s2_i, DATA_WIDTH);
    `wire_axis_l(s3_i, DATA_WIDTH);

`genif (S0_PIPE) begin
    bhand # (
        .DATA_WIDTH(DATA_WIDTH + 1), //We're putting the last bit alongside the data
        .RESET_TYPE(RESET_TYPE)
    ) s0_pipe_stage (
        .clk(clk),
        .rst(rst),
        
        .idata({s0_TDATA, s0_TLAST}),
        .idata_vld(s0_TVALID),
        .idata_rdy(s0_TREADY),
        
        .odata({s0_i_TDATA, s0_i_TLAST}),
        .odata_vld(s0_i_TVALID),
        .odata_rdy(s0_i_TREADY)
    );
`else_gen
    assign s0_i_TDATA = s0_TDATA;
    assign s0_i_TVALID = s0_TVALID;
    assign s0_TREADY = s0_i_TREADY;
    assign s0_i_TLAST = s0_TLAST;
`endgen


`genif (S1_PIPE) begin
    bhand # (
        .DATA_WIDTH(DATA_WIDTH + 1), //We're putting the last bit alongside the data
        .RESET_TYPE(RESET_TYPE)
    ) s1_pipe_stage (
        .clk(clk),
        .rst(rst),
        
        .idata({s1_TDATA, s1_TLAST}),
        .idata_vld(s1_TVALID),
        .idata_rdy(s1_TREADY),
        
        .odata({s1_i_TDATA, s1_i_TLAST}),
        .odata_vld(s1_i_TVALID),
        .odata_rdy(s1_i_TREADY)
    );
`else_gen
    assign s1_i_TDATA = s1_TDATA;
    assign s1_i_TVALID = s1_TVALID;
    assign s1_TREADY = s1_i_TREADY;
    assign s1_i_TLAST = s1_TLAST;
`endgen
    
    
`genif (S2_PIPE) begin
    bhand # (
        .DATA_WIDTH(DATA_WIDTH + 1), //We're putting the last bit alongside the data
        .RESET_TYPE(RESET_TYPE)
    ) s2_pipe_stage (
        .clk(clk),
        .rst(rst),
        
        .idata({s2_TDATA, s2_TLAST}),
        .idata_vld(s2_TVALID),
        .idata_rdy(s2_TREADY),
        
        .odata({s2_i_TDATA, s2_i_TLAST}),
        .odata_vld(s2_i_TVALID),
        .odata_rdy(s2_i_TREADY)
    );
`else_gen
    assign s2_i_TDATA = s2_TDATA;
    assign s2_i_TVALID = s2_TVALID;
    assign s2_TREADY = s2_i_TREADY;
    assign s2_i_TLAST = s2_TLAST;
`endgen
    
    
`genif (S3_PIPE) begin
    bhand # (
        .DATA_WIDTH(DATA_WIDTH + 1), //We're putting the last bit alongside the data
        .RESET_TYPE(RESET_TYPE)
    ) s3_pipe_stage (
        .clk(clk),
        .rst(rst),
        
        .idata({s3_TDATA, s3_TLAST}),
        .idata_vld(s3_TVALID),
        .idata_rdy(s3_TREADY),
        
        .odata({s3_i_TDATA, s3_i_TLAST}),
        .odata_vld(s3_i_TVALID),
        .odata_rdy(s3_i_TREADY)
    );
`else_gen
    assign s3_i_TDATA = s3_TDATA;
    assign s3_i_TVALID = s3_TVALID;
    assign s3_TREADY = s3_i_TREADY;
    assign s3_i_TLAST = s3_TLAST;
`endgen

    ////////////////
    //HELPER WIRES//
    ////////////////
    
    wire [3:0] req = {s3_i_TVALID, s2_i_TVALID, s1_i_TVALID, s0_i_TVALID};
    //This technique found in Altera's "Advanced synthesis cookbook"
    wire [3:0] base = {sel_r[2:0], sel_r[3]};
    wire [7:0] req_dbl = {req, req};
    wire [7:0] gnt_dbl = req_dbl & ~(req_dbl - base);
    wire [3:0] gnt = gnt_dbl[7:4] | gnt_dbl[3:0];
    
    //Vivado requires this wire to be forward-declared in order to compile the
    //rest of it, even if it would be perfectly logical
    wire rst_sig;
`genif (RESET_TYPE == `ACTIVE_HIGH) begin
    assign rst_sig = rst;
`else_genif (RESET_TYPE == `ACTIVE_LOW) begin
    assign rst_sig = ~rst;
`endgen

    //////////////
    //MAIN LOGIC//
    //////////////
    
    //Use multiplexer
    `wire_axis_l(muxout, DATA_WIDTH);
    mux4_onehot # (DATA_WIDTH) the_mux (
        sel, 
        `ports_axis_l(s0_i), 
        `ports_axis_l(s1_i),
        `ports_axis_l(s2_i),
        `ports_axis_l(s3_i),
        `ports_axis_l(muxout)
    );
    
    //Update selection (taking care to only arbitrate on TLAST, if that's what
    //was required. There are four cases:
    // Arbitrate on TLAST and no reset
    // Arbitrate on TLAST and reset is active high or active low
    // No TLAST and no reset
    // No TLAST but reset is active high or active low
`genif(TLAST_ARB && RESET_TYPE == `NO_RESET) begin    
    assign sel = undecided ? gnt : sel_r;
    
    always @(posedge clk) begin
        sel_r <= `axis_flit(muxout) ? sel : sel_r;
        undecided <= `axis_flit(muxout) ? (muxout_TLAST ?  1 : 0) : undecided;
    end
`else_genif(TLAST_ARB) begin
    assign sel = undecided ? gnt : sel_r;
    
    always @(posedge clk) begin
        if (rst_sig) begin
            sel_r <= 'b0001;
            undecided <= 1;
        end else begin
            sel_r <= `axis_flit(muxout) ? sel : sel_r;
            undecided <= `axis_flit(muxout) ? (muxout_TLAST ?  1 : 0) : undecided;
        end
    end
`else_genif(RESET_TYPE == `NO_RESET) begin
    assign sel = gnt;
    always @(posedge clk) begin
        sel_r <= `axis_flit(muxout) ? sel : sel_r;
    end
`else_gen 
    assign sel = gnt;
    always @(posedge clk) begin
        if (rst_sig) begin
            sel_r <= 'b0001;
        end else begin
            sel_r <= `axis_flit(muxout) ? sel : sel_r;
        end
    end
`endgen

    //////////////////
    //ASSIGN OUTPUTS//
    //////////////////
    
    //If the pipeline registers are on, we need a bhand
`genif (PIPE_STAGE) begin
    bhand # (
        .DATA_WIDTH(DATA_WIDTH + 1), //Need room for TLAST
        .RESET_TYPE(RESET_TYPE)
    ) sit_shake_good_boy (
        .clk(clk),
        .rst(rst),
        
        .idata({muxout_TDATA, muxout_TLAST}),
        .idata_vld(muxout_TVALID),
        .idata_rdy(muxout_TREADY),
        
        .odata({o_TDATA, o_TLAST}),
        .odata_vld(o_TVALID),
        .odata_rdy(o_TREADY)
    );
`else_gen 
    assign o_TDATA = muxout_TDATA;
    assign o_TVALID = muxout_TVALID;
    assign muxout_TREADY = o_TREADY;
    assign o_TLAST = muxout_TLAST;
`endgen

endmodule


//Combinational
module mux4_onehot # (
    parameter DATA_WIDTH = 32
) (
    input wire [3:0] sel,
    
    `in_axis_l_reg(s0, DATA_WIDTH),
    `in_axis_l_reg(s1, DATA_WIDTH),
    `in_axis_l_reg(s2, DATA_WIDTH),
    `in_axis_l_reg(s3, DATA_WIDTH),
    
    `out_axis_l_reg(o, DATA_WIDTH)
);
    
    wire [1:0] muxsel = {sel[3] | sel[2], sel[3] | sel[1]};
    
    always @(*) begin
        case (muxsel)
        'b00: begin
            o_TDATA <= s0_TDATA;
            o_TVALID <= s0_TVALID;
            o_TLAST <= s0_TLAST;
            s0_TREADY <= o_TREADY;
            s1_TREADY <= 0;
            s2_TREADY <= 0;
            s3_TREADY <= 0;
            end
        'b01: begin
            o_TDATA <= s1_TDATA;
            o_TVALID <= s1_TVALID;
            o_TLAST <= s1_TLAST;
            s0_TREADY <= 0;
            s1_TREADY <= o_TREADY;
            s2_TREADY <= 0;
            s3_TREADY <= 0;
            end
        'b10: begin
            o_TDATA <= s2_TDATA;
            o_TVALID <= s2_TVALID;
            o_TLAST <= s2_TLAST;
            s0_TREADY <= 0;
            s1_TREADY <= 0;
            s2_TREADY <= o_TREADY;
            s3_TREADY <= 0;
            end
        'b11: begin
            o_TDATA <= s3_TDATA;
            o_TVALID <= s3_TVALID;
            o_TLAST <= s3_TLAST;
            s0_TREADY <= 0;
            s1_TREADY <= 0;
            s2_TREADY <= 0;
            s3_TREADY <= o_TREADY;
            end
        endcase
    end
    
endmodule
