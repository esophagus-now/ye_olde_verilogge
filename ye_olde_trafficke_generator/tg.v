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
    reg [15:0] flit_cnt = 0;
    reg [15:0] packet_cnt = 0;
    reg [31:0] lfsr = 1;
    reg [31:0] sum = -'sd1;

    parameter IDLE = 2'b00;
    parameter NORMAL = 2'b01;
    parameter COOLDOWN = 2'b11;
    parameter WAITING = 2'b10;
    reg [1:0] state = IDLE;
    
    //Some helper wires for neatening code. Also, adding delays to inputs helps when
    //using AXI GPIOs to set config registers
    reg [15:0] num_packets_r;
    reg [15:0] num_packets_i;
    always @(posedge clk) num_packets_r <= num_packets[15:0];
    always @(posedge clk) num_packets_i <= num_packets_r;
    reg [15:0] num_flits_r;
    reg [15:0] num_flits_i;
    always @(posedge clk) num_flits_r <= num_flits[15:0];
    always @(posedge clk) num_flits_i <= num_flits_r;
    reg [7:0] last_flit_bytes_r;
    reg [7:0] last_flit_bytes_i;
    always @(posedge clk) last_flit_bytes_r <= last_flit_bytes[7:0];
    always @(posedge clk) last_flit_bytes_i <= last_flit_bytes_r;
    reg [15:0] M_r;
    reg [15:0] M_i;
    always @(posedge clk) M_r <= M[15:0];
    always @(posedge clk) M_i <= M_r;
    reg [15:0] N_r;
    reg [15:0] N_i;
    always @(posedge clk) N_r <= N[15:0];
    always @(posedge clk) N_i <= N_r;
    
    wire last_flit;
    assign last_flit = TVALID && TREADY && TLAST;
    wire last_packet;
    assign last_packet = last_flit && (packet_cnt == (num_packets_i-1));
    

    //Named subfields of mode
    reg [7:0] mode_r;
    reg [7:0] mode_i;
    always @(posedge clk) mode_r <= mode[7:0];
    always @(posedge clk) mode_i <= mode_r;
    wire en;
    assign en = mode_i[0];
    wire [1:0] fill;
    assign fill = mode_i[2:1];
    wire loop;
    assign loop = mode_i[3];
    
    //Generate header
    `define HEADER_BYTES (2+2+1+2+2+1+2+2)
    
    wire [8*`HEADER_BYTES -1:0] hdr;
    //Have to play the endianness game...
    assign hdr = {
        packet_cnt,
        flit_cnt,
        mode_i, 
        num_packets_i, 
        num_flits_i,
        last_flit_bytes_i,
        M_i,
        N_i
    };
    
    //Generate TKEEP for last flit
    wire [BYTES -1 :0] last_flit_tkeep;
    for (i = 0; i < BYTES; i = i + 1) begin
        assign last_flit_tkeep[i] = ((BYTES-1-i) < last_flit_bytes_i);
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
                sum <= sum + M_i;
            else
                sum <= sum - N_i;
        end
    end
    
    wire [31:0] deadbeef;
    assign deadbeef = 32'hDEADBEEF;
    
    //Fill each byte of TDATA and each bit of TKEEP
    for (i = BYTES -1; i >= 0; i = i - 1) begin
        /*assign TDATA[8*(i+1) -1 -: 8] = 
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
        */ //This was failing timing because too much routing congestion
        if ((BYTES-1-i) < `HEADER_BYTES) begin
        	assign TDATA[8*(i+1) -1 -: 8] = hdr[8*(`HEADER_BYTES -1 - (BYTES-1-i)%`HEADER_BYTES +1) -1 -: 8];
        end else if (i%4 == 3) begin
        	assign TDATA[8*(i+1) -1 -: 8] = 8'hDE;
        end else if (i%4 == 2) begin
        	assign TDATA[8*(i+1) -1 -: 8] = 8'hAD;
        end else if (i%4 == 1) begin
        	assign TDATA[8*(i+1) -1 -: 8] = 8'hBE;
        end else begin
        	assign TDATA[8*(i+1) -1 -: 8] = 8'hEF;
        end
        assign TKEEP[i] = !TLAST || last_flit_tkeep[i];
                
    end
    
    //Assign TVALID and TLAST
    assign TVALID = (state == NORMAL);
    assign TLAST = (flit_cnt == num_flits_i - 1);
    
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
