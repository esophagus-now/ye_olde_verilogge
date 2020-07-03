//Copyright 2020 Marco Merlini. This file is part of the fpga-bpf project,
//whose license information can be found at 
//https://github.com/UofT-HPRC/fpga-bpf/blob/master/LICENSE


//Please remember to set this as "global include" in Vivado's sources panel

/* instruction classes, always compare to instr[7:5] */
`define		AXIS_CPU_LD		3'b000
`define		AXIS_CPU_LDX	3'b001
`define		AXIS_CPU_ALU	3'b100
`define		AXIS_CPU_JMP	3'b101

/* Specific opdocdes for instructions, always compare to instr[7:4] */
//Very subtle kludge here: notice that ST and OUT (and STX and OUTX) share
//a prefix of 010 (and 011). This is used inside the stage2 module to say
//whether A or X is read
`define		AXIS_CPU_ST		        4'b0100
`define		AXIS_CPU_OUT	        4'b0101
`define		AXIS_CPU_STX	        4'b0110
`define		AXIS_CPU_OUTX	        4'b0111
`define     AXIS_CPU_TAX            4'b1100
`define     AXIS_CPU_TXA            4'b1101
`define     AXIS_CPU_SET_JMP_OFF    4'b1110
`define     AXIS_CPU_SET_IMM        4'b1111

/* ld/ldx fields */
//Addressing mode, always compare to instr[2:0]
`define		AXIS_CPU_IMM 	3'b000 
`define		AXIS_CPU_MEM	3'b001
`define     AXIS_CPU_STREAM 3'b010

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
`define		A_SEL_MEM	    3'b011
`define		A_SEL_ALU	    3'b110
`define		A_SEL_X		    3'b111
//Named constants for X register MUX
`define		X_SEL_IMM 	    3'b000 
`define		X_SEL_STREAM    3'b001 
`define		X_SEL_MEM	    3'b011
`define		X_SEL_ALU	    3'b110
`define		X_SEL_A		    3'b111
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

//PC value select
`define		PC_SEL_PLUS_1	1'b0
`define		PC_SEL_PLUS_IMM	1'b1

