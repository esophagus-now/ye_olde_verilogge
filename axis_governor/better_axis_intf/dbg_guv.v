`timescale 1ns / 1ps

/*

This wraps around axis_governor.v, and is what will get put into your block 
diagram when you use the automatic TCL scripts provided along with these cores. 
Please forgive the messy organization; it's unclear how to organize things 
until they're all finished.

*/

 `ifdef ICARUS_VERILOG
`include "axis_governor.v"
`include "bhand.v"
`endif

`include "macros.vh"

module dbg_guv # (
    parameter DATA_WIDTH = 32,
    parameter DEST_WIDTH = 16,
    parameter ID_WIDTH = 16,
    parameter CNT_SIZE = 16,
    parameter ADDR_WIDTH = 10, //This gives 1024 simultaneous debug cores
    parameter ADDR = 0, //Set this to be different for each 
    parameter RESET_TYPE = `ACTIVE_HIGH,
    parameter PIPE_STAGE = 1 //This causes a delay on cmd_out in case fanout is
                             //an issue
) (
    input wire clk,
    input wire rst,
    
    //Input command stream
    //This may be a bad decision, but I decided the command width should match
    //the inject data width.
    //How does this work if you have a bunch of streams of different sizes that
    //you want to debug? Also, what about the rr_tree in that case?
    //Also, this core cannot assert backpressure
    input wire [DATA_WIDTH -1:0] cmd_in_TDATA,
    input wire cmd_in_TVALID,
    
    //All the controllers are daisy-chained. If in incoming command is not for
    //this controller, send it to the next one
    output wire [DATA_WIDTH -1:0] cmd_out_TDATA,
    output wire cmd_out_TVALID,
    
    //Also,since this module is intended to wrap around axis_governor, we need
    //to provide access to its ports through this one.
    
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
    ////////////////////
    //LOCAL PARAMETERS//
    ////////////////////
    
    `localparam REG_ADDR_WIDTH = 4;
    //These just clean up the code slightly
    `localparam NO_RST = (RESET_TYPE == `NO_RESET);
    `localparam HAS_RST = (RESET_TYPE != `NO_RESET);
    
    ////////////////////////
    //FORWARD DECLARATIONS//
    ////////////////////////
    
    //Wires needed for axis_governor connections
    wire inj_TREADY;
    `wire_axis_kl(log, DATA_WIDTH);
    wire [DEST_WIDTH -1:0] log_TDEST;
    wire [ID_WIDTH -1:0] log_TID;
    
    ////////////////
    //HELPER WIRES//
    ////////////////
    
    //Named subfields of command
    wire [ADDR_WIDTH -1:0] cmd_core_addr = cmd_in_TDATA[ADDR_WIDTH + REG_ADDR_WIDTH -1 :- ADDR_WIDTH];
    wire [REG_ADDR_WIDTH -1:0] cmd_reg_addr = cmd_in_TDATA[REG_ADDR_WIDTH -1:0];  
    //We need to know if this message was meant for us
    wire msg_for_us = cmd_in_TVALID && (cmd_core_addr == ADDR);
    
    wire rst_sig;
`genif (RESET_TYPE == `ACTIVE_HIGH) begin
    assign rst_sig = rst;
`else_gen
    assign rst_sig = ~rst;
`endgen

    ///////////////////////////
    //COMMAND INTERPRETER FSM//
    ///////////////////////////
    
    //These registers are immediately updated
    reg [CNT_SIZE -1:0] drop_cnt_r = 0;        //Reg addr = 0
    reg [CNT_SIZE -1:0] log_cnt_r = 0;         //Reg addr = 1
    reg [DATA_WIDTH -1:0] inj_TDATA_r = 0;     //Reg addr = 2
    reg inj_TVALID_r = 0;                      //Reg addr = 3
    reg inj_TLAST_r = 0;                       //Reg addr = 4
    reg [DATA_WIDTH/8 -1:0] inj_TKEEP_r = 0;   //Reg addr = 5
    reg [DEST_WIDTH -1:0] inj_TDEST_r = 0;     //Reg addr = 6
    reg [ID_WIDTH -1:0] inj_TID_r = 0;         //Reg addr = 7
    reg keep_pausing_r = 0;                    //Reg addr = 8
    reg keep_logging_r = 0;                    //Reg addr = 9
    reg keep_dropping_r = 0;                   //Reg addr = 10
    
    `localparam CMD_FSM_ADDR = 0;
    `localparam CMD_FSM_DATA = 1;
    
    reg cmd_fsm_state = CMD_FSM_ADDR;
    reg [REG_ADDR_WIDTH -1:0] saved_reg_addr = 0;
    
    //The user puts in a reg address of all ones to commit register values
    wire latch_sig = (cmd_fsm_state == CMD_FSM_ADDR) && msg_for_us && (cmd_reg_addr == {REG_ADDR_WIDTH{1'b1}});
    
    assign cmd_in_TREADY = msg_for_us || (cmd_fsm_state == CMD_FSM_DATA);
    
    //In the interests of keeping things simple, the commands will happen over
    //two flits: "address" and "data"

`genif (NO_RST) begin
    always @(posedge clk) begin
        if (latch_sig) begin
            drop_cnt_r <= 0;
            log_cnt_r <= 0;
            inj_TVALID_r <= 0;
            keep_pausing_r <= 0;
            keep_logging_r <= 0;
            keep_dropping_r <= 0;
        end else begin
            case (cmd_fsm_state)
            CMD_FSM_ADDR: begin
                cmd_fsm_state <= msg_for_us ? CMD_FSM_DATA : CMD_FSM_ADDR;
                saved_reg_addr <= cmd_reg_addr;
            end CMD_FSM_DATA: begin
                if (cmd_in_TVALID) begin
                    cmd_fsm_state <= CMD_FSM_ADDR;
                    case (saved_reg_addr)
                    0:  drop_cnt_r <= cmd_in_TDATA[CNT_SIZE -1:0];
                    1:  log_cnt_r <= cmd_in_TDATA[CNT_SIZE -1:0];
                    2:  inj_TDATA_r <= cmd_in_TDATA;
                    3:  inj_TVALID_r <= cmd_in_TDATA[0];
                    4:  inj_TLAST_r <= cmd_in_TDATA[0];
                    5:  inj_TKEEP_r <= cmd_in_TDATA[DATA_WIDTH/8 -1:0];
                    6:  inj_TDEST_r <= cmd_in_TDATA[DEST_WIDTH -1:0];
                    7:  inj_TID_r <= cmd_in_TDATA[ID_WIDTH -1:0];
                    8:  keep_pausing_r <= cmd_in_TDATA[0];
                    9:  keep_logging_r <= cmd_in_TDATA[0];
                    10: keep_dropping_r <= cmd_in_TDATA[0];
                    endcase
                end
            end
            endcase
        end
    end
`else_gen 
    always @(posedge clk) begin
        if (latch_sig || rst_sig) begin
            drop_cnt_r <= 0;
            log_cnt_r <= 0;
            inj_TVALID_r <= 0;
            keep_pausing_r <= 0;
            keep_logging_r <= 0;
            keep_dropping_r <= 0;
        end else begin
            case (cmd_fsm_state)
            CMD_FSM_ADDR: begin
                cmd_fsm_state <= msg_for_us ? CMD_FSM_DATA : CMD_FSM_ADDR;
                saved_reg_addr <= cmd_reg_addr;
            end CMD_FSM_DATA: begin
                if (cmd_in_TVALID) begin
                    cmd_fsm_state <= CMD_FSM_ADDR;
                    case (saved_reg_addr)
                    0:  drop_cnt_r <= cmd_in_TDATA[CNT_SIZE -1:0];
                    1:  log_cnt_r <= cmd_in_TDATA[CNT_SIZE -1:0];
                    2:  inj_TDATA_r <= cmd_in_TDATA;
                    3:  inj_TVALID_r <= cmd_in_TDATA[0];
                    4:  inj_TLAST_r <= cmd_in_TDATA[0];
                    5:  inj_TKEEP_r <= cmd_in_TDATA[DATA_WIDTH/8 -1:0];
                    6:  inj_TDEST_r <= cmd_in_TDATA[DEST_WIDTH -1:0];
                    7:  inj_TID_r <= cmd_in_TDATA[ID_WIDTH -1:0];
                    8:  keep_pausing_r <= cmd_in_TDATA[0];
                    9:  keep_logging_r <= cmd_in_TDATA[0];
                    10: keep_dropping_r <= cmd_in_TDATA[0];
                    endcase
                end
            end
            endcase
        end
    end
`endgen
    
    ////////////////////////
    //GOVERNOR CONTROL FSM//
    ////////////////////////
        
    reg [CNT_SIZE -1:0] drop_cnt = 0;
    reg [CNT_SIZE -1:0] log_cnt = 0;
    reg [DATA_WIDTH -1:0] inj_TDATA = 0;
    reg inj_TVALID = 0;
    reg inj_TLAST = 0;
    reg [DATA_WIDTH/8 -1:0] inj_TKEEP = 0;
    reg [DEST_WIDTH -1:0] inj_TDEST = 0;
    reg [ID_WIDTH -1:0] inj_TID = 0;
    reg keep_pausing = 0;
    reg keep_logging = 0;
    reg keep_dropping = 0;
    
    //Governor control wires. These feed directly into axis_governor
    wire pause;
    wire drop;
    wire log_en;
    
`genif (NO_RST) begin
    always @(posedge clk) begin
        if (latch_sig) begin
            drop_cnt <= drop_cnt_r;
            log_cnt <= drop_cnt_r;
            inj_TDATA <= inj_TDATA_r;
            inj_TVALID <= inj_TVALID_r;
            inj_TLAST <= inj_TLAST_r;
            inj_TKEEP <= inj_TKEEP_r;
            inj_TDEST <= inj_TDEST_r;
            inj_TID <= inj_TID_r;
            keep_pausing <= keep_pausing_r;
            keep_logging <= keep_logging_r;
            keep_dropping <= keep_dropping_r;
        end else begin
            //Decrement drop_cnt when flit is sent (if drop_cnt is not already zero)
            drop_cnt <= (|drop_cnt) ? (drop_cnt - `axis_flit(in)) : drop_cnt;
            //Decrement drop_cnt when flit is logged (if log_cnt is not already zero)
            log_cnt <= (|log_cnt) ? (log_cnt - `axis_flit(log)) : log_cnt;
            //Set inj_TVALID to 0 once an injection occurs
            inj_TVALID <= `axis_flit(inj) ? 0 : inj_TVALID;
        end
    end
`else_gen 
    always @(posedge clk) begin
        if (rst_sig) begin
            drop_cnt <= 0;
            log_cnt <= 0;
            inj_TDATA <= 0;
            inj_TVALID <= 0;
            inj_TLAST <= 0;
            inj_TKEEP <= 0;
            inj_TDEST <= 0;
            inj_TID <= 0;
            keep_pausing <= 0;
            keep_logging <= 0;
            keep_dropping <= 0;
        end else if (latch_sig) begin
            drop_cnt <= drop_cnt_r;
            log_cnt <= drop_cnt_r;
            inj_TDATA <= inj_TDATA_r;
            inj_TVALID <= inj_TVALID_r;
            inj_TLAST <= inj_TLAST_r;
            inj_TKEEP <= inj_TKEEP_r;
            inj_TDEST <= inj_TDEST_r;
            inj_TID <= inj_TID_r;
            keep_pausing <= keep_pausing_r;
            keep_logging <= keep_logging_r;
            keep_dropping <= keep_dropping_r;
        end else begin
            //Decrement drop_cnt when flit is sent (if drop_cnt is not already zero)
            drop_cnt <= (|drop_cnt) ? (drop_cnt - `axis_flit(in)) : drop_cnt;
            //Decrement drop_cnt when flit is logged (if log_cnt is not already zero)
            log_cnt <= (|log_cnt) ? (log_cnt - `axis_flit(log)) : log_cnt;
            //Set inj_TVALID to 0 once an injection occurs
            inj_TVALID <= `axis_flit(inj) ? 0 : inj_TVALID;
        end
    end
`endgen
    
    //We don't pause if our dropping/logging counters are still going
    assign pause = keep_pausing && ~(|drop_cnt || |log_cnt);
    assign log_en = keep_logging || (|log_cnt);
    assign drop_en = keep_dropping || (|drop_cnt);
    

    /////////////////////////////
    //INSTANTIATE AXIS GOVERNOR//
    /////////////////////////////
    
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
    
    //////////////////////////////////////
    //CONNECT REMAINING WIRES TO OUTPUTS//
    //////////////////////////////////////

`genif (PIPE_STAGE) begin
    //Delay by one cycle for timing
    reg [DATA_WIDTH -1:0] cmd_out_TDATA_r = 0;
    reg cmd_out_TVALID_r = 0;
    
    always @(posedge clk) begin
        cmd_out_TDATA_r <= cmd_in_TDATA;
        cmd_out_TVALID_r <= cmd_in_TVALID;
    end
    
    assign cmd_out_TDATA = cmd_out_TDATA_r;
    assign cmd_out_TVALID = cmd_out_TVALID_r;
`else_gen 
    assign cmd_out_TDATA = cmd_in_TDATA;
    assign cmd_out_TVALID = cmd_in_TVALID;
`endgen
    
    assign log_catted_TDATA = {log_TDATA, log_TKEEP, log_TLAST, log_TDEST, log_TID};
    assign log_catted_TVALID = log_TVALID;
    assign log_TREADY = log_catted_TREADY;
    
endmodule