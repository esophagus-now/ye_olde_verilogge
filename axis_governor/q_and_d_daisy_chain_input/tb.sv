`timescale 1ns / 1ps

// I used the AXI VIP method to simulate this design. This testbench will only
// work if you do the whole rigamarole of drawing up the block diagram and 
// copying in the component name into the testbench. For more details see

// https://github.com/UofT-HPRC/tpdp/blob/master/simulation_idioms/general_method/using_axi_vip.txt

import design_1_axi_vip_0_0_pkg::*;
import axi_vip_pkg::*;


`define CYCLE @(negedge aclk)
`define CYCLES repeat (2) @(negedge aclk)

module tb;


  reg aclk = 0;
  reg aresetn = 0;
  wire [63:0] cmd_tdata;
  wire cmd_tvalid;

	design_1_axi_vip_0_0_mst_t agent;
	xil_axi_prot_t		prot = 0;
	xil_axi_resp_t		resp;

always #5 aclk <= ~aclk;



initial begin
	//Create an agent
	agent = new("master vip agent", DUT.design_1_i.axi_vip_0.inst.IF);
	
	// set tag for agents for easy debug
	agent.set_agent_tag("Master VIP");

	// set print out verbosity level.
	agent.set_verbosity(400);

	//Start the agent
	agent.start_master();
	
	#40
	`CYCLE;
	aresetn <= 1;
	
	//Write to dbg_guv 0, reg address 8 (keep_pausing)
	`CYCLES
	agent.AXI4LITE_WRITE_BURST(0,prot,'h8,resp);
	
	`CYCLE
	agent.AXI4LITE_WRITE_BURST(4,prot,'h0,resp);
	
	//Set data to '1' (enable keep_pausing)
	`CYCLES
	agent.AXI4LITE_WRITE_BURST(0,prot,'h1,resp);
	
	`CYCLE
	agent.AXI4LITE_WRITE_BURST(4,prot,'h0,resp);
	
	//Latch on dbg_guv 0
	`CYCLES
	agent.AXI4LITE_WRITE_BURST(0,prot,'hF,resp);
	
	`CYCLE
	agent.AXI4LITE_WRITE_BURST(4,prot,'h0,resp);
	
	//Write to dbg_guv 1, reg address 2 (inject_TDATA)
	`CYCLES
	agent.AXI4LITE_WRITE_BURST(0,prot,'h12,resp);
	
	`CYCLE
	agent.AXI4LITE_WRITE_BURST(4,prot,'h0,resp);
	
	//Write some silly data
	`CYCLES
	agent.AXI4LITE_WRITE_BURST(0,prot,'hEEF2BABE,resp);
	
	`CYCLE
	agent.AXI4LITE_WRITE_BURST(4,prot,'hFEEDBADB,resp);
	
	//Latch dbug_guv 1
	`CYCLES
	agent.AXI4LITE_WRITE_BURST(0,prot,'h1F,resp);
	
	`CYCLE
	agent.AXI4LITE_WRITE_BURST(4,prot,'h0,resp);
	
	#100
	$finish;
	
end


design_1_wrapper DUT
   (aclk,
    aresetn,
    cmd_tdata,
    cmd_tvalid);


endmodule
