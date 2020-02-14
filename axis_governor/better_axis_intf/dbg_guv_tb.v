`timescale 1ns / 1ps

/*
dbg_guv_tb.v

A testbench for the AXIS governor controller.

In case you're wondering, no, I don't painstakingly write everything in my 
testbenches by hand. I mostly copy and paste and use Geany's regex find/replace 
tool.

For example,

Find: 
    .* (\w+)\,

Replace:
    \t\t\.\1\(\1\)\,
    
is really handy for doing up module instantiations
*/ 

`ifdef ICARUS_VERILOG
`include "dbg_guv.v"
`endif

`include "macros.vh"

module dbg_guv_tb # (
    parameter DATA_WIDTH = 32,
    parameter DEST_WIDTH = 16,
    parameter ID_WIDTH = 16,
    parameter CNT_SIZE = 16,
    parameter ADDR_WIDTH = 10, //This gives 1024 simultaneous debug cores
    parameter ADDR = 0, //Set this to be different for each 
    parameter RESET_TYPE = `ACTIVE_HIGH,
    parameter STICKY_MODE = 0, //If 1, latching registers does not reset them
    parameter PIPE_STAGE = 1 //This causes a delay on cmd_out in case fanout is
                             //an issue
);
	reg clk = 0;    
    reg rst = 0;
    
    //Input command stream
    //This may be a bad decision, but I decided the command width should match
    //the inject data width.
    //How does this work if you have a bunch of streams of different sizes that
    //you want to debug? Also, what about the rr_tree in that case?
    //Also, this core cannot assert backpressure
    reg [DATA_WIDTH -1:0] cmd_in_TDATA = 0;
    reg cmd_in_TVALID = 0;
    
    //All the controllers are daisy-chained. If in incoming command is not for
    //this controller, send it to the next one
    wire [DATA_WIDTH -1:0] cmd_out_TDATA;
    wire cmd_out_TVALID;
    
    //Also,since this module is intended to wrap around axis_governor, we need
    //to provide access to its ports through this one.
    
    //Input1 AXI Stream.
    reg [DATA_WIDTH-1:0] in1_TDATA = 0;
    reg in1_TVALID = 1;
    wire in1_TREADY;
    reg [DATA_WIDTH/8 -1:0] in1_TKEEP = 0;
    reg [DEST_WIDTH -1:0] in1_TDEST = 0;
    reg [ID_WIDTH -1:0] in1_TID;
    reg in1_TLAST = 0;
    
    //Input2 AXI Stream.
    reg [DATA_WIDTH-1:0] in2_TDATA = 1;
    reg in2_TVALID = 1;
    wire in2_TREADY;
    reg [DATA_WIDTH/8 -1:0] in2_TKEEP = 1;
    reg [DEST_WIDTH -1:0] in2_TDEST = 1;
    reg [ID_WIDTH -1:0] in2_TID = 1;
    reg in2_TLAST = 0;
    
    //Output1 AXI Stream.
    wire [DATA_WIDTH-1:0] out1_TDATA;
    wire out1_TVALID;
    reg out1_TREADY = 1;
    wire [DATA_WIDTH/8 -1:0] out1_TKEEP;
    wire [DEST_WIDTH -1:0] out1_TDEST;
    wire [ID_WIDTH -1:0] out1_TID;
    wire out1_TLAST;
    
    //Output2 AXI Stream.
    wire [DATA_WIDTH-1:0] out2_TDATA;
    wire out2_TVALID;
    reg out2_TREADY = 1;
    wire [DATA_WIDTH/8 -1:0] out2_TKEEP;
    wire [DEST_WIDTH -1:0] out2_TDEST;
    wire [ID_WIDTH -1:0] out2_TID;
    wire out2_TLAST;
    
    //Log1 AXI Stream. 
    //This core takes care of concatting the sidechannels into the data part
    //of the flit
    `sim_axis_l(log_catted1, DATA_WIDTH + DATA_WIDTH/8 + 1 + DEST_WIDTH + ID_WIDTH);
    
    //Log2 AXI Stream. 
    //This core takes care of concatting the sidechannels into the data part
    //of the flit
    `sim_axis_l(log_catted2, DATA_WIDTH + DATA_WIDTH/8 + 1 + DEST_WIDTH + ID_WIDTH);
    
    integer fd, dummy;
    
    initial begin
        $dumpfile("dbg_guv.vcd");
        $dumpvars;
        $dumplimit(512000);
                
        fd = $fopen("dbg_guv_drivers.mem", "r");
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
        
        #0.01
        dummy = $fscanf(fd, "%x%b%b%b", idata, idata_vld, odata_rdy, rst);
    end



endmodule
