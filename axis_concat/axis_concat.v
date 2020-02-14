/*

In almost all my Verilog cores, it's a major pain in the rear end to keep 
adding separate side-channels for TKEEP, TDEST, TID, etc. Normally I fold all 
these into TDATA, but you can't do this cleanly in IP Integrator.

Well, with this module, you can! I only take care of this messy logic once.  
And anyway, I'd like my cores to have conditional side channels anyway.

In the end, this module is noting more than wires, but it tricks Vivado into 
doing what I want

Anyway, each side channel has an "in enable" and an "out enable". This means:

in | out | Meaning
------------------------------------
 0 |  d  | The side channel is not present at the input
 1 |  0  | The side channel is concatenated into output TDATA
 1 |  0  | The side channel is present at input, but not concatenated

*/

/*

If you use this in another Verilog core and "pass up" the parameters to your 
top-level core, add these TCL lines to your IP packaging script:

*/

`include "macros.vh"

/*

Unfortunately, due to problems with Vivado, I have to move all the 
automatically derived parameters into macros instead of using localparam

Specifically, this happens because you can't use localparam to set a module's 
port width, even if you use the K&R-style Verilog syntax:

    module my_thing # (
        parameter W = 2
    ) (a, b);
    localparam WW = W+W;
    input wire [W -1:0] a;
    output wire [WW -1:0] b;
    
    endmodule

Vivado chokes on it.

So there is no choice but to use ugly `define statements... and to make things
worse, you can't do 
    x ? 1 : 0
Vivado only understands
    (x != 0) ? 1 : 0
*/

