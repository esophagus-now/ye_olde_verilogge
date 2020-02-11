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

//Reset types.
`define NO_RESET 0
`define ACTIVE_HIGH 1
`define ACTIVE_LOW 2

//

//If selections are backwards, I'll just swap these constants' values
`define SEL_PRV 0
`define SEL_SRC 1

//Some may disagree, but I think this helps me read the code. It becomes much
//easier to visually distinguish generate blocks from regular ones
`define genif generate if
`define else_genif end else if
`define endgen end endgenerate

`define logic reg

module star_arb # (
    parameter DATA_WIDTH = 64,
    parameter RESET_TYPE = `ACTIVE_LOW,
    parameter START_WITH_STAR = 0
) (
    input wire clk,
    input wire rst,
    
    //This is how the star passed between arbiters
    output wire give_star,
    input wire take_star,
    
    //Input AXI Stream
    input wire [DATA_WIDTH -1:0] src_TDATA,
    input wire src_TVALID,
    output wire src_TREADY,
    input wire src_TLAST,
    
    //Chained AXI Stream
    input wire [DATA_WIDTH -1:0] prv_TDATA,
    input wire prv_TVALID,
    output wire prv_TREADY,
    input wire prv_TLAST,
    
    //Output AXI Stream
    output wire [DATA_WIDTH -1:0] res_TDATA,
    output wire res_TVALID,
    input wire res_TREADY,
    output wire res_TLAST
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
    
    //Forward-declare wires/registers if necessary
    `logic sel; //Selected input stream
    
    //*****************
    //* STAR HANDLING *
    //***************** 
    reg star = START_WITH_STAR;  
     
    //Ladies and gentlement, please prepare your passports, we are now entering
    //kludge city
    reg can_drop = 1'b1;
    
    wire drop_star; //Not to be confused with give_star; this signal means we
    //should "attach" the star to the flit; the give_star output is only 
    //triggered once the flit leaves the bhand at the end of this module 
    assign drop_star = /*can_drop && */ (prv_last || src_last);
    
`genif (RESET_TYPE == `NO_RESET) begin

    always @(posedge clk) begin
        //We will have the star on the next cycle in two cases:
        // 1) We had it before and don't give it away
        // 2) It's being given to us
        //This implements Rule 1 and Rule 2
        star <= (star && ~drop_star) || take_star;
        
        //Also, manage the can_drop FSM
        case (can_drop)
        1'b0:
            can_drop <= ((sel == `SEL_SRC) && src_last) || ((sel == `SEL_PRV) && prv_last);
        1'b1:
            can_drop <= ~take_star;
        endcase
    end
    
`else_genif (RESET_TYPE == `ACTIVE_HIGH) begin

    always @(posedge clk) begin
        if (rst) begin
            star <= START_WITH_STAR;
            can_drop <= 1'b1;
        end else begin
            star <= (star && ~drop_star) || take_star;
                    
            case (can_drop)
            1'b0:
                can_drop <= ((sel == `SEL_SRC) && src_last) || ((sel == `SEL_PRV) && prv_last);
            1'b1:
                can_drop <= ~take_star;
            endcase
        end
    end
    
`else_genif (RESET_TYPE == `ACTIVE_LOW) begin

    always @(posedge clk) begin
        if (!rst) begin
            star <= START_WITH_STAR;
            can_drop <= 1'b1;
        end else begin
            star <= (star && ~drop_star) || take_star;
            
            case (can_drop)
            1'b0:
                can_drop <= ((sel == `SEL_SRC) && src_last) || ((sel == `SEL_PRV) && prv_last);
            1'b1:
                can_drop <= ~take_star;
            endcase
        end
    end
    
`endgen
    
    
    //**********************
    //* SELECTION DECISION *
    //**********************
    
    //Our decision is volatile on the cycle after a TLAST, and until the 
    //selected flit is read in by this module. This is for Rule 6
    reg undecided = 1;
    
    //sel is combinational in several different inputs and sel_r.
    //(It is forward-declared at the top of this module)
    //wire sel;
    
    //sel_r is sel delayed by one cycle
    reg sel_r = `SEL_PRV;
    
    //HUGE KLUDGE AHEAD!
    //If START_WITH_STAR is 1, we know that this is the second-last arbiter,
    //and that it is safe to enforce even distribution
    
    always @(*) begin
        if (undecided) begin 
            sel <= ~prv_TVALID || (src_TVALID && star); //Rules 3, 4, and 5
        end else begin 
            sel <= sel_r; //This case implements Rule 6
        end
    end
    
`genif (RESET_TYPE == `NO_RESET) begin

    always @(posedge clk) begin
        sel_r <= sel;
        if (sel == `SEL_SRC) begin
            undecided <= src_flit ? (src_TLAST ? 1 : 0) : undecided;
        end else begin 
            undecided <= prv_flit ? (prv_TLAST ? 1 : 0) : undecided;
        end
    end
    
`else_genif (RESET_TYPE == `ACTIVE_HIGH) begin

    always @(posedge clk) begin
        if (rst) begin
            sel_r <= `SEL_PRV;
            undecided <= 1;
        end else begin
            sel_r <= sel;
            if (sel == `SEL_SRC) begin
                undecided <= src_flit ? (src_TLAST ? 1 : 0) : undecided;
            end else begin 
                undecided <= prv_flit ? (prv_TLAST ? 1 : 0) : undecided;
            end
        end
    end
    
`else_genif (RESET_TYPE == `ACTIVE_LOW) begin

    always @(posedge clk) begin
        if (!rst) begin
            sel_r <= `SEL_PRV;
            undecided <= 1;
        end else begin
            sel_r <= sel;
            if (sel == `SEL_SRC) begin
                undecided <= src_flit ? (src_TLAST ? 1 : 0) : undecided;
            end else begin 
                undecided <= prv_flit ? (prv_TLAST ? 1 : 0) : undecided;
            end
        end
    end
    
