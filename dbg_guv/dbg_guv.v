`timescale 1ns / 1ps
`default_nettype none

/*

This wraps around axis_governor.v, and is what will get put into your block 
diagram when you use the automatic TCL scripts provided along with these cores. 
Please forgive the messy organization; it's unclear how to organize things 
until they're all finished.

This controller works by maintaining two sets of registers. The first set of 
registers, called S1, include:

    - drop_cnt: The number of flits to drop from the input stream
    - log_cnt: The number of flits to log from the input stream
    - inj_TDATA: The TDATA field of the injection input
    - inj_TVALID: The TVALID field of the injection input.
    - inj_T*: The other AXI Stream fields for the injection input
    - keep_pausing: When 1, pauses input stream indefinitely
    - keep_logging: When 1, logs input stream indefinitely
    - keep_dropping: When 1, drops input stream indefinitely

Whenever a flit is dropped(logged), drop_cnt(log_cnt) is decremented. Once the 
count reaches zero, no more flits will be dropped(logged), unless 
keep_dropping(keep_logging) is asserted. If the drop_cnt(log_cnt) is nonzero, 
the keep_pausing signal is ignored. Otherwise, keep_pausing causes 
keep_dropping(keep_logging) to be ignored. Also, as soon as the injected flit 
is sent out, the inj_TVALID register is reset to zero.

The second set of registers, called S2, is identical to the first set. In the 
code, they have an "_r" at the end of their name. These registers do not 
control anything, and can only be set by the command interface. The trick is 
that we perform S1 = S2 when the user sends a special command. This allows the 
user to build up a (possibly complex) set of register updates that will then be 
applied simultaneously. 

The command interface is definitely clunky, but I've already found myself 
spending a lot of time writing this code and I want to move on. It only needs 
to be good enough. Anyway, it works in two steps: first you send an address, 
and then you send data on the immediately following flit. The address is 
formatted as {padding, dbg_core, reg}. The dbg_core address specifies which 
debug core to use, and reg specifies which of the S1 registers to update within 
that debug core. If reg is all ones, then S1 is copied into S2. These addresses 
are aligned to the right of cmd_in_TDATA by padding on the left. The data is 
formatted as {padding, data}. Everything is in big-endian.


UPDATES
Mar 23 / 2020 This module now sends command receipts on the logging interface.
Jun 12 / 2020 Removed STICKY_MODE. S1 registers always retain their values.

*/

/*
Remaining tasks for implementing new interface:

[x] Use shift register technique for INJECT_TDATA_r
[N] Use "generate if" to get rid of TID, TDEST, TUSER if unused (forget it; it's too much trouble)
[x] Construct correct headers for logs and command receipts
[x] Construct properly padded payload vector
[x] Figure out how to replace the axis_mux thing
[x] Add in the dbg_guv_width_adapter
[ ] Oh yeah, don't forget the flit for sidechannels
[ ] Simulate the crap out of it
*/

 `ifdef ICARUS_VERILOG
`include "axis_governor.v"
`include "dbg_guv_width_adapter.v"
`include "tkeep_to_len.v"
`endif

`include "macros.vh"

//This ugly business is because you have conditional ports on a module. If
//the user selects an ID_WIDTH of 0, then unfortunately the expression
//
//  input wire [ID_WIDTH -1:0] din_TID
//
//has an illegal size.
//So, even if a sidechannel is unused, we are still forced to make sure that
//the resulting Verilog is legal
`define SAFE_ID_WIDTH (ID_WIDTH < 1 ? 1 : ID_WIDTH)
`define SAFE_DEST_WIDTH (DEST_WIDTH < 1 ? 1 : DEST_WIDTH)

`define MIN(x,y) (((x)<(y)) ? (x) : (y))
`define MAX(x,y) (((x)>(y)) ? (x) : (y))
    
