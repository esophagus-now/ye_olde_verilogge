//Copyright 2020 Marco Merlini. This file is part of the fpga-bpf project,
//whose license information can be found at 
//https://github.com/UofT-HPRC/fpga-bpf/blob/master/LICENSE

/* BIG LIST OF TODOS
    
[x] Edit and rename bpf_defs.vh to match new ISA
[x] Add MUL/DIV/MOD into ALU with proper handshaking
[x] Add immediate and jump offset memory to datapath
[x] Instantiate instruction memory in datapath
[x] Implement instructions for setting imm and jmp_off
[x] Implement instructions for reading/writing to stream 
    -> Include "PASS" instruction?
[x] Add TLAST register and special jump type for it
[x] Add logic to program instruction and immediate memory from axis_reg_map
[ ] Add in axis_reg_map register for single-stepping (gate inst_rd_en?)
[ ] Add code to send register values over debug stream
[ ] Update sims

*/

`timescale 1ns / 1ps

`ifdef ICARUS_VERILOG
`include "macros.vh"
`include "controller.v"
`include "datapath.v"
`include "axis_reg_map.v"
`default_nettype none
`endif

module axis_cpu # (
    parameter CODE_ADDR_WIDTH = 10,
    parameter REG_ADDR_WIDTH = 4, //Seems good enough
    parameter CPU_ID_WIDTH = 12,
    parameter [CPU_ID_WIDTH-1:0] CPU_ID = 0, //Basically like a base address, used for AXIS register map
    parameter PESS = 0
) (
    input wire clk,
    input wire rst,

    //Interface to outside world
    `in_axis_l(din, 32),
    `out_axis_l(dout, 32),
    
    //Programming ports
    input wire [31:0] cmd_in_TDATA,
    input wire cmd_in_TVALID,
    
    output wire [31:0] cmd_out_TDATA,
    output wire cmd_out_TVALID,
    
    //Debug ports
    `out_axis_l(dbg, 32)
);
    
    reg programming = 0; //If 1, then we are in the programming state. The
                         //CPU should be halted, and we should be enabling
                         //the register map to write jump offsets, immediates,
                         //and instructions
    //When in programming mode, these registers keep track of where to push
    //the next values in our various memories
    reg [CODE_ADDR_WIDTH -1:0] inst_mem_wr_addr = 0;
    wire inst_mem_wr_en;
    reg [3:0] jmp_off_wr_addr = 0;
    wire jmp_off_wr_en;
    reg [3:0] imm_wr_addr = 0;
    wire imm_wr_en;
    
    wire [REG_ADDR_WIDTH -1:0] reg_addr;
    wire reg_strb;
    wire [31:0] reg_data;
    
    //Instantiate our AXIS register map
    axis_reg_map # (
        .REG_ADDR_WIDTH(REG_ADDR_WIDTH),
        .ADDR_WIDTH(CPU_ID_WIDTH),
        .ADDR(CPU_ID), //Set this to be different for each 
        .RESET_TYPE(`ACTIVE_HIGH),
        .PIPE_STAGE(PESS || (CPU_ID%2 == 1))
    ) regmap (
		.clk(clk),
		.rst(rst),
        
        //Input command stream
		.cmd_in_TDATA(cmd_in_TDATA),
		.cmd_in_TVALID(cmd_in_TVALID),
        
        //All the reg_maps are daisy-chained. 
		.cmd_out_TDATA(cmd_out_TDATA),
		.cmd_out_TVALID(cmd_out_TVALID),
        
		//Register update outputs used by whatever is instantiating this module
		.reg_addr(reg_addr),
		.reg_data(reg_data),
		.reg_strb(reg_strb)
    );
    
    //Manage our programming state and registers
    always @(posedge clk) begin
        if (rst) begin
            programming <= 0;
        end else begin
            if (reg_strb) begin
                case (reg_addr)
                `AXIS_CPU_REG_PROG: begin
                    programming <= reg_data[0];
                    inst_mem_wr_addr <= 0;
                    jmp_off_wr_addr <= 0;
                    imm_wr_addr <= 0;
                end
                `AXIS_CPU_REG_INST: begin
                    //The enables are taken care of below this always block
                    inst_mem_wr_addr <= inst_mem_wr_addr + 1;
                end
                `AXIS_CPU_REG_JMP_OFF: begin
                    jmp_off_wr_addr <= jmp_off_wr_addr + 1;
                end
                `AXIS_CPU_REG_IMM: begin
                    imm_wr_addr <= imm_wr_addr + 1;
                end
                endcase
            end
        end
    end
    //Manage write enables
    assign inst_mem_wr_en = (reg_addr == `AXIS_CPU_REG_INST) && reg_strb;
    assign jmp_off_wr_en = (reg_addr == `AXIS_CPU_REG_JMP_OFF) && reg_strb;
    assign imm_wr_en = (reg_addr == `AXIS_CPU_REG_IMM) && reg_strb;
    
    wire hold_in_rst = programming;
    
    //Controller outputs
    wire [1:0] PC_sel; 
    wire PC_en;
    wire inst_rd_en;
    wire B_sel;
    wire [3:0] ALU_sel;
    wire ALU_en;
    wire addr_sel;
    wire regfile_sel; //Whether A or X is written to the regfile
    wire regfile_wr_en;
    wire [3:0] regfile_wr_addr;
    wire [3:0] utility_addr; //Used for setting jmp_off_sel or imm_sel
    wire jmp_off_sel_en;
    wire imm_sel_en;
    wire [2:0] A_sel;
    wire A_en;
    wire [2:0] X_sel;
    wire X_en;
    wire ALU_ack;
    wire last_en;
    wire last_out; //Seems kind of silly to take this as input only to
                         //to turn around and put in on dout_TLAST
    wire last;
    
    wire [CODE_ADDR_WIDTH -1:0] jmp_correction;
    
    //Datapath outputs
    wire eq;
    wire gt;
    wire ge;
    wire set;
    wire ALU_vld;
    wire [7:0] instr;
    
    controller # (
        .CODE_ADDR_WIDTH(CODE_ADDR_WIDTH),
        .PESS(PESS)
    ) ctrl (
        .clk(clk),
        .rst(rst || hold_in_rst),
        .eq(eq),
        .gt(gt),
        .ge(ge),
        .set(set),
        .ALU_vld(ALU_vld),
        .din_TVALID(din_TVALID),
        .din_TREADY(din_TREADY),
        .dout_TVALID(dout_TVALID),
        .dout_TREADY(dout_TREADY),
        .instr_in(instr),
        .inst_rd_en(inst_rd_en),
        .PC_en(PC_en),
        .B_sel(B_sel),
        .ALU_sel(ALU_sel),
        .ALU_en(ALU_en),
        .regfile_wr_addr(regfile_wr_addr),
        .regfile_wr_en(regfile_wr_en),
        .regfile_sel(regfile_sel),
        .PC_sel(PC_sel), 
        .A_sel(A_sel),
        .A_en(A_en),
        .X_sel(X_sel),
        .X_en(X_en),
        .last_out(last_out),
        .last_en(last_en),
        .last(last),
        .ALU_ack(ALU_ack),
        .jmp_correction(jmp_correction)
    );

    datapath # (
        .CODE_ADDR_WIDTH(CODE_ADDR_WIDTH)
    ) dpath (
        .clk(clk),
        .rst(rst || hold_in_rst),
        .A_sel(A_sel),
        .A_en(A_en),
        .X_sel(X_sel),
        .X_en(X_en),
        .PC_sel(PC_sel),
        .PC_en(PC_en),
        .inst_rd_en(inst_rd_en),
        .instr(instr),
        .B_sel(B_sel),
        .ALU_sel(ALU_sel),
        .ALU_en(ALU_en),
        .eq(eq),
        .gt(gt),
        .ge(ge),
        .set(set),
        .ALU_vld(ALU_vld),
        .ALU_ack(ALU_ack),
        .din_TDATA(din_TDATA),
        .din_TLAST(din_TLAST),
        .dout_TDATA(dout_TDATA),
        .dout_TLAST(dout_TLAST),
        .last_out(last_out),
        .last_en(last_en),
        .last(last),
        .utility_addr(utility_addr),
        .jmp_off_sel_en(jmp_off_sel_en),
        .imm_sel_en(imm_sel_en),
        .regfile_sel(regfile_sel),
        .regfile_wr_addr(regfile_wr_addr),
        .regfile_wr_en(regfile_wr_en),
        .jmp_correction(jmp_correction),
        
        //These are for reprogramming the immediates table
		.imm_wr_data(reg_data),
		.imm_wr_addr(imm_wr_addr),
		.imm_wr_en(imm_wr_en),
        
        //These are for reprogramming the jump offsets table
		.jmp_off_wr_data(reg_data[7:0]),
		.jmp_off_wr_addr(jmp_off_wr_addr),
		.jmp_off_wr_en(jmp_off_wr_en),
        
        //Signals for writing new instructions
		.inst_mem_wr_data(reg_data[7:0]),
		.inst_mem_wr_addr(inst_mem_wr_addr),
		.inst_mem_wr_en(inst_mem_wr_en)
    );

endmodule

`undef localparam