//Derived parameters. Do not set manually!
//
//The "CONCAT_*_WIDTH" parameters mean how many additional bits are added
//into the output TDATA
//
//The "SAFE_*_WIDTH" parameters are an ugly hack. See, if I just did 
//something like
//  input wire [DEST_WIDTH - 1 :0]
//but DEST_WIDTH was 0, then we would get a Verilog error. Although I plan
//to have the packaged IP hide the ability to edit the width if you disable
//the port, I don't want obscure errors if the user typed in 0 before 
//disabling. 
//
//The "PASSTHRU_*" indicate that a side channel shouldnot be concatted with 
//TDATA; instead, it is given its own output
//
`define CONCAT_LAST (((IN_ENABLE_LAST != 0) && (OUT_ENABLE_LAST == 0)) ? 1 : 0)
`define CONCAT_KEEP (((IN_ENABLE_KEEP != 0) && (OUT_ENABLE_KEEP == 0)) ? 1 : 0)
`define CONCAT_DEST (((IN_ENABLE_DEST != 0) && (OUT_ENABLE_DEST == 0)) ? 1 : 0)
`define CONCAT_ID (((IN_ENABLE_ID != 0) && (OUT_ENABLE_ID == 0)) ? 1 : 0)
`define CONCAT_USER (((IN_ENABLE_USER != 0) && (OUT_ENABLE_USER == 0)) ? 1 : 0)

`define CONCAT_LAST_WIDTH (`CONCAT_LAST) //For consistency

`define KEEP_WIDTH ((DATA_WIDTH+7)/8)
`define CONCAT_KEEP_WIDTH (`CONCAT_KEEP * `KEEP_WIDTH)
`define IN_SAFE_KEEP_WIDTH ((IN_ENABLE_KEEP != 0) ? `KEEP_WIDTH : 1)
`define OUT_SAFE_KEEP_WIDTH ((OUT_ENABLE_KEEP != 0) ? `KEEP_WIDTH : 1)

`define CONCAT_DEST_WIDTH (`CONCAT_DEST * DEST_WIDTH)
`define IN_SAFE_DEST_WIDTH ((IN_ENABLE_DEST != 0) ? DEST_WIDTH : 1)
`define OUT_SAFE_DEST_WIDTH ((OUT_ENABLE_DEST != 0) ? DEST_WIDTH : 1)

`define CONCAT_ID_WIDTH (`CONCAT_ID * ID_WIDTH)
`define IN_SAFE_ID_WIDTH ((IN_ENABLE_ID != 0) ? ID_WIDTH : 1)
`define OUT_SAFE_ID_WIDTH ((OUT_ENABLE_ID != 0) ? ID_WIDTH : 1)

`define CONCAT_USER_WIDTH (`CONCAT_USER * USER_WIDTH)
`define IN_SAFE_USER_WIDTH ((IN_ENABLE_USER != 0) ? USER_WIDTH : 1)
`define OUT_SAFE_USER_WIDTH ((OUT_ENABLE_USER != 0) ? USER_WIDTH : 1)


`define PASSTHRU_LAST (((IN_ENABLE_LAST != 0) && (OUT_ENABLE_LAST != 0)) ? 1 : 0)
`define PASSTHRU_KEEP (((IN_ENABLE_KEEP != 0) && (OUT_ENABLE_KEEP != 0)) ? 1 : 0)
`define PASSTHRU_DEST (((IN_ENABLE_DEST != 0) && (OUT_ENABLE_DEST != 0)) ? 1 : 0)
`define PASSTHRU_ID (((IN_ENABLE_ID != 0) && (OUT_ENABLE_ID != 0)) ? 1 : 0)
`define PASSTHRU_USER (((IN_ENABLE_USER != 0) && (OUT_ENABLE_USER != 0)) ? 1 : 0)

module axis_concat # (
    parameter DATA_WIDTH = 32,
    
    parameter IN_ENABLE_KEEP = 0,
    parameter OUT_ENABLE_KEEP = 0,
    
    parameter IN_ENABLE_LAST = 1,
    parameter OUT_ENABLE_LAST = 1,
    
    parameter IN_ENABLE_DEST = 0,
    parameter OUT_ENABLE_DEST = 0,
    parameter DEST_WIDTH = 16,
    
    parameter IN_ENABLE_ID = 0,
    parameter OUT_ENABLE_ID = 0,
    parameter ID_WIDTH = 16,
    
    parameter IN_ENABLE_USER = 0,
    parameter OUT_ENABLE_USER = 0,
    parameter USER_WIDTH = 16
) (
    input wire clk, //Dummy clock to get rid of Vivado's annoying warning
    
    input wire [DATA_WIDTH -1:0] left_TDATA,
    input wire left_TVALID,
    output wire left_TREADY,
    input wire left_TLAST,
    input wire [`IN_SAFE_KEEP_WIDTH -1:0] left_TKEEP,
    input wire [`IN_SAFE_DEST_WIDTH -1:0] left_TDEST,
    input wire [`IN_SAFE_ID_WIDTH -1:0] left_TID,
    input wire [`IN_SAFE_USER_WIDTH -1:0] left_TUSER,
    
    output wire [DATA_WIDTH
                 + `CONCAT_LAST_WIDTH
                 + `CONCAT_KEEP_WIDTH
                 + `CONCAT_DEST_WIDTH
                 + `CONCAT_ID_WIDTH
                 + `CONCAT_USER_WIDTH
                 -1:0] right_TDATA,
    output wire right_TVALID,
    input wire right_TREADY,
    output wire right_TLAST,
    output wire [`OUT_SAFE_KEEP_WIDTH -1:0] right_TKEEP,
    output wire [`OUT_SAFE_DEST_WIDTH -1:0] right_TDEST,
    output wire [`OUT_SAFE_ID_WIDTH -1:0] right_TID,
    output wire [`OUT_SAFE_USER_WIDTH -1:0] right_TUSER
);

wire [DATA_WIDTH 
      + `CONCAT_LAST_WIDTH 
      -1:0] tmp_dl;

wire [DATA_WIDTH 
      + `CONCAT_LAST_WIDTH 
      + `CONCAT_KEEP_WIDTH
      -1:0] tmp_dlk;

wire [DATA_WIDTH 
      + `CONCAT_LAST_WIDTH 
      + `CONCAT_KEEP_WIDTH
      + `CONCAT_DEST_WIDTH
      -1:0] tmp_dlkd;

wire [DATA_WIDTH 
      + `CONCAT_LAST_WIDTH 
      + `CONCAT_KEEP_WIDTH
      + `CONCAT_DEST_WIDTH
      + `CONCAT_ID_WIDTH
      -1:0] tmp_dlkdi;

wire [DATA_WIDTH 
      + `CONCAT_LAST_WIDTH 
      + `CONCAT_KEEP_WIDTH
      + `CONCAT_DEST_WIDTH
      + `CONCAT_ID_WIDTH
      + `CONCAT_USER_WIDTH
      -1:0] tmp_dlkdiu;

`genif (`CONCAT_LAST) begin
    assign tmp_dl = {left_TDATA, left_TLAST};
`else_gen
    assign tmp_dl = left_TDATA;
`endgen


`genif (`CONCAT_KEEP) begin
    assign tmp_dlk = {tmp_dl, left_TKEEP};
`else_gen
    assign tmp_dlk = tmp_dl;
`endgen


`genif (`CONCAT_DEST) begin
    assign tmp_dlkd = {tmp_dlk, left_TDEST};
`else_gen
    assign tmp_dlkd = tmp_dlk;
`endgen


`genif (`CONCAT_ID) begin
    assign tmp_dlkdi = {tmp_dlkd, left_TID};
`else_gen
    assign tmp_dlkdi = tmp_dlkd;
`endgen


`genif (`CONCAT_USER) begin
    assign tmp_dlkdiu = {tmp_dlkdi, left_TUSER};
`else_gen
    assign tmp_dlkdiu = tmp_dlkdi;
`endgen

assign right_TDATA = tmp_dlkdiu;
assign right_TVALID = left_TVALID;
assign left_TREADY = right_TREADY;

`genif (`PASSTHRU_LAST) begin
    assign right_TLAST = left_TLAST;
`endgen

`genif (`PASSTHRU_KEEP) begin
    assign right_TKEEP = left_TKEEP;
`endgen

`genif (`PASSTHRU_DEST) begin
    assign right_TDEST = left_TDEST;
`endgen

`genif (`PASSTHRU_ID) begin
    assign right_TID = left_TID;
`endgen

`genif (`PASSTHRU_USER) begin
    assign right_TUSER = left_TUSER;
`endgen




endmodule