module dbg_guv # (
    parameter DATA_WIDTH = 64,
    parameter DATA_HAS_TKEEP = 1,
    parameter DATA_HAS_TLAST = 1,
    parameter DEST_WIDTH = 0, /*range: 0-32 (inclusive)*/
    parameter ID_WIDTH = 0, /*range: 0-32 (inclusive)*/
    parameter CNT_SIZE = 16,
    /*DO NOT EDIT*/ parameter ADDR_WIDTH = 13, //This gives maximum 8196 simultaneous debug cores. That should be enough!
    parameter [ADDR_WIDTH -1:0] ADDR = 0, //Set this to be different for each 
    parameter RESET_TYPE = `NO_RESET,
    parameter DUT_RST_VAL = 1, //The value of DUT_rst that will reset the DUT
    parameter PIPE_STAGE = 1, //This causes a delay on cmd_out in case fanout is
                              //an issue
    parameter SATCNT_WIDTH = 3, //Saturating counter for number of cycles slave
                               //has not been ready
    parameter DEFAULT_DROP = 0,
    parameter DEFAULT_LOG = 0,
    parameter DEFAULT_PAUSE = 0,
    parameter DEFAULT_INJECT = 0
) (
    input wire clk,
    input wire rst,
    
    //Input command stream
    input wire [31:0] cmd_in_TDATA,
    input wire cmd_in_TVALID,
    
    //All the controllers are daisy-chained. If in incoming command is not for
    //this controller, send it to the next one
    output wire [31:0] cmd_out_TDATA,
    output wire cmd_out_TVALID,
    
    //Also,since this module is intended to wrap around axis_governor, we need
    //to provide access to its ports through this one.
    
    //Input AXI Stream.
    `in_axis_kl(din, DATA_WIDTH),
    input wire [`SAFE_DEST_WIDTH -1:0] din_TDEST,
    input wire [`SAFE_ID_WIDTH -1:0] din_TID,
    
    //Output AXI Stream.
    `out_axis_kl(dout, DATA_WIDTH),
    output wire [`SAFE_DEST_WIDTH -1:0] dout_TDEST,
    output wire [`SAFE_ID_WIDTH -1:0] dout_TID,
    
    //DUT Reset output
    output wire DUT_rst,
    
    //Log and Command Receipt AXI Stream. 
    //This stream follows a very specific protocol. See the file
    //logs_and_cmds_protocol.txt in this repo
    `out_axis_l(logs_receipts, 32)
);
    ////////////////////
    //LOCAL PARAMETERS//
    ////////////////////
    
    `localparam REG_ADDR_WIDTH = 4;
    `localparam KEEP_WIDTH = DATA_WIDTH/8;
    
    ////////////////////////
    //FORWARD DECLARATIONS//
    ////////////////////////
    wire inj_TREADY;
    `wire_axis_kl(log, DATA_WIDTH);
    wire [`SAFE_DEST_WIDTH -1:0] log_TDEST;
    wire [`SAFE_ID_WIDTH -1:0] log_TID;
    
    ////////////////
    //HELPER WIRES//
    ////////////////
    
    //Serves double duty. If you wrote a new command with inj_TVALID_r == 0, 
    //this value will be 1 if the old injection was forcibly dropped.
    //If instead you wrote a new command with inj_TVALID_r == 1 but the old
    //injection was still not sent, this value will go to 1.
    //It means that either your new inject or an old inject was dropped,
    //depending on whether you wrote 0 or 1 to inj_TVALID_r
    wire inj_failed;
    
    //Helper wire to indicate when a latch command is received
    wire latch_sig;
    
    //Named subfields of command
    wire [ADDR_WIDTH -1:0] cmd_core_addr = cmd_in_TDATA[ADDR_WIDTH + REG_ADDR_WIDTH -1 -: ADDR_WIDTH];
    wire [REG_ADDR_WIDTH -1:0] cmd_reg_addr = cmd_in_TDATA[REG_ADDR_WIDTH -1:0];  
    //We need to know if this message was meant for us
    wire msg_for_us = (cmd_core_addr == ADDR);
    
    `wire_rst_sig;
    
    ///////////////////////////
    //COMMAND INTERPRETER FSM//
    ///////////////////////////
    
    //These registers are immediately updated
    reg [CNT_SIZE -1:0] drop_cnt_r = 0;        //Reg addr = 0
    reg [CNT_SIZE -1:0] log_cnt_r = 0;         //Reg addr = 1
    reg [DATA_WIDTH -1:0] inj_TDATA_r = 0;     //Reg addr = 2
    reg inj_TVALID_r = 0;                      //Reg addr = 3
    reg inj_TLAST_r = 0;                       //Reg addr = 4
    reg [KEEP_WIDTH -1:0] inj_TKEEP_r = 0;     //Reg addr = 5
    reg [`SAFE_DEST_WIDTH -1:0] inj_TDEST_r = 0;     //Reg addr = 6
    reg [`SAFE_ID_WIDTH -1:0] inj_TID_r = 0;         //Reg addr = 7
    reg keep_pausing_r = 0;                    //Reg addr = 8
    reg keep_logging_r = 0;                    //Reg addr = 9
    reg keep_dropping_r = 0;                   //Reg addr = 10
    reg dut_reset_r = !DUT_RST_VAL;            //Reg addr = 11
    //Special register: if register address is 14, then all S2 registers
    //are reset?
    
    `localparam [1:0] CMD_FSM_ADDR = 0;
    `localparam [1:0] CMD_FSM_DATA = 1;
    `localparam [1:0] CMD_FSM_IGNORE = 2;
    
    reg [1:0] cmd_fsm_state = CMD_FSM_ADDR;
    reg [REG_ADDR_WIDTH -1:0] saved_reg_addr = 0;
    
    //The user puts in a reg address of all ones to commit register values
    wire reg_addr_all_ones = (cmd_reg_addr == {REG_ADDR_WIDTH{1'b1}});
    assign latch_sig = (cmd_fsm_state == CMD_FSM_ADDR) && msg_for_us && cmd_in_TVALID && reg_addr_all_ones;
    
    //TODO: If Vivado is truly inefficient, I'll rewrite this code in a more
    //optimized way
`genif (RESET_TYPE == `NO_RESET) begin
    always @(posedge clk) begin
        if (cmd_in_TVALID) begin
            case (cmd_fsm_state)
                CMD_FSM_ADDR: begin
                    cmd_fsm_state <= reg_addr_all_ones ? 
                        CMD_FSM_ADDR                                :
                        (msg_for_us ? CMD_FSM_DATA : CMD_FSM_IGNORE);
                        
                    saved_reg_addr <= cmd_reg_addr;
                end CMD_FSM_DATA: begin
                    cmd_fsm_state <= CMD_FSM_ADDR;
                    case (saved_reg_addr)
                        0:  drop_cnt_r <= cmd_in_TDATA[CNT_SIZE -1:0];
                        1:  log_cnt_r <= cmd_in_TDATA[CNT_SIZE -1:0];
                        //Remaining inj_TDATA_r bits handled later
                        2:  inj_TDATA_r[`MIN(32, DATA_WIDTH) -1:0] <= cmd_in_TDATA;
                        3:  inj_TVALID_r <= cmd_in_TDATA[0];
                        4:  inj_TLAST_r <= cmd_in_TDATA[0];
                        5:  inj_TKEEP_r <= cmd_in_TDATA[KEEP_WIDTH -1:0];
                        6:  inj_TDEST_r <= cmd_in_TDATA[`SAFE_DEST_WIDTH -1:0];
                        7:  inj_TID_r <= cmd_in_TDATA[`SAFE_ID_WIDTH -1:0];
                        8:  keep_pausing_r <= cmd_in_TDATA[0];
                        9:  keep_logging_r <= cmd_in_TDATA[0];
                        10: keep_dropping_r <= cmd_in_TDATA[0];
                        11: dut_reset_r <= cmd_in_TDATA[0];
                        //TODO: decide if I want to keep this or just
                        //require the user to manually reset everything 
                        //that's what they need
                        /*
                        //Special "reset all" register?
                        14: begin
                            //TODO: maybe try to find more efficient way to do this?
                            drop_cnt_r <= 0;
                            log_cnt_r <= 0;
                            inj_TVALID_r <= 0;
                            inj_TLAST_r <= 0;
                            inj_TKEEP_r <= 0;
                            inj_TDEST_r <= 0;
                            inj_TID_r <= 0;
                            keep_pausing_r <= 0;
                            keep_logging_r <= 0;
                            keep_dropping_r <= 0;
                            dut_reset_r <= !DUT_RST_VAL;
                        end
                        */
                    endcase
                end CMD_FSM_IGNORE: begin
                    cmd_fsm_state <= CMD_FSM_ADDR;
                end
            endcase
        end
    end
`else_gen //HAS_RST
    always @(posedge clk) begin
        if (rst_sig) begin
            drop_cnt_r <= 0;
            log_cnt_r <= 0;
            inj_TVALID_r <= 0;
            keep_pausing_r <= 0;
            keep_logging_r <= 0;
            keep_dropping_r <= 0;
            dut_reset_r <= !DUT_RST_VAL;
        end else if (cmd_in_TVALID) begin
            case (cmd_fsm_state)
                CMD_FSM_ADDR: begin
                    cmd_fsm_state <= reg_addr_all_ones ? 
                        CMD_FSM_ADDR                                :
                        (msg_for_us ? CMD_FSM_DATA : CMD_FSM_IGNORE);
                        
                    saved_reg_addr <= cmd_reg_addr;
                end CMD_FSM_DATA: begin
                    cmd_fsm_state <= CMD_FSM_ADDR;
                    case (saved_reg_addr)
                        0:  drop_cnt_r <= cmd_in_TDATA[CNT_SIZE -1:0];
                        1:  log_cnt_r <= cmd_in_TDATA[CNT_SIZE -1:0];
                        //Remaining inj_TDATA_r bits handled later
                        2:  inj_TDATA_r[`MIN(32, DATA_WIDTH) -1:0] <= cmd_in_TDATA;
                        3:  inj_TVALID_r <= cmd_in_TDATA[0];
                        4:  inj_TLAST_r <= cmd_in_TDATA[0];
                        5:  inj_TKEEP_r <= cmd_in_TDATA[KEEP_WIDTH -1:0];
                        6:  inj_TDEST_r <= cmd_in_TDATA[`SAFE_DEST_WIDTH -1:0];
                        7:  inj_TID_r <= cmd_in_TDATA[`SAFE_ID_WIDTH -1:0];
                        8:  keep_pausing_r <= cmd_in_TDATA[0];
                        9:  keep_logging_r <= cmd_in_TDATA[0];
                        10: keep_dropping_r <= cmd_in_TDATA[0];
                        11: dut_reset_r <= cmd_in_TDATA[0];
                        //TODO: decide if I want to keep this or just
                        //require the user to manually reset everything 
                        //that's what they need
                        /*
                        //Special "reset all" register?
                        14: begin
                            //TODO: maybe try to find more efficient way to do this?
                            drop_cnt_r <= 0;
                            log_cnt_r <= 0;
                            inj_TVALID_r <= 0;
                            inj_TLAST_r <= 0;
                            inj_TKEEP_r <= 0;
                            inj_TDEST_r <= 0;
                            inj_TID_r <= 0;
                            keep_pausing_r <= 0;
                            keep_logging_r <= 0;
                            keep_dropping_r <= 0;
                            dut_reset_r <= !DUT_RST_VAL;
                        end
                        */
                    endcase
                end CMD_FSM_IGNORE: begin
                    cmd_fsm_state <= CMD_FSM_ADDR;
                end
            endcase
        end
    end
