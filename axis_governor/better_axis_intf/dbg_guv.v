`timescale 1ns / 1ps

/*

This wraps around axis_governor.v, and is what will get put into your block 
diagram when you use the automatic TCL scripts provided along with these cores. 
Please forgive the messy organization; it's unclear how to organize things 
until they're all finished.

*/

`include "macros.vh"

 `ifdef ICARUS_VERILOG
`include "axis_governor.v"
`endif

module dbg_guv # (
    parameter DATA_WIDTH = 32,
    parameter DEST_WIDTH = 16,
    parameter ID_WIDTH = 16,
    parameter CNT_SIZE = 16
) (
    //Input command stream
    //This may be a bad decision, but I decided the command width should match
    //the inject data width.
    //How does this work if you have a bunch of streams of different sizes that
    //you want to debug? Also, what about the rr_tree in that case?
    `in_axis(cmd, DATA_WIDTH),
    
    //Also,since this module is intended to wrap around axis_governor, we need
    //to provide access to its ports through this one. (I didn't use the macros
    //because it was easier to copy-paste the wires I already had in 
    //axis_governor.v)
    
    //Input AXI Stream.
    input wire [DATA_WIDTH-1:0] in_TDATA,
    input wire in_TVALID,
    output wire in_TREADY,
    input wire [DATA_WIDTH/8 -1:0] in_TKEEP,
    input wire [DEST_WIDTH -1:0] in_TDEST,
    input wire [ID_WIDTH -1:0] in_TID,
    input wire in_TLAST,
    
    //Output AXI Stream.
    output wire [DATA_WIDTH-1:0] out_TDATA,
    output wire out_TVALID,
    input wire out_TREADY,
    output wire [DATA_WIDTH/8 -1:0] out_TKEEP,
    output wire [DEST_WIDTH -1:0] out_TDEST,
    output wire [ID_WIDTH -1:0] out_TID,
    output wire out_TLAST,
    
    //Log AXI Stream. 
    //This core takes care of concatting the sidechannels into the data part
    //of the flit
    `out_axis_l(log_catted, DATA_WIDTH + DATA_WIDTH/8 + 1 + DEST_WIDTH + ID_WIDTH)
);
    //Forward-declare internal wires/registers    
    //Governor control wires
    wire pause;
    wire drop;
    wire log_en;
    
    `wire_axis_kl(log, DATA_WIDTH);
    wire [DEST_WIDTH -1:0] log_TDEST;
    wire [ID_WIDTH -1:0] log_TID;
    
    //State registers
    reg [CNT_SIZE -1:0] drop_cnt = 0;       //Address = 0
    reg [CNT_SIZE -1:0] log_cnt = 0;        //Address = 1
    reg [DATA_WIDTH -1:0] inj_TDATA = 0;    //Address = 2
    reg inj_TVALID = 0;                     //Address = 3
    reg inj_TLAST = 0;                      //Address = 4
    reg [DATA_WIDTH/8 -1:0] inj_TKEEP = 0;  //Address = 5
    reg [DEST_WIDTH -1:0] inj_TDEST = 0;    //Address = 6
    reg [ID_WIDTH -1:0] inj_TID = 0;        //Address = 7
    wire inj_TREADY; //I might use this for something?

    //Do easy stuff first
    axis_governor #(
		.DATA_WIDTH(DATA_WIDTH),
		.DEST_WIDTH(DEST_WIDTH),
		.ID_WIDTH(ID_WIDTH)
    ) ello_guvna (    
		.clk(clk),
        
        //Input AXI Stream.
		.in_TDATA(in_TDATA),
		.in_TVALID(in_TVALID),
		.in_TREADY(in_TREADY),
		.in_TKEEP(in_TKEEP),
		.in_TDEST(in_TDEST),
		.in_TID(in_TID),
		.in_TLAST(in_TLAST),
        
        //Inject AXI Stream. 
		.inj_TDATA(inj_TDATA),
		.inj_TVALID(inj_TVALID),
		.inj_TREADY(inj_TREADY),
		.inj_TKEEP(inj_TKEEP),
		.inj_TDEST(inj_TDEST),
		.inj_TID(inj_TID),
		.inj_TLAST(inj_TLAST),
        
        //Output AXI Stream.
		.out_TDATA(out_TDATA),
		.out_TVALID(out_TVALID),
		.out_TREADY(out_TREADY),
		.out_TKEEP(out_TKEEP),
		.out_TDEST(out_TDEST),
		.out_TID(out_TID),
		.out_TLAST(out_TLAST),
        
        //Log AXI Stream. 
		.log_TDATA(log_TDATA),
		.log_TVALID(log_TVALID),
		.log_TREADY(log_TREADY),
		.log_TKEEP(log_TKEEP),
		.log_TDEST(log_TDEST),
		.log_TID(log_TID),
		.log_TLAST(log_TLAST),
        
        //Control signals
		.pause(pause),
		.drop(drop),
		.log_en(log_en)
    );    
endmodule
