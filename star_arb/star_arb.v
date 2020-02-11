`timescale 1ns / 1ps

/*

This module is an implementation of a "star arbiter". This is a sort of "token 
ring" arbiter which should be reasonably fair when daisy-chaining a bunch of 
sources (see associated README file).


*/

`ifdef ICARUS_VERILOG
`define localparam parameter
`else /* For Vivado */
`define localparam localparam
`endif

`ifdef FROM_STAR_ARB
`include "bhand.v" //Wherever it may be. I think you can use -I in iverilog command line?
`endif

`define NO_RESET 0
`define ACTIVE_HIGH 1
`define ACTIVE_LOW 2

`define SEL_SRC 0
`define SEL_PRV 1

`define genif generate if
`define endgen end endgenerate

//TUSER is used to hold the star

module star_arb # (
    parameter DATA_WIDTH = 64,
    parameter RESET_TYPE = `ACTIVE_LOW,
    parameter START_WITH_STAR = 0
) (
    input wire clk,
    input wire rst,
    input wire rstn,
    
    //Input AXI Stream
    input wire [DATA_WIDTH -1:0] src_TDATA,
    input wire src_TVALID,
    output wire src_TREADY,
    input wire src_TLAST,
    input wire src_TUSER,
    
    //Chained AXI Stream
    input wire [DATA_WIDTH -1:0] prv_TDATA,
    input wire prv_TVALID,
    output wire prv_TREADY,
    input wire prv_TLAST,
    input wire prv_TUSER,
    
    //Output AXI Stream
    output wire [DATA_WIDTH -1:0] res_TDATA,
    output wire res_TVALID,
    input wire res_TREADY,
    output wire res_TLAST,
    output wire res_TUSER
);
    //Invariant for whole system of daisy-chained star_arbs: the star is always 
    //in EXACTLY one location
    //
    //Rule 1: We take the star when we see it on an incoming TLAST flit from prv
    //
    //Rule 2: If we have the star, we must give it to the TLAST flit from src
    //
    //Rule 3: If we have the star, and prv and src are both ready, we must 
    //        select src
    //
    //Rule 4: If we do not have the star, and prv and src are both ready, we 
    //        must select prv
    //
    //Rule 5: Whether or not we have the star, if only one of prv or src is 
    //        ready, we must select the ready stream
    //
    //Rule 6: We may not change our selection until we see TLAST on our 
    //        selected stream
    
    
    //Helper wires to clean up the code
    wire src_flit = src_TVALID && src_TREADY;
    wire src_last = src_flit && src_TLAST; 
    
    wire prv_flit = prv_TVALID && prv_TREADY;
    wire prv_last = prv_flit && prv_TLAST; 
    
    //Our decision is volatile on the cycle after a TLAST, and until the 
    //selected flit is read in by this module. This is for Rule 6
    reg undecided = 1;
    
`genif (RESET_TYPE == `NO_RESET) begin
    always @(posedge clk) begin
        if (sel == `SEL_SRC) begin
            undecided <= src_flit ? (src_TLAST : 1 : 0) : undecided;
        end else begin 
            undecided <= prv_flit ? (prv_TLAST : 1 : 0) : undecided;
        end
    end
`endgen
    
    reg star = START_WITH_STAR;
    
    //sel is combinational in several different inputs and sel_r.
    //sel_r is sel but delayed by one cycle
    wire sel;
    reg sel_r = `SEL_PRV;
    
    always @(*) begin
        if (undecided) begin //This "undecided" stuff implements Rule 6
            sel <= sel_r;
        end else begin
            sel <= ~prv_TVALID || (src_TVALID && star); //Rules 3, 4, and 5
    end

`genif (RESET_TYPE == `NO_RESET) begin
    always @(posedge clk) begin
        sel_r <= sel;
        
        
        //We will have the star on the next cycle in two cases:
        // 1) We had it before and don't give it away
        // 2) It's being given to us
        
        star <= (star && !((sel == `SEL_SRC) && src_last)  //Case 1
                || (prev_last && prev_TUSER);              //Case 2
        //This implements Rule 1 and Rule 2
    end
`endgen
    
    //Assign correct AXI Stream signals
    wire [DATA_WIDTH -1:0] comb_TDATA;
    wire comb_TVALID;
    wire comb_TREADY; //Output from bhand
    wire comb_TLAST;
    wire comb_TUSER;
    
    assign comb_TDATA = (sel == `SEL_SRC) ? src_TDATA : prv_TDATA;
    assign comb_TVALID = (sel == `SEL_SRC) ? src_TVALID : prv_TVALID;
    assign comb_TREADY = (sel == `SEL_SRC) ? src_TREADY : prv_TREADY;
    assign comb_TLAST = (sel == `SEL_SRC) ? src_TLAST : prv_TLAST;
    assign comb_TUSER = (sel == `SEL_SRC) && star && comb_TLAST; //Rule 2
    
    //Apply bhand

`genif (RESET_TYPE == `NO_RESET) begin
    bhand # (
        .DATA_WIDTH(DATA_WIDTH + 1 + 1) //TDATA + TLAST + TUSER
    ) (
        .clk(clk),
        .rst(0),
        
        .idata({comb_TDATA, comb_TLAST, comb_TUSER}),
        .idata_vld(comb_TVALID),
        .idata_rdy(comb_TREADY),
        
        .odata({res_TDATA, res_TLAST, res_TUSER}),
        .odata_vld(res_TVALID),
        .odata_rdy(res_TREADY)
    );
`endgen

    //Assign last remaining outputs (src_TREADY and prv_TREADY)
    assign src_TREADY = (sel == `SEL_SRC) && comb_TREADY;
    assign prv_TREADY = (sel == `PRV_SRC) && comb_TREADY;
    
endmodule

`undef NO_RESET
`undef ACTIVE_HIGH
`undef ACTIVE_LOW

`undef SEL_SRC
`undef SEL_PRV

`undef genif
`undef endgen
