`ifdef ICARUS_VERILOG
`define localparam parameter
`else /*For Vivado*/
`define localparam localparam
`endif

`define logic reg

`define CLOG2(x) (\
    (((x) <= 1) ? 0 : \
    (((x) <= 2) ? 1 : \
    (((x) <= 4) ? 2 : \
    (((x) <= 8) ? 3 : \
    (((x) <= 16) ? 4 : \
    (((x) <= 32) ? 5 : \
    (((x) <= 64) ? 6 : \
    (((x) <= 128) ? 7 : \
    (((x) <= 256) ? 8 : \
    (((x) <= 512) ? 9 : \
    (((x) <= 1024) ? 10 : \
    (((x) <= 2048) ? 11 : \
    (((x) <= 4096) ? 12 : \
    (((x) <= 8192) ? 13 : \
    (((x) <= 16384) ? 14 : \
    (((x) <= 32768) ? 15 : \
    (((x) <= 65536) ? 16 : \
    -1))))))))))))))))))

//Helper macros to declare AXI Streams nicely in Verilog
//The "_reg" versions are because Verilog forces you to use reg in always
//blocks (which is really awful!)
//The "sim_" versions are used when writing testbenches
`define in_axis(name, width) \
    input wire [width -1:0] name``_TDATA,\
    input wire name``_TVALID,\
    output wire name``_TREADY

`define in_axis_reg(name, width) \
    input wire [width -1:0] name``_TDATA,\
    input wire name``_TVALID,\
    output reg name``_TREADY
    
`define out_axis(name, width) \
    output wire [width -1:0] name``_TDATA,\
    output wire name``_TVALID,\
    input wire name``_TREADY

`define out_axis_reg(name, width) \
    output reg [width -1:0] name``_TDATA,\
    output reg name``_TVALID,\
    input wire name``_TREADY
    
`define wire_axis(name, width) \
    wire [width -1:0] name``_TDATA;\
    wire name``_TVALID;\
    wire name``_TREADY
    
`define sim_in_axis(name, width) \
    reg [width -1:0] name``_TDATA = 0;\
    reg name``_TVALID = 0;\
    wire name``_TREADY;\
    reg name``_TREADY_exp = 0
    
`define sim_out_axis(name, width) \
    wire [width -1:0] name``_TDATA;\
    reg [width -1:0] name``_TDATA_exp;\
    wire name``_TVALID;\
    reg name``_TVALID_exp = 0;\
    reg name``_TREADY = 1

`define ports_axis(name) name``_TDATA, name``_TVALID, name``_TREADY

`define inst_axis(lname, rname) \
        .lname``_TDATA(rname``_TDATA),\
        .lname``_TVALID(rname``_TVALID),\
        .lname``_TREADY(rname``_TREADY)

//Same, but with TLAST signal
`define in_axis_l(name, width) \
    `in_axis(name, width),\
    input wire name``_TLAST
    
`define in_axis_l_reg(name, width) \
    `in_axis_reg(name, width),\
    input wire name``_TLAST

`define out_axis_l(name, width) \
    `out_axis(name, width),\
    output wire name``_TLAST

`define out_axis_l_reg(name, width) \
    `out_axis_reg(name, width),\
    output reg name``_TLAST

`define wire_axis_l(name, width) \
    `wire_axis(name, width);\
    wire name``_TLAST
    
`define sim_in_axis_l(name, width) \
    `sim_in_axis(name, width);\
    reg name``_TLAST = 0
    
`define sim_out_axis_l(name, width) \
    `sim_out_axis(name, width);\
    wire name``_TLAST;\
    reg name``_TLAST_exp = 0

`define ports_axis_l(name) `ports_axis(name), name``_TLAST

`define inst_axis_l(lname, rname) \
        `inst_axis(lname, rname),\
        .lname``_TLAST(rname``_TLAST)

//Same, but with TKEEP signal
`define in_axis_k(name, width) \
    `in_axis(name, width),\
    input wire [(width/8) -1:0] name``_TKEEP
    
`define in_axis_k_reg(name, width) \
    `in_axis_reg(name, width),\
    input wire [(width/8) -1:0] name``_TKEEP

`define out_axis_k(name, width) \
    `out_axis(name, width),\
    output wire [(width/8) -1:0] name``_TKEEP

`define out_axis_k_reg(name, width) \
    `out_axis_reg(name, width),\
    output reg [(width/8) -1:0] name``_TKEEP

`define wire_axis_k(name, width) \
    `wire_axis(name, width);\
    wire [(width/8) -1:0] name``_TKEEP
    
`define sim_in_axis_k(name, width) \
    `sim_in_axis(name, width);\
    reg [(width/8) -1:0] name``_TKEEP = 0
    
`define sim_out_axis_k(name, width) \
    `sim_out_axis(name, width);\
    wire [(width/8) -1:0] name``_TKEEP;\
    reg [(width/8) -1:0] name``_TKEEP_exp = 0

`define ports_axis_k(name) `ports_axis(name), name``_TKEEP

`define inst_axis_k(lname, rname) \
        `inst_axis(lname, rname),\
        .lname``_TKEEP(rname``_TKEEP)

//Same, but with TLAST and TKEEP signals
`define in_axis_kl(name, width) \
    `in_axis_l(name, width),\
    input wire [(width/8) -1:0] name``_TKEEP
`define in_axis_lk(n, w) `in_axis_kl(n, w)

`define in_axis_kl_reg(name, width) \
    `in_axis_l_reg(name, width),\
    input wire [(width/8) -1:0] name``_TKEEP
`define in_axis_lk_reg(n, w) `in_axis_kl_reg(n, w)

`define out_axis_kl(name, width) \
    `out_axis_l(name, width),\
    output wire [(width/8) -1:0] name``_TKEEP
