//Copyright 2020 Marco Merlini. This file is part of the fpga-bpf project,
//whose license information can be found at 
//https://github.com/UofT-HPRC/fpga-bpf/blob/master/LICENSE


//Please remember to set this as "global include" in Vivado's sources panel

`ifndef AXIS_CPU_DEFS_VH
`define AXIS_CPU_DEFS_VH 1

/* instruction classes */
`define		AXIS_CPU_LD		3'b000
`define		AXIS_CPU_LDX	3'b001
`define		AXIS_CPU_ST		3'b010
`define		AXIS_CPU_STX	3'b011
`define		AXIS_CPU_ALU	3'b100
`define		AXIS_CPU_JMP	3'b101
`define		AXIS_CPU_MISC	3'b111

/* ld/ldx fields */
//Addressing mode
`define		AXIS_CPU_IMM 	3'b000 
`define		AXIS_CPU_MEM	3'b011
//Named constants for A register MUX
`define		A_SEL_IMM 	3'b000
`define		A_SEL_MEM	3'b011
`define		A_SEL_ALU	3'b110
`define		A_SEL_X		3'b111
//Named constants for X register MUX
`define		X_SEL_IMM 	3'b000 
`define		X_SEL_MEM	3'b011
`define		X_SEL_A		3'b111
//A or X select for regfile write
`define		REGFILE_IN_A	1'b0
`define		REGFILE_IN_X	1'b1
//ALU operand B select
`define		ALU_B_SEL_IMM	1'b0
`define		ALU_B_SEL_X		1'b1
//ALU operation select. Deliberately designed so one-cycle ops have leading 0
`define		AXIS_CPU_ADD	4'b0000
`define		AXIS_CPU_SUB	4'b0001
`define		AXIS_CPU_XOR	4'b0010
`define		AXIS_CPU_OR		4'b0011
`define		AXIS_CPU_AND	4'b0100
`define		AXIS_CPU_LSH	4'b0101
`define		AXIS_CPU_RSH	4'b0110
`define		AXIS_CPU_NOT	4'b0111
`define		AXIS_CPU_MUL	4'b1000
`define		AXIS_CPU_DIV	4'b1001
`define		AXIS_CPU_MOD	4'b1010

//Jump types
`define		AXIS_CPU_JA		3'b000
`define		AXIS_CPU_JEQ	3'b001
`define		AXIS_CPU_JGT	3'b010
`define		AXIS_CPU_JGE	3'b011
`define		AXIS_CPU_JSET	3'b100
`define		AXIS_CPU_JLAST	3'b101

//Compare-to value select
`define		AXIS_CPU_COMP_IMM	1'b0
`define 	AXIS_CPU_COMP_X		1'b1
//PC value select
`define		PC_SEL_PLUS_1	2'b00
`define		PC_SEL_PLUS_JT	2'b01
`define		PC_SEL_PLUS_JF	2'b10
`define		PC_SEL_PLUS_IMM	2'b11


`endif
