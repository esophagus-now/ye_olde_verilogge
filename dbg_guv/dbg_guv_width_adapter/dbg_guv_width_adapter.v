/*
dbg_guv_width_adapter.v

This code is horrific! But will I make it nicer? no. I am now a permanent
resident of spaghettitown. But, I'll at least explain the general idea.

There are two states: STATE_SEND_HEADER and STATE_SEND_PAYLOAD. When in the
first state, the adapted_TDATA output is equal to the header input. Once the
header is sent (and if there are any payload words to send, as determined
by payload_TKEEP) we transition into STATE_SEND_PAYLOAD.

in the STATE_SEND_PAYLOAD state, there are two shift registers: 
keep_countdown and data_countdown. These registers are initialized with 
payload_TKEEP* and payload_TDATA when we are in the STATE_SEND_HEADER state. 
Then, every time a flit is sent on the adapted stream, we shift them to the
left. We transition back into STATE_SEND_HEADER when keep_countdown becomes
zero.

* Actually, we only need to save one TKEEP bit for every WORD_SIZE/8 bytes.

Example: (WORD_SIZE = 32, PAYLOAD_WORDS = 2)
(NOTE: stars mark changed quantities)

t = 0
-----
INPUTS
> header         = 0xDEADBEEF
> payload_TDATA  = 0xFAFFADAFFABEDAFF
> payload_TVALID = 0b               1
> payload_TKEEP  = 0b 1 1 1 1 1 1 1 0
> keep_countdown = 0b         X
> data_countdown = 0xXXXXXXXXXXXXXXXX
> adapted_TREADY = 0b               0

OUTPUTS
> adapted_TDATA  = 0xDEADBEEF
> adapted_TVALID = 0b               1
> adapted_TLAST  = 0b               0
> payload_TREADY = 0b               0

STATE
> STATE_SEND_HEADER

COMMENTS
> Because adapted_TREADY is low on this cycle, we don't send anything or 
> change the state. By the way, adapted_TLAST is zero because the leftmost
> bit of payload_TKEEP is nonzero.
>
> In STATE_SEND_HEADER, payload_TREADY is equal to adapted_TREADY


t = 1
-----
INPUTS
> header         = 0xDEADBEEF
> payload_TDATA  = 0xFAFFADAFFABEDAFF
> payload_TVALID = 0b               1
> payload_TKEEP  = 0b 1 1 1 1 1 1 1 0
>*keep_countdown = 0b         1
>*data_countdown = 0xFAFFADAFFABEDAFF
>*adapted_TREADY = 0b               1

OUTPUTS
> adapted_TDATA  = 0xDEADBEEF
> adapted_TVALID = 0b               1
> adapted_TLAST  = 0b               0
>*payload_TREADY = 0b               1

STATE
> STATE_SEND_HEADER

COMMENTS
> In STATE_SEND_HEADER, we latch payload_TDATA and every fourth 
> payload_TKEEP bit (except the last one). On the next clock edge, we will
> have sent the header, and we'll enter STATE_SEND_PAYLOAD



t = 2
-----
INPUTS
>*header         = 0xCAFEBABE
>*payload_TDATA  = 0x0123456789ABCDEF
> payload_TVALID = 0b               1
>*payload_TKEEP  = 0b 1 1 1 0 0 0 0 0
>*keep_countdown = 0b         1
>*data_countdown = 0xFAFFADAFFABEDAFF
> adapted_TREADY = 0b               1

OUTPUTS
>*adapted_TDATA  = 0xFAFFADAF
> adapted_TVALID = 0b               1
> adapted_TLAST  = 0b               0
>*payload_TREADY = 0b               0

STATE
> STATE_SEND_PAYLOAD

COMMENTS
> In STATE_SEND_HEADER (@t = 1), we latched payload_TDATA and every fourth 
> payload_TKEEP bit (except the last one). It's hard to notice because 
> the keep_countdown and data_countdown registers keep the same value (since
> their corresponding input didn't change from t = 1 to t = 2)
>
> On this cycle, we send the upper 32 bits of data_countdown. adapted_TLAST
> is still zero, but this time it's because the leftmost bit of 
> keep_countdown is nonzero. Also, because we're in STATE_SEND_PAYLOAD, 
> adapted_TLAST is likewise zero because the leftmost bit of keep_countdown
> is nonzero. Finally, payload_TREADY is always zero in STATE_SEND_PAYLOAD.
>
> Because the leftmost bit of keep_countdown is nonzero, we will stay in
> STATE_SEND_PAYLOAD for the next cycle.
>
> By the way, keep_countdown and data_countdown will shift left here because
> adapted_TREADY && adapted_TVALID are both high. If adapted_TREADY had 
> instead been zero, we wouldn't shift them, and also 0xFAFFADAFF would not
> be sent.




t = 3
-----
INPUTS
> header         = 0xCAFEBABE
> payload_TDATA  = 0x0123456789ABCDEF
> payload_TVALID = 0b               1
> payload_TKEEP  = 0b 1 1 1 0 0 0 0 0
>*keep_countdown = 0b         0
>*data_countdown = 0xFABEDAFFFABEDAFF
> adapted_TREADY = 0b               1

OUTPUTS
>*adapted_TDATA  = 0xFABEDAFF
> adapted_TVALID = 0b               1
>*adapted_TLAST  = 0b               1
> payload_TREADY = 0b               0

STATE
> STATE_SEND_PAYLOAD

COMMENTS
> Here, because we were in STATE_SEND_PAYLOAD (@t = 2) keep_countdown and
> data_countdown shifted left. (Note: the last 32 bits of data_countdown
> are unchanged; there was no need to reset them to zeroes or anything).
>
> The big difference here is that the leftmost bit of keep_countdown IS zero
> now. That means adapted_TLAST is high, and on the next cycle we will go
> back to STATE_SEND_HEADER.
>
> By the way, if adapted_TREADY was zero, we wouldn't transition back to 
> STATE_SEND_HEADER (or send 0xFABEDAFF).
*/