`define out_axis_lk(n, w) `out_axis_kl(n, w)

`define out_axis_kl_reg(name, width) \
    `out_axis_l_reg(name, width),\
    output reg [(width/8) -1:0] name``_TKEEP
`define out_axis_lk_reg(n, w) `out_axis_kl_reg(n, w)

`define wire_axis_kl(name, width) \
    `wire_axis_l(name, width);\
    wire [(width/8) -1:0] name``_TKEEP
`define wire_axis_lk(n, w) `wire_axis_kl(n, w)
    
`define sim_in_axis_kl(name, width) \
    `sim_in_axis_l(name, width);\
    reg [(width/8) -1:0] name``_TKEEP = 0
`define sim_in_axis_lk(n, w) `sim_in_axis_kl(n, w)
    
`define sim_out_axis_kl(name, width) \
    `sim_out_axis_l(name, width);\
    wire [(width/8) -1:0] name``_TKEEP;\
    reg [(width/8) -1:0] name``_TKEEP_exp = 0
`define sim_out_axis_lk(n, w) `sim_out_axis_kl(n, w)

`define ports_axis_kl(name) `ports_axis_l(name), name``_TKEEP
`define ports_axis_lk(name) `ports_axis_kl(name)

`define inst_axis_kl(lname, rname) \
        `inst_axis_l(lname, rname),\
        .lname``_TKEEP(rname``_TKEEP)
`define inst_axis_lk(lname, rname) `inst_axis_kl(lname, rname)

//Some helper macros to neaten up code dealing with AXI Streams VALID and READY
`define axis_flit(name) (name``_TVALID && name``_TREADY)
`define axis_last(name) (name``_TVALID && name``_TREADY && name``_TLAST)

`define NO_RESET 0
`define ACTIVE_HIGH 1
`define ACTIVE_LOW 2

`define genif generate if
`define else_genif end else if
`define else_gen end else begin
`define endgen end endgenerate

//Common construct I use in my desgins
`define wire_rst_sig \
    wire rst_sig; \
`genif (RESET_TYPE == `ACTIVE_HIGH) begin \
    assign rst_sig = rst; \
end else begin \
    assign rst_sig = ~rst; \
`endgen \
wire unused_dummy_in_wire_rst_sig_macro

//This makes the ternary operator look a little more friendly
//"if" was already taken
`define si(x) ((x) ?
`define prendre (
`define autrement ) : (
`define fin ))


//For making self-testing testbenches. 
//In your testbench, place 
//
//  auto_tb_decls;
//
//Outside all initial/always blocks, and it's best to put the declarations
//at the top.
//
//Use 
//
//  open_drivers_file("my_drivers.mem");
//
//inside of an initial block.
//
//Then we run two loops. The first is for reading the drivers file. The 
//second is where you can run automatic tests. Outside all initial always
//blocks, place:
//
//  `auto_tb_read_loop(my_testbench_clk)
//      `dummy = $fscanf(`fd, "%h%b%b...", my_sig_1, my_sig_2, expected_my_sig_2, ...);
//  `auto_tb_read_end
//
//  `auto_tb_test_loop(my_testbench_clk)
//      `test(my_sig_2, expected_my_sig_2);
//      //... other tests ...
//  `auto_tb_test_end
//
//Unfortunately, I wasn't able to find a workaround to hide `fd and `dummy

`define auto_tb_decls \
    integer auto_tb_fd, auto_tb_dummy;\
    integer auto_tb_line = 0;  \
    integer auto_tb_incr = 0
    
`define open_drivers_file(f) \
        auto_tb_fd = $fopen(f, "r");\
        if (auto_tb_fd == 0) begin\
            $display("Could not open file %s", f);\
            $finish;\
        end\
        \
        while ($fgetc(auto_tb_fd) != "\n") begin\
            if ($feof(auto_tb_fd)) begin\
                $display("Error: file is in incorrect format");\
                $display("Must be nonempty, and first line is always skipped and treated as comments");\
                $finish;\
            end\
        end\
        auto_tb_incr = 1

`define test(x,y) \
        if ($time != 0 && !(x === y)) begin \
            $display("TB ERROR: line %d, variable x: expected %h but got %h", auto_tb_line, y, x);\
            #5 $finish;\
        end\
        auto_tb_dummy = 1

`define fd      auto_tb_fd
`define dummy   auto_tb_dummy

`define auto_tb_read_loop(clk)\
    always @(posedge clk) begin\
        if ($feof(auto_tb_fd)) begin\
            $display("Successfully completed drivers file");\
            #20\
            $finish;\
        end\
        /* Add line increment then reset the increment */ \
        auto_tb_line = auto_tb_line + auto_tb_incr; \
        auto_tb_incr = 0; \
        #0.01

`define auto_tb_read_end\
        /*Skip comments at end of line*/\
        while (!$feof(auto_tb_fd) && $fgetc(auto_tb_fd) != "\n") ;\
        auto_tb_incr = auto_tb_incr + 1;\
        /* Do our best to count blank lines */\
        while(!$feof(auto_tb_fd) && auto_tb_dummy != -1) begin \
            auto_tb_dummy = $fgetc(auto_tb_fd);\
            if (auto_tb_dummy == "\n") begin \
                auto_tb_incr = auto_tb_incr + 1; \
            end else if (auto_tb_dummy != " " && auto_tb_dummy != "\t") begin \
                auto_tb_dummy = $ungetc(auto_tb_dummy, auto_tb_fd); \
                auto_tb_dummy = -1; \
            end \
        end \
    end

`define auto_tb_test_loop(clk)\
    always @(posedge clk) begin\

`define auto_tb_test_end\
    end
