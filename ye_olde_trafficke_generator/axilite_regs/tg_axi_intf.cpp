#include "ap_int.h"

void tg_axi_intf (
	//Output wires, sent to axilite bus
	ap_uint<16> num_packets_dropped,
	ap_uint<16> &num_packets_dropped_axilite, //Note '&' on axilite signal

	//Input wires, received from axilite bus
	ap_uint<32> &mode, //Note '&' on output wires
	ap_uint<32> mode_axilite,

	ap_uint<32> &num_packets,
	ap_uint<32> num_packets_axilite,

	ap_uint<32> &num_flits,
	ap_uint<32> num_flits_axilite,

	ap_uint<32> &last_flit_bytes,
	ap_uint<32> last_flit_bytes_axilite,

	ap_uint<32> &M,
	ap_uint<32> M_axilite,

	ap_uint<32> &N,
	ap_uint<32> N_axilite
) {
	//Use ap_ctrl_none on the function so that it runs continuously
	#pragma HLS INTERFACE ap_ctrl_none port=return

	//Use ap_none interface on wires
	#pragma HLS INTERFACE ap_none port=num_packets_dropped
	#pragma HLS INTERFACE ap_none port=mode
	#pragma HLS INTERFACE ap_none port=num_packets
	#pragma HLS INTERFACE ap_none port=num_flits
	#pragma HLS INTERFACE ap_none port=last_flit_bytes
	#pragma HLS INTERFACE ap_none port=M
	#pragma HLS INTERFACE ap_none port=N

	//Use s_axilite interface on axilite registers
	#pragma HLS INTERFACE s_axilite port=num_packets_dropped_axilite
	#pragma HLS INTERFACE s_axilite port=mode_axilite
	#pragma HLS INTERFACE s_axilite port=num_packets_axilite
	#pragma HLS INTERFACE s_axilite port=num_flits_axilite
	#pragma HLS INTERFACE s_axilite port=last_flit_bytes_axilite
	#pragma HLS INTERFACE s_axilite port=M_axilite
	#pragma HLS INTERFACE s_axilite port=N_axilite

	//On each clock cycle, simply wire each axilite register to
	//its corresponding wire
	num_packets_dropped_axilite = num_packets_dropped;
	mode = mode_axilite;
	num_packets = num_packets_axilite;
	num_flits = num_flits_axilite;
	last_flit_bytes = last_flit_bytes_axilite;
	M = M_axilite;
	N = N_axilite;
}
