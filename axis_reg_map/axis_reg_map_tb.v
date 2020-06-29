`timescale 1ns / 1ps

`ifdef ICARUS_VERILOG
`include "axis_reg_map.v"
`endif

`include "macros.vh"

module dbg_guv_tb # (
    parameter REG_ADDR_WIDTH = 4,
    parameter ADDR_WIDTH = 12,
    parameter [ADDR_WIDTH -1:0] ADDR = 0, //Set this to be different for each 
    parameter RESET_TYPE = `NO_RESET,
    parameter PIPE_STAGE = 1
);
	reg clk = 0;    
    reg rst = 0;
    
    //Input command stream
    reg [31:0] cmd_in_TDATA = 0;
    reg cmd_in_TVALID = 0;
    
    //All the controllers are daisy-chained. If in incoming command is not for
    //this controller, send it to the next one
    wire [31:0] cmd_out_TDATA;
    wire cmd_out_TVALID;
    
    //Register update outputs, used by whatever is instantiating this module
    wire [REG_ADDR_WIDTH -1:0] reg_addr0;
    wire [31:0] reg_data0;
    wire reg_strb0;
    wire [REG_ADDR_WIDTH -1:0] reg_addr1;
    wire [31:0] reg_data1;
    wire reg_strb1;
    wire [REG_ADDR_WIDTH -1:0] reg_addr2;
    wire [31:0] reg_data2;
    wire reg_strb2;
    
    integer fd, dummy;
    
    initial begin
        $dumpfile("axis_reg_map.vcd");
        $dumpvars;
        $dumplimit(2048000);
                
        fd = $fopen("axis_reg_map_drivers.mem", "r");
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
        dummy = $fscanf(fd, "%x%b", cmd_in_TDATA, cmd_in_TVALID);
        //Skip comments at end of line
        while (!$feof(fd) && $fgetc(fd) != "\n") ;
    end

    wire [31:0] cmd_out_data1;
    wire cmd_out_vld_1;

    wire [31:0] cmd_out_data2;
    wire cmd_out_vld_2;
axis_reg_map # (
    .REG_ADDR_WIDTH(REG_ADDR_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH),
    .ADDR(0), //Set this to be different for each 
    .RESET_TYPE(RESET_TYPE),
    .PIPE_STAGE(PIPE_STAGE)
) DUT0 (
    .clk(clk),
    .rst(rst),
    
    //Input command stream
    .cmd_in_TDATA(cmd_in_TDATA),
    .cmd_in_TVALID(cmd_in_TVALID),
    
    //All the reg_maps are daisy-chained. 
    .cmd_out_TDATA(cmd_out_data1),
    .cmd_out_TVALID(cmd_out_vld_1),
    
    //Register update outputs, used by whatever is instantiating this module
    .reg_addr(reg_addr0),
    .reg_data(reg_data0),
    .reg_strb(reg_strb0)
);

axis_reg_map # (
    .REG_ADDR_WIDTH(REG_ADDR_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH),
    .ADDR(1), //Set this to be different for each 
    .RESET_TYPE(RESET_TYPE),
    .PIPE_STAGE(PIPE_STAGE)
) DUT1 (
    .clk(clk),
    .rst(rst),
    
    //Input command stream
    .cmd_in_TDATA(cmd_out_data1),
    .cmd_in_TVALID(cmd_out_vld_1),
    
    //All the reg_maps are daisy-chained. 
    .cmd_out_TDATA(cmd_out_data2),
    .cmd_out_TVALID(cmd_out_vld_2),
    
    //Register update outputs, used by whatever is instantiating this module
    .reg_addr(reg_addr1),
    .reg_data(reg_data1),
    .reg_strb(reg_strb1)
);

axis_reg_map # (
    .REG_ADDR_WIDTH(REG_ADDR_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH),
    .ADDR(2), //Set this to be different for each 
    .RESET_TYPE(RESET_TYPE),
    .PIPE_STAGE(PIPE_STAGE)
) DUT2 (
    .clk(clk),
    .rst(rst),
    
    //Input command stream
    .cmd_in_TDATA(cmd_out_data2),
    .cmd_in_TVALID(cmd_out_vld_2),
    
    //All the reg_maps are daisy-chained. 
    .cmd_out_TDATA(cmd_out_TDATA),
    .cmd_out_TVALID(cmd_out_TVALID),
    
    //Register update outputs, used by whatever is instantiating this module
    .reg_addr(reg_addr2),
    .reg_data(reg_data2),
    .reg_strb(reg_strb2)
);

endmodule