`endgen
    
    //************************
    //* BUFFERED HANDSHAKING *
    //************************
    
    //Assign correct AXI Stream signals
    wire [DATA_WIDTH -1:0] comb_TDATA;
    wire comb_TVALID;
    wire comb_TREADY; //Output from bhand
    wire comb_TLAST;
    wire comb_TSTAR; //Is the star attached to this flit?
    
    assign comb_TDATA = (sel == `SEL_SRC) ? src_TDATA : prv_TDATA;
    assign comb_TVALID = (sel == `SEL_SRC) ? src_TVALID : prv_TVALID;
    assign comb_TLAST = (sel == `SEL_SRC) ? src_TLAST : prv_TLAST;
    assign comb_TSTAR = star && drop_star; //We give the star away if we had it
                                           //and if we're dropping it

    wire res_TSTAR; //Really annoying kludge: we have to gate give_star with
    //res_TVALID and res_TREADY to prevent double reads
    
    //Apply bhand

    bhand # (
        .DATA_WIDTH(DATA_WIDTH + 1 + 1), //TDATA + TLAST + "TSTAR"
        .RESET_TYPE(RESET_TYPE)
    ) sit_shake_good_boy (
        .clk(clk),
        .rst(rst),
        
        .idata({comb_TDATA, comb_TLAST, comb_TSTAR}),
        .idata_vld(comb_TVALID),
        .idata_rdy(comb_TREADY),
        
        .odata({res_TDATA, res_TLAST, res_TSTAR}),
        .odata_vld(res_TVALID),
        .odata_rdy(res_TREADY)
    );
    
    //*******************
    //* LAST FEW THINGS *
    //*******************
    
    //Assign last remaining outputs (src_TREADY and prv_TREADY)
    assign src_TREADY = (sel == `SEL_SRC) && comb_TREADY;
    assign prv_TREADY = (sel == `SEL_PRV) && comb_TREADY;
    
    assign give_star = res_TSTAR && res_TVALID && res_TREADY;
    
endmodule

`undef NO_RESET
`undef ACTIVE_HIGH
`undef ACTIVE_LOW

`undef SEL_SRC
`undef SEL_PRV

`undef genif
`undef else_genif
`undef endgen

`undef logic
