`timescale 1ns / 1ps

/*
torch_arb_tb.v

A testbench for the buffered handshake
*/

`ifdef FROM_STAR_ARB
`include "star_arb.v"
`endif

`define NO_RESET 0
`define ACTIVE_HIGH 1
`define ACTIVE_LOW 2

module star_arb_tb # (
    parameter DATA_WIDTH = 8,
    parameter RESET_TYPE = `ACTIVE_HIGH
);
	reg clk = 0;    
    reg rst = 0;
    
    //Source 0
    reg [DATA_WIDTH -1:0] src0_TDATA = 0;
    reg src0_TVALID = 0;
    wire src0_TREADY;
    reg src0_TLAST = 0;
    
    //Source 1
    reg [DATA_WIDTH -1:0] src1_TDATA = 1;
    reg src1_TVALID = 0;
    wire src1_TREADY;
    reg src1_TLAST = 0;
    
    //Source 2
    reg [DATA_WIDTH -1:0] src2_TDATA = 2;
    reg src2_TVALID = 0;
    wire src2_TREADY;
    reg src2_TLAST = 0;
    
    //Source 3
    reg [DATA_WIDTH -1:0] src3_TDATA = 3;
    reg src3_TVALID = 0;
    wire src3_TREADY;
    reg src3_TLAST = 0;
    
    //Final output
    wire [DATA_WIDTH -1:0] res_TDATA;
    wire res_TVALID;
    reg res_TREADY = 1;
    wire res_TLAST;
    
    //Wires for human-friendly display
    wire [1:0] who = res_TDATA[1:0]; 
    reg [7:0] arb0_cnt = 0;
    reg [7:0] arb1_cnt = 0;
    reg [7:0] arb2_cnt = 0;
    reg [7:0] arb3_cnt = 0;
    
    integer fd, dummy;
    
    initial begin
        $dumpfile("star_arb.vcd");
        $dumpvars;
        $dumplimit(512000);
        
        fd = $fopen("star_arb_drivers.mem", "r");
        if (fd == 0) begin
            $display("Could not open file");
            $finish;
        end
        
        while ($fgetc(fd) != "\n") begin
            if ($feof(fd)) begin
                $display("Error: file is in incorrect format");
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
        
        //#0.01
        //dummy = $fscanf(fd, "%x%b%b%b", );
        #6000
        $finish;
    end
    
    //Quick and dirty test vectors
    always @(posedge clk) begin
        if (src0_TVALID && src0_TREADY) begin
            src0_TDATA <= src0_TDATA + 4;
            src0_TLAST <= ~src0_TLAST;
        end
        if (src1_TVALID && src1_TREADY) begin
            src1_TDATA <= src1_TDATA + 4;
            src1_TLAST <= ~src1_TLAST;
        end
        if (src2_TVALID && src2_TREADY) begin
            src2_TDATA <= src2_TDATA + 4;
            src2_TLAST <= ~src2_TLAST;
        end
        if (src3_TVALID && src3_TREADY) begin
            src3_TDATA <= src3_TDATA + 4;
            src3_TLAST <= ~src3_TLAST;
        end
        
        //src0_TVALID <= $random;
        //src1_TVALID <= $random;
        //src2_TVALID <= $random;
        //src3_TVALID <= $random;
        src0_TVALID <= 1;
        src1_TVALID <= 1;
        src2_TVALID <= 1;
        src3_TVALID <= 1;
        
        res_TREADY <= $random;
        
        //src0_TLAST <= $random;
        //src1_TLAST <= $random;
        //src2_TLAST <= $random;
        //src3_TLAST <= $random;
        
        if (res_TDATA && res_TVALID && res_TLAST) begin
            case (who)
            2'b00:
                arb0_cnt <= arb0_cnt + 1;
            2'b01:
                arb1_cnt <= arb1_cnt + 1;
            2'b10:
                arb2_cnt <= arb2_cnt + 1;
            2'b11:
                arb3_cnt <= arb3_cnt + 1;
            endcase
        end
    end

    //INSTANTIATIONS AND INTERNAL WIRES
    //---------------------------------

    //Wires from arb3 to arb0
    wire arb30_TSTAR;
    
    //Wires from arb0 to arb1
    wire [DATA_WIDTH -1:0] arb01_TDATA;
    wire arb01_TVALID;
    wire arb01_TREADY;
    wire arb01_TLAST;
    wire arb01_TSTAR;
    
    star_arb # (
		.DATA_WIDTH(DATA_WIDTH),
		.RESET_TYPE(RESET_TYPE),
		.START_WITH_STAR(0)
    ) arb_0 (
		.clk(clk),
		.rst(rst),
        
        //This is how the star passed between arbiters
        .take_star(arb30_TSTAR),
        .give_star(arb01_TSTAR),
        
        //Input AXI Stream
		.src_TDATA(src0_TDATA),
		.src_TVALID(src0_TVALID),
		.src_TREADY(src0_TREADY),
		.src_TLAST(src0_TLAST),
        
        //Chained AXI Stream
		.prv_TVALID(1'b0),
        
        //Output AXI Stream
		.res_TDATA(arb01_TDATA),
		.res_TVALID(arb01_TVALID),
		.res_TREADY(arb01_TREADY),
		.res_TLAST(arb01_TLAST)
    );

    //Wires from arb1 to arb2
    wire [DATA_WIDTH-1:0] arb12_TDATA;
    wire arb12_TVALID;
    wire arb12_TREADY;
    wire arb12_TLAST;
    wire arb12_TSTAR;
    
    star_arb # (
		.DATA_WIDTH(DATA_WIDTH),
		.RESET_TYPE(RESET_TYPE),
		.START_WITH_STAR(0)
    ) arb_1 (
		.clk(clk),
		.rst(rst),
        
        //This is how the star passed between arbiters
        .take_star(arb01_TSTAR),
        .give_star(arb12_TSTAR),
        
        //Input AXI Stream
		.src_TDATA(src1_TDATA),
		.src_TVALID(src1_TVALID),
		.src_TREADY(src1_TREADY),
		.src_TLAST(src1_TLAST),
        
        //Chained AXI Stream
		.prv_TDATA(arb01_TDATA),
		.prv_TVALID(arb01_TVALID),
		.prv_TREADY(arb01_TREADY),
		.prv_TLAST(arb01_TLAST),
        
        //Output AXI Stream
		.res_TDATA(arb12_TDATA),
		.res_TVALID(arb12_TVALID),
		.res_TREADY(arb12_TREADY),
		.res_TLAST(arb12_TLAST)
    );

    //Wires from arb2 to arb3
    wire [DATA_WIDTH -1:0] arb23_TDATA;
    wire arb23_TVALID;
    wire arb23_TREADY;
    wire arb23_TLAST;
    wire arb23_TSTAR;
    
    star_arb # (
		.DATA_WIDTH(DATA_WIDTH),
		.RESET_TYPE(RESET_TYPE),
		.START_WITH_STAR(0)
    ) arb_2 (
		.clk(clk),
		.rst(rst),
        
        //This is how the star passed between arbiters
        .take_star(arb12_TSTAR),
        .give_star(arb23_TSTAR),
        
        //Input AXI Stream
		.src_TDATA(src2_TDATA),
		.src_TVALID(src2_TVALID),
		.src_TREADY(src2_TREADY),
		.src_TLAST(src2_TLAST),
        
        //Chained AXI Stream
		.prv_TDATA(arb12_TDATA),
		.prv_TVALID(arb12_TVALID),
		.prv_TREADY(arb12_TREADY),
		.prv_TLAST(arb12_TLAST),
        
        //Output AXI Stream
		.res_TDATA(arb23_TDATA),
		.res_TVALID(arb23_TVALID),
		.res_TREADY(arb23_TREADY),
		.res_TLAST(arb23_TLAST)
    );

    star_arb # (
		.DATA_WIDTH(DATA_WIDTH),
		.RESET_TYPE(RESET_TYPE),
		.START_WITH_STAR(1)
    ) arb_3 (
		.clk(clk),
		.rst(rst),
        
        //This is how the star passed between arbiters
        .take_star(arb23_TSTAR),
        .give_star(arb30_TSTAR),
        
        //Input AXI Stream
		.src_TDATA(src3_TDATA),
		.src_TVALID(src3_TVALID),
		.src_TREADY(src3_TREADY),
		.src_TLAST(src3_TLAST),
        
        //Chained AXI Stream
		.prv_TDATA(arb23_TDATA),
		.prv_TVALID(arb23_TVALID),
		.prv_TREADY(arb23_TREADY),
		.prv_TLAST(arb23_TLAST),
        
        //Output AXI Stream
		.res_TDATA(res_TDATA),
		.res_TVALID(res_TVALID),
		.res_TREADY(res_TREADY),
		.res_TLAST(res_TLAST)
    );
endmodule
