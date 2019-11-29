`timescale 1ns / 1ps

/*
tg_tb.v

Replace innards with desired logic
*/

`ifdef FROM_TG
`include "tg.v"
`endif

`define WIDTH 64

module tg_tb;
    reg clk;
    reg rst;
    
    reg [31:0] mode;             //bits 5:0
    reg [31:0] num_packets;      //bits 15:0
    reg [31:0] num_flits;        //bits 15:0
    reg [31:0] last_flit_bytes;  //bits 7:0
    reg [31:0] M;                //bits 15:0
    reg [31:0] N;                //bits 15:0
    
    //AXI Stream signals
    wire [`WIDTH-1:0] TDATA;
    wire [`WIDTH/8 - 1:0] TKEEP;
    wire TVALID;
    reg TREADY;
    wire TLAST;
    
    integer fd, dummy;
    
    initial begin
        $dumpfile("tg.vcd");
        $dumpvars;
        $dumplimit(512000);
        
        clk <= 0;
        rst <= 0;
        mode <= 0;
        num_packets <= 0;
        num_flits <= 0;
        last_flit_bytes <= 0;
        M <= 0;
        N <= 0;
        TREADY <= 1;
        
        fd = $fopen("tg_drivers.mem", "r");
        if (fd == 0) begin
            $display("Could not open file");
            $finish;
        end
        
        while ($fgetc(fd) != "\n") begin
            if ($feof(fd)) begin
                $display("Error: drivers file is in incorrect format");
                $finish;
            end
        end
    end
    
    always #5 clk <= ~clk;
    
    always @(posedge clk) begin
        if ($feof(fd)) begin
            $display("Reached end of drivers file");
            #20
            $finish;
        end
        
        #0.01
        dummy = $fscanf(fd, "%b%d%d%d%d%d%b", 
            mode,
            num_packets,
            num_flits,
            last_flit_bytes,
            M,
            N,
            TREADY
        );
    end

    tg # (
        .WIDTH(`WIDTH)
    ) DUT (
        .clk(clk),
        .rst(rst),

        .mode(mode),
        .num_packets(num_packets),
        .num_flits(num_flits),
        .last_flit_bytes(last_flit_bytes),
        .M(M),
        .N(N),

        //AXI Stream signals
        .TDATA(TDATA),
        .TKEEP(TKEEP),
        .TVALID(TVALID),
        .TREADY(TREADY),
        .TLAST(TLAST)
    );

endmodule