//ASSUMPTION: the input "plays nice". In other words, once it asserts 
//TVALID, the data and valid signals won't change.

`timescale 1ns / 1ps
`default_nettype none

`include "macros.vh"

`define MAX(x,y) (((x)>(y))?(x):(y))

module dbg_guv_width_adapter # (
    parameter WORD_SIZE = 32,
    parameter PAYLOAD_WORDS = 2,
    
    parameter RESET_TYPE = `NO_RESET
) (
    input wire clk,
    input wire rst,
    
    //The header is understood to be a "sidechannel" of the payload. I 
    //thought about naming it payload_TUSER, but opted for this clearer
    //name (since this module isn't meant to be packaged as an individual
    //IP)
    //ASSUMPTION: no TLAST here
    input wire [WORD_SIZE -1:0] header,
    `in_axis_k(payload, WORD_SIZE*PAYLOAD_WORDS),
    
    `out_axis_l(adapted, WORD_SIZE)
);
    genvar i;
    `localparam TKEEP_WIDTH = (WORD_SIZE*PAYLOAD_WORDS)/8;
    
    //I really hate how Verilog forces you to do ugly things like this to
    //get around corner cases in defining vectors...
    `localparam SAFE_PAYLOAD_WORDS = `MAX(PAYLOAD_WORDS, 2);
    wire any_words_left;
    reg [SAFE_PAYLOAD_WORDS-1 -1:0] keep_countdown = 0;
`genif(PAYLOAD_WORDS > 1) begin
    assign any_words_left = keep_countdown[PAYLOAD_WORDS-1 -1];
`else_gen
    assign any_words_left = 0;
`endgen
    reg [WORD_SIZE-1 :0] data_countdown[0: PAYLOAD_WORDS-1];

    `wire_rst_sig;    
    
    //FSM logic
    `localparam STATE_SEND_HEADER = 0;
    `localparam STATE_SEND_PAYLOAD = 1;
    reg state = STATE_SEND_HEADER;

`genif (RESET_TYPE == `NO_RESET) begin
    always @(posedge clk) begin
        case (state)
        STATE_SEND_HEADER: begin
            state <= `axis_flit(adapted) ?
                (payload_TKEEP[TKEEP_WIDTH -1] ? STATE_SEND_PAYLOAD : STATE_SEND_HEADER)
                : STATE_SEND_HEADER
            ;
        end
        STATE_SEND_PAYLOAD: begin
            state <= `axis_flit(adapted) ?
                (any_words_left ? STATE_SEND_PAYLOAD : STATE_SEND_HEADER)
                : STATE_SEND_PAYLOAD
            ;
        end
        endcase
    end
