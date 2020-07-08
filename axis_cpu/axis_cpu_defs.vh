//Copyright 2020 Marco Merlini. This file is part of the fpga-bpf project,
//whose license information can be found at 
//https://github.com/UofT-HPRC/fpga-bpf/blob/master/LICENSE


//Please remember to set this as "global include" in Vivado's sources panel

//Programming registers addresses
`define     AXIS_CPU_REG_PROG      4'b0000
`define     AXIS_CPU_REG_INST      4'b0001
`define     AXIS_CPU_REG_JMP_OFF   4'b0010
`define     AXIS_CPU_REG_IMM       4'b0011

/* instruction classes, always compare to instr[7:5] */
`define		AXIS_CPU_LD		3'b000
`define		AXIS_CPU_LDX	3'b001
`define     AXIS_CPU_ST     3'b010
`define     AXIS_CPU_STX    3'b011
`define		AXIS_CPU_ALU	3'b100
`define		AXIS_CPU_JMP	3'b101

/* Specific opdocdes for instructions, always compare to instr[7:4] */
`define     AXIS_CPU_TAX            4'b1100
`define     AXIS_CPU_TXA            4'b1101
`define     AXIS_CPU_SET_JMP_OFF    4'b1110
`define     AXIS_CPU_SET_IMM        4'b1111

/* ld/ldx fields */
//Addressing mode, always compare to instr[4:3]
`define		AXIS_CPU_IMM        2'b00 
`define     AXIS_CPU_STREAM     2'b01
`define		AXIS_CPU_MEM_LOW	2'b10 //Registers 0-7
`define		AXIS_CPU_MEM_HIGH	2'b11 //Registers 8-15


/* st/stx fields */
//Destination type, always compare to instr[4]
`define     AXIS_CPU_ST_MEM     1'b0
`define     AXIS_CPU_ST_STREAM  1'b1

//Jump types, always compare to instr[2:0]
`define		AXIS_CPU_JA		3'b000
`define		AXIS_CPU_JEQ	3'b001
`define		AXIS_CPU_JGT	3'b010
`define		AXIS_CPU_JGE	3'b011
`define		AXIS_CPU_JSET	3'b100
`define		AXIS_CPU_JLAST	3'b101

//Compare-to value select, always get from instr[4]
`define		AXIS_CPU_COMP_IMM	1'b0
`define 	AXIS_CPU_COMP_X		1'b1

//Named constants for A register MUX
`define		A_SEL_IMM 	    3'b000
`define		A_SEL_STREAM 	3'b001
`define		A_SEL_MEM	    3'b010
`define		A_SEL_ALU	    3'b011
`define		A_SEL_X		    3'b100
//Named constants for X register MUX
`define		X_SEL_IMM 	    3'b000 
`define		X_SEL_STREAM    3'b001 
`define		X_SEL_MEM	    3'b010
`define		X_SEL_ALU	    3'b011
`define		X_SEL_A		    3'b100
//A or X select for regfile write
`define		REGFILE_IN_A	1'b0
`define		REGFILE_IN_X	1'b1
//A or X select for stream out
`define     OUT_SEL_A       1'b0
`define     OUT_SEL_X       1'b1
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

//PC value select
`define		PC_SEL_PLUS_1	1'b0
`define		PC_SEL_PLUS_IMM	1'b1