`endgen
    
    //Logic for remaining inj_TDATA_r bits
    genvar i;
    for (i = 32; i < DATA_WIDTH; i = i + 1) begin
        always @(posedge clk) begin
            if (cmd_in_TVALID && (cmd_fsm_state == CMD_FSM_DATA) && (saved_reg_addr == 'd2)) begin
                inj_TDATA_r <= inj_TDATA_r[i - 32];
            end
        end
    end


    ////////////////////////
    //COMMAND RECEIPT INFO//
    ////////////////////////
    
    //Saturating counter for out ready.    
    //Counts up when dout_TREADY is low, and saturates instead of wrapping
    //around. Resets to zero when dout_TREADY is high
    
    reg [SATCNT_WIDTH -1:0] dout_not_rdy_cnt = 0;
`genif (RESET_TYPE == `NO_RESET) begin
    always @(posedge clk) begin
        dout_not_rdy_cnt <= (!dout_TREADY && !latch_sig) ? 
                            dout_not_rdy_cnt + !(&dout_not_rdy_cnt) :
                            0;
    end
`else_gen
    always @(posedge clk) begin
        dout_not_rdy_cnt <= (!dout_TREADY && !latch_sig && !rst_sig) ? 
                            dout_not_rdy_cnt + !(&dout_not_rdy_cnt) :
                            0;
    end
`endgen
    
    //At some point, we will select whether to send a command receipt or a log.
    reg [31:0] receipt_header = 0;
    //receipt does not have any data
    reg receipt_TVALID = 0;
    wire receipt_TREADY;
    
    //Receipt TDATA format = {
    //  zero_padding, 
    //  n  bits: dout_not_rdy_cnt, 
    //  1  bit : inj_failed, 
    //  1  bit : dut_reset, 
    //  1  bit : inj_TVALID, 
    //  1  bit : |drop_cnt, 
    //  1  bit : |log_cnt, 
    //  1  bit : keep_dropping, 
    //  1  bit : keep_logging, 
    //  1  bit : keep_pausing, 
    //  1  bit : 1 (for L/C),
    //  10 bits: ADDR
    //  }
    `localparam RECEIPT_PAD_WIDTH = 32 - SATCNT_WIDTH - 9 - ADDR_WIDTH;

    //Rule: user must always wait for a command receipt, or else they risk 
    //clobbering one
`genif (RESET_TYPE == `NO_RESET) begin
    always @(posedge clk) begin
        if (latch_sig) begin
            receipt_header <= {
                {RECEIPT_PAD_WIDTH{1'b0}}, 
                dout_not_rdy_cnt, 
                inj_failed, 
                dut_reset_r, 
                inj_TVALID_r, 
                |drop_cnt_r, 
                |log_cnt_r, 
                keep_dropping_r, 
                keep_logging_r, 
                keep_pausing_r, 
                1'b1, 
                ADDR
            };
            receipt_TVALID <= 1;
        end else begin
            receipt_TVALID <= `axis_flit(receipt) ? 0 : receipt_TVALID;
        end
    end
`else_gen
    always @(posedge clk) begin
        if(rst_sig) begin
            receipt_TVALID <= 0;
        end else if (latch_sig) begin
            receipt_header <= {
                {RECEIPT_PAD_WIDTH{1'b0}}, 
                dout_not_rdy_cnt, 
                inj_failed, 
                dut_reset_r, 
                inj_TVALID_r, 
                |drop_cnt_r, 
                |log_cnt_r, 
                keep_dropping_r, 
                keep_logging_r, 
                keep_pausing_r, 
                1'b1, 
                ADDR
            };
            receipt_TVALID <= 1;
        end else begin
            receipt_TVALID <= `axis_flit(receipt) ? 0 : receipt_TVALID;
        end
    end
`endgen

    ////////////
    //LOG INFO//
    ////////////
    
    wire [31:0] log_header;
    
    `localparam LOG_LEN_SZ = 5;
    wire [LOG_LEN_SZ -1:0] log_len;

    //Always assuming DATA_WIDTH is a multiple of 8
`genif (DATA_HAS_TKEEP) begin
    tkeep_to_len # (
        .TKEEP_WIDTH(DATA_WIDTH/8)
    ) compute_len (
        .tkeep(log_TKEEP),
        .len(log_len[$clog2(DATA_WIDTH/8) -1:0])
    );
    
    if (LOG_LEN_SZ > $clog2(DATA_WIDTH/8)) begin
        assign log_len[LOG_LEN_SZ -1: $clog2(DATA_WIDTH/8)] = 0;
    end
    
`else_gen
    assign log_len = (DATA_WIDTH/8) -1;
`endgen
    
    assign log_header = {DEST_WIDTH[5:0], ID_WIDTH[5:0], log_TLAST, log_len, 1'b0, ADDR};   
    
    
    ////////////////////////
    //GOVERNOR CONTROL FSM//
    ////////////////////////
        
    reg [CNT_SIZE -1:0] drop_cnt = 0;
    reg [CNT_SIZE -1:0] log_cnt = 0;
    reg [DATA_WIDTH -1:0] inj_TDATA = 0;
    reg inj_TVALID = DEFAULT_INJECT[0];
    reg inj_TLAST = 0;
    reg [KEEP_WIDTH -1:0] inj_TKEEP = 0;
    reg [`SAFE_DEST_WIDTH -1:0] inj_TDEST = 0;
    reg [`SAFE_ID_WIDTH -1:0] inj_TID = 0;
    reg keep_pausing = DEFAULT_PAUSE[0];
    reg keep_logging = DEFAULT_LOG[0];
    reg keep_dropping = DEFAULT_DROP[0];
    reg dut_reset = !DUT_RST_VAL;
    
    //Governor control wires. These feed directly into axis_governor
    wire pause;
    wire drop;
    wire log_en;
    
    //Suppose we are trying to cancel an old injection (inj_TVALID_r == 0)
    //Then the old injection failed if it was valid but is not being sent
    //right now.
    //A neat trick: now suppose we are trying to write a new injections
    //(inj_TVALID_r == 1). This fails if the old inject was valid and
    //is not being sent right now. 
    //In other words, inj_failed is always equal to this expression no
    //matter what we're doing. Nice!
    assign inj_failed = inj_TVALID && !inj_TREADY;
    
`genif (RESET_TYPE == `NO_RESET) begin
    always @(posedge clk) begin
        if (latch_sig) begin
            drop_cnt <= drop_cnt_r;
            log_cnt <= log_cnt_r;
            //Special rule: only write new inject values if the old ones have
            //been sent. However, if the new inj_TVALID_r is zero, then we are
            //forcing this inject to be dropped, so write anyway
            if (!inj_failed || inj_TVALID_r == 0) begin
                inj_TDATA <= inj_TDATA_r;
                inj_TVALID <= inj_TVALID_r;
                inj_TLAST <= inj_TLAST_r;
                inj_TKEEP <= inj_TKEEP_r;
                inj_TDEST <= inj_TDEST_r;
                inj_TID <= inj_TID_r;
            end            
            keep_pausing <= keep_pausing_r;
            keep_logging <= keep_logging_r;
            keep_dropping <= keep_dropping_r;
            dut_reset <= dut_reset_r;
        end else begin
            //Decrement drop_cnt when flit is sent (if drop_cnt is not already zero)
            drop_cnt <= (|drop_cnt) ? (drop_cnt - `axis_flit(din)) : drop_cnt;
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
            dut_reset <= 0;
        end else if (latch_sig) begin
            drop_cnt <= drop_cnt_r;
            log_cnt <= log_cnt_r;
            //See above `genif clause for explanation of inj_* signals
            if (!inj_failed || inj_TVALID_r == 0) begin
                inj_TDATA <= inj_TDATA_r;
                inj_TVALID <= inj_TVALID_r;
                inj_TLAST <= inj_TLAST_r;
                inj_TKEEP <= inj_TKEEP_r;
                inj_TDEST <= inj_TDEST_r;
                inj_TID <= inj_TID_r;
            end   
            keep_pausing <= keep_pausing_r;
            keep_logging <= keep_logging_r;
            keep_dropping <= keep_dropping_r;
            dut_reset <= dut_reset_r;
        end else begin
            //Decrement drop_cnt when flit is sent (if drop_cnt is not already zero)
            drop_cnt <= (|drop_cnt) ? (drop_cnt - `axis_flit(din)) : drop_cnt;
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
    assign drop = keep_dropping || (|drop_cnt);
    

    /////////////////////////////
    //INSTANTIATE AXIS GOVERNOR//
    /////////////////////////////
    
    axis_governor #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEST_WIDTH(`SAFE_DEST_WIDTH),
        .ID_WIDTH(`SAFE_ID_WIDTH)
    ) ello_guvna (    
        .clk(clk),
        
        //Input AXI Stream.
        .in_TDATA(din_TDATA),
        .in_TVALID(din_TVALID),
        .in_TREADY(din_TREADY),
        .in_TKEEP(din_TKEEP),
        .in_TDEST(din_TDEST),
        .in_TID(din_TID),
        .in_TLAST(din_TLAST),
        
        //Inject AXI Stream. 
        .inj_TDATA(inj_TDATA),
        .inj_TVALID(inj_TVALID),
        .inj_TREADY(inj_TREADY),
        .inj_TKEEP(inj_TKEEP),
        .inj_TDEST(inj_TDEST),
        .inj_TID(inj_TID),
        .inj_TLAST(inj_TLAST),
        
        //Output AXI Stream.
        .out_TDATA(dout_TDATA),
        .out_TVALID(dout_TVALID),
        .out_TREADY(dout_TREADY),
        .out_TKEEP(dout_TKEEP),
        .out_TDEST(dout_TDEST),
        .out_TID(dout_TID),
        .out_TLAST(dout_TLAST),
        
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
        
    /////////////////////
    //ADD WIDTH ADAPTER//
    /////////////////////
    `localparam LOG_DEST_ID_SIZE = DEST_WIDTH + ID_WIDTH;
    `localparam LOG_DEST_ID_PADDED_SIZE = (((LOG_DEST_ID_SIZE+31)/32)*32);
    `localparam LOG_DEST_ID_NUM_WORDS = LOG_DEST_ID_PADDED_SIZE/32;
    `localparam LOG_DEST_ID_EXTRA_KEEP_BITS = LOG_DEST_ID_PADDED_SIZE/8;
    
    //For some reason localparams aren't allowed in generate blocks
    //This first parameter is used if DEST and ID fit in 32 bits
    `localparam LOG_DEST_ID_PADDING = 32 - LOG_DEST_ID_SIZE;
    //These two parameters are used if DEST and ID each need their own
    //32 bit word
    `localparam LOG_DEST_PADDING = 32 - DEST_WIDTH;
    `localparam LOG_ID_PADDING = 32 - ID_WIDTH;
    
    wire [`MAX(LOG_DEST_ID_PADDED_SIZE,1) -1:0] log_TDEST_TID_padded;
`genif((LOG_DEST_ID_SIZE > 0) && (LOG_DEST_ID_SIZE <= 32)) begin
    //DEST and ID together will fit in a single 32 bit word
    
    //Verilog is such a pain the ass sometimes...
    if (LOG_DEST_ID_PADDING > 0) begin
        assign log_TDEST_TID_padded = {
            {LOG_DEST_ID_PADDING{1'b0}},
            log_TID,
            log_TDEST
        };
    end else begin
        assign log_TDEST_TID_padded = {
            log_TID,
            log_TDEST
        };
    end
    
`else_gen
    //Note: our assumption is that neither of log_TDEST or log_TID is wider
    //than 32 bits. Therefore, if their sum is larger than 32, both of them
    //must be larger than 0.
    //Each DEST and ID gets its own 32 bit word
    
    assign log_TDEST_TID_padded = {
        {LOG_ID_PADDING{1'b0}},
        log_TID,
        {LOG_DEST_PADDING{1'b0}},
        log_TDEST
    };
`endgen
    
    
    //The dbg_guv_width_adapter requires that its input be a multiple of
    //32 bits
    `localparam LOG_DATA_PADDED_SIZE = (((DATA_WIDTH+31)/32)*32);
    `localparam LOG_KEEP_PADDED_SIZE = LOG_DATA_PADDED_SIZE/8;
    `localparam LOG_DATA_NUM_WORDS = LOG_DATA_PADDED_SIZE/32;
    `localparam LOG_DATA_PADDING = LOG_DATA_PADDED_SIZE - DATA_WIDTH;
    `localparam LOG_KEEP_PADDING = LOG_DATA_PADDING/8;
    
    wire [LOG_DATA_PADDED_SIZE -1:0] log_TDATA_padded;
    wire [LOG_DATA_PADDED_SIZE/8 -1:0] log_TKEEP_padded;
    
`genif(LOG_DATA_PADDING > 0) begin
    assign log_TDATA_padded = {log_TDATA, {LOG_DATA_PADDING{1'b0}}};
    assign log_TKEEP_padded = {log_TKEEP, {LOG_KEEP_PADDING{1'b0}}};
`else_gen
    assign log_TDATA_padded = log_TDATA;
    assign log_TKEEP_padded = log_TKEEP;
`endgen

    `localparam LOG_PAYLOAD_DATA_SIZE = LOG_DEST_ID_PADDED_SIZE + LOG_DATA_PADDED_SIZE;
    `localparam LOG_PAYLOAD_NUM_WORDS = LOG_DEST_ID_NUM_WORDS + LOG_DATA_NUM_WORDS;
    `localparam LOG_PAYLOAD_KEEP_BITS = LOG_DEST_ID_EXTRA_KEEP_BITS + KEEP_WIDTH + LOG_KEEP_PADDING;
    
    wire [LOG_PAYLOAD_DATA_SIZE -1:0] payload_TDATA;
    wire [LOG_PAYLOAD_KEEP_BITS -1:0] payload_TKEEP;

`genif(LOG_DEST_ID_SIZE > 0) begin
    assign payload_TDATA = {log_TDEST_TID_padded, log_TDATA_padded};
    assign payload_TKEEP = {{LOG_DEST_ID_EXTRA_KEEP_BITS{1'b1}}, log_TKEEP_padded};
`else_gen
    assign payload_TDATA = log_TDATA_padded;
    assign payload_TKEEP = log_TKEEP_padded;
`endgen
    
    wire adapter_TREADY;

    dbg_guv_width_adapter # (
        .PAYLOAD_WORDS(LOG_PAYLOAD_NUM_WORDS),
        .RESET_TYPE(RESET_TYPE)
    ) adapter (
        .clk(clk),
        .rst(rst),
        
        //The header is understood to be a "sidechannel" of the payload. I 
        //thought about naming it payload_TUSER, but opted for this clearer
        //name (since this module isn't meant to be packaged as an individual
        //IP)
        //ASSUMPTION: no TLAST here
        .header(receipt_TVALID ? receipt_header : log_header),
        .payload_TDATA(payload_TDATA),
        .payload_TKEEP(receipt_TVALID ? {LOG_PAYLOAD_KEEP_BITS{1'b0}} : payload_TKEEP),
        .payload_TVALID(log_TVALID | receipt_TVALID),
        .payload_TREADY(adapter_TREADY),
        
        `inst_axis_l(adapted, logs_receipts)
    );
    
    assign receipt_TREADY = receipt_TVALID && adapter_TREADY;
    assign log_TREADY = ~receipt_TVALID && adapter_TREADY;
        
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
    
    //It might be better to just concat the log side channels into TDATA rather 
    //than in a header flit. That way, at the cost of more routing resources, 
    //it might be possible to have 100% transparent snooping. I wasn't sure 
    //what to do so I just picked the header method and went with it
    
    assign DUT_rst = dut_reset;
    
endmodule

`undef MIN
`undef MAX