end else begin
    always @(posedge clk) begin
        if(rst_sig) begin
            state <= STATE_SEND_HEADER;
        end else begin
            case (state)
            STATE_SEND_HEADER: begin
                state <= `axis_flit(adapted) ?
                    (payload_TKEEP[TKEEP_WIDTH -1] ? STATE_SEND_PAYLOAD : STATE_SEND_HEADER)
                    : STATE_SEND_HEADER
                ;
            end
            STATE_SEND_PAYLOAD: begin
                state <= `axis_flit(adapted) ?
                    (any_words_left ? STATE_SEND_PAYLOAD : STATE_SEND_HEADER)
                    : STATE_SEND_PAYLOAD
                ;
            end
            endcase
        end
    end
`endgen

    //Tricky business: if PAYLOAD_WORDS is equal to 1, then there is no
    //keep_countdown wire, so we shouldn't keep track of it
`genif (PAYLOAD_WORDS > 1 && RESET_TYPE == `NO_RESET) begin
    //Keep track of how many payload words left to send
    always @(posedge clk) begin
        keep_countdown[0] <=  
            `si(state == STATE_SEND_HEADER) `prendre
                payload_TKEEP[(WORD_SIZE/8)-1]
            `autrement
                `si(`axis_flit(adapted)) `prendre
                    1'b0
                `autrement
                    keep_countdown[0]
                `fin
            `fin
        ;
    end
    for (i = 1; i < PAYLOAD_WORDS-1; i = i + 1) begin
        always @(posedge clk) begin
            keep_countdown[i] <= 
                `si(state == STATE_SEND_HEADER) `prendre
                    payload_TKEEP[(WORD_SIZE/8)*(i+1) -1]
                `autrement
                    `si(`axis_flit(adapted)) `prendre
                        keep_countdown[i-1]
                    `autrement 
                        keep_countdown[i]
                    `fin
                `fin
            ;
        end
    end
`else_genif(PAYLOAD_WORDS > 1) begin
    //Keep track of how many payload words left to send
    always @(posedge clk) begin
        if (rst_sig) keep_countdown[0] <= 0;
        else begin
            keep_countdown[0] <= 
                `si(state == STATE_SEND_HEADER) `prendre
                    payload_TKEEP[(WORD_SIZE/8)-1]
                `autrement
                    `si(`axis_flit(adapted)) `prendre
                        1'b0
                    `autrement
                        keep_countdown[0]
                    `fin
                `fin
            ;
        end
    end
    for (i = 1; i < PAYLOAD_WORDS-1; i = i + 1) begin
        always @(posedge clk) begin
            if (rst_sig) keep_countdown[i] <= 0;
            else begin
                keep_countdown[i] <= 
                    `si(state == STATE_SEND_HEADER) `prendre
                        payload_TKEEP[(WORD_SIZE/8)*(i+1) -1]
                    `autrement
                        `si(`axis_flit(adapted)) `prendre
                            keep_countdown[i-1]
                        `autrement 
                            keep_countdown[i]
                        `fin
                    `fin
                ;
            end
        end
    end
`endgen
    
    //Also create a shift register for the payload words
    always @(posedge clk) begin
        if (state == STATE_SEND_HEADER) begin
            data_countdown[0] <= payload_TDATA[WORD_SIZE -1:0];
        end
    end
    for (i = 1; i < PAYLOAD_WORDS; i = i + 1) begin
        always @(posedge clk) begin
            if (state == STATE_SEND_HEADER) begin
                data_countdown[i] <= payload_TDATA[(i+1)*WORD_SIZE -1 -: WORD_SIZE];
            end else if (adapted_TREADY) begin
                data_countdown[i] <= data_countdown[i-1];
            end
        end
    end
    
    //Assign remaining outputs
    assign adapted_TVALID = (state == STATE_SEND_HEADER) ?
          payload_TVALID
        : 1'b1;
    
    assign adapted_TLAST = (state == STATE_SEND_HEADER) ? 
          ~payload_TKEEP[TKEEP_WIDTH-1]
        : ~any_words_left
    ;
    
    assign adapted_TDATA = (state == STATE_SEND_HEADER) ?
        header
        : data_countdown[PAYLOAD_WORDS-1]
    ;
    
    assign payload_TREADY = (state == STATE_SEND_HEADER); //Unintuitive
    
endmodule
    
`undef MAX
