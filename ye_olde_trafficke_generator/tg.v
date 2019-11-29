`timescale 1ns / 1ps

/*

tg.v

Generates AXI Stream traffic. 

Does not care one bit about area efficiency; the only concern is passing timing 
at 322 MHz.

*/


//"if" was already taken
`define si(x) ((x) ?
`define prendre (
`define autrement ) : (
`define fin ))

module tg # (
    parameter WIDTH = 512
) (
    input wire clk,
    input wire rst,
    
    //All runtime configuration parameters are 32 bits wide, in case I want to
    //use AXI Lite one of these days. However, I only ever use a subset of the
    //bits, as indicated in the comments next to the input
    input wire [31:0] mode,             //bits 5:0
    input wire [31:0] num_packets,      //bits 15:0
    input wire [31:0] num_flits,        //bits 15:0
    input wire [31:0] last_flit_bytes,  //bits 7:0
    input wire [31:0] M,                //bits 15:0
    input wire [31:0] N,                //bits 15:0
    
    //AXI Stream signals
    output wire [WIDTH-1:0] TDATA,
    output wire [WIDTH/8 - 1:0] TKEEP,
    output wire TVALID,
    input wire TREADY,
    output wire TLAST
);
    parameter BYTES = WIDTH/8;
    genvar i;
    //Internal signals
    reg [31:0] flit_cnt = 0;
    reg [31:0] packet_cnt = 0;
    reg [31:0] lfsr = 1;
    reg [31:0] sum = -'sd1;

    parameter IDLE = 2'b00;
    parameter NORMAL = 2'b01;
    parameter COOLDOWN = 2'b11;
    parameter WAITING = 2'b10;
    reg [1:0] state = IDLE;
    
    //Some helper wires for neatening code
    wire last_flit;
    assign last_flit = TVALID && TREADY && TLAST;
    wire last_packet;
    assign last_packet = last_flit && (packet_cnt == (num_packets-1));
    

    //Named subfields of mode
    wire en;
    assign en = mode[0];
    wire [1:0] fill;
    assign fill = mode[2:1];
    wire loop;
    assign loop = mode[3];
    
    //Generate header
    `define HEADER_BYTES (2+2+1+2+2+1+2+2)
    
    wire [8*`HEADER_BYTES -1:0] hdr;
    //Have to play the endianness game...
    assign hdr = {
        packet_cnt[15:0],
        flit_cnt[15:0],
        mode[7:0], 
        num_packets[15:0], 
        num_flits[15:0],
        last_flit_bytes[7:0],
        M[15:0],
        N[15:0]
    };
    
    //Generate TKEEP for last flit
    wire [BYTES -1 :0] last_flit_tkeep;
    for (i = 0; i < BYTES; i = i + 1) begin
        assign last_flit_tkeep[i] = ((BYTES-1-i) < last_flit_bytes);
    end
    
    //Update internal counters
    always @(posedge clk) begin
        if (rst || (en == 0) || state == WAITING || state == IDLE) begin
            sum <= -'sd1;
            packet_cnt <= 0;
            flit_cnt <= 0;
        end else begin
            flit_cnt <= (last_flit) ? 0 : flit_cnt + (TVALID & TREADY);
            packet_cnt <= (last_packet) ? 0 : packet_cnt + (last_flit);
            if (TVALID && TREADY)
                sum <= sum + M;
            else
                sum <= sum - N;
        end
    end
    
    wire [31:0] deadbeef;
    assign deadbeef = 32'hDEADBEEF;
    
    //Fill each byte of TDATA and each bit of TKEEP
    for (i = BYTES -1; i >= 0; i = i - 1) begin
        assign TDATA[8*(i+1) -1 -: 8] = 
            `si(fill[1]) `prendre
                `si(fill[0]) `prendre
                    deadbeef[8*(3 - (BYTES-1-i)%4 + 1) -1 -: 8]
                `autrement
                    lfsr
                `fin
            `autrement
                `si(fill[0]) `prendre
                    hdr[8*(`HEADER_BYTES -1 - (BYTES-1-i)%`HEADER_BYTES +1) -1 -: 8]
                `autrement
                    0
                `fin
            `fin;
        assign TKEEP[i] =
            `si(TLAST) `prendre
                last_flit_tkeep[i]
            `autrement
                1
            `fin;
                
    end
    
    //Assign TVALID and TLAST
    assign TVALID = (state == NORMAL);
    assign TLAST = (flit_cnt == num_flits - 1);
    
    //State machine
    
    always @(posedge clk) begin
        if (rst || (en == 0)) begin
            state <= IDLE;
        end else begin
            case (state)
                IDLE:
                    state <= (en == 1) ? NORMAL : IDLE;
                NORMAL:
                    state <=
                        `si(last_packet && !loop) `prendre
                            WAITING
                        `autrement
                            `si(last_flit) `prendre
                                //Check the sign bit of sum
                                //(I should have made sum 42 bits)
                                `si(sum[31] == 0) `prendre
                                    COOLDOWN
                                `autrement
                                    NORMAL
                                `fin
                            `autrement
                                NORMAL
                            `fin
                        `fin;
                COOLDOWN:
                    state <= (sum[31] == 0) ? COOLDOWN : NORMAL;
                WAITING:
                    state <= (en == 1) ? WAITING : IDLE;
            endcase
        end
    end
endmodule

`undef HEADER_BYTES
`undef si
`undef prendre
`undef autrement
`undef fin
