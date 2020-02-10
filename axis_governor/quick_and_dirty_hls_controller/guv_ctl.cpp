#include "ap_int.h"
#include "guv_ctl.h"

void guv_ctl (
	//AXI Lite inputs
	ap_uint<1> latch,
	ap_uint<10> inject_data,
	ap_uint<1> inject,
	ap_uint<CNT_SIZE> log_cnt,
	ap_uint<CNT_SIZE> drop_cnt,
	ap_uint<1> pause,

	//Raw outputs
	ap_uint<1> &pause_out,
	ap_uint<1> &drop_out,
	ap_uint<1> &log_out,
	ap_uint<10> &inject_TDATA,
	ap_uint<1> &inject_TVALID,
	ap_uint<1> inject_TREADY,
	//Quick and dirty: signals to say that a flit has moved
	ap_uint<1> mst_flit_sent,
	ap_uint<1> log_flit_rcvd
) {
#pragma HLS INTERFACE s_axilite port=latch
#pragma HLS INTERFACE s_axilite port=inject_data
#pragma HLS INTERFACE s_axilite port=inject
#pragma HLS INTERFACE s_axilite port=log_cnt
#pragma HLS INTERFACE s_axilite port=drop_cnt
#pragma HLS INTERFACE s_axilite port=pause

#pragma HLS INTERFACE ap_ctrl_none port=return

#pragma HLS INTERFACE ap_none port=pause_out
#pragma HLS INTERFACE ap_none port=drop_out
#pragma HLS INTERFACE ap_none port=log_out
#pragma HLS INTERFACE ap_none port=inject_TDATA
#pragma HLS INTERFACE ap_none port=inject_TVALID
#pragma HLS INTERFACE ap_none port=inject_TREADY
#pragma HLS INTERFACE ap_none port=mst_flit_sent
#pragma HLS INTERFACE ap_none port=log_flit_rcvd

	static ap_uint<1> platch = 0;

	static ap_uint<1> pause_i = 0;
	static ap_uint<CNT_SIZE> log_cnt_i = 0;
	static ap_uint<CNT_SIZE> drop_cnt_i = 0;
	static ap_uint<1> inject_i = 0;

	//C++ compiler didn't like "0" and "1" in the code since their type
	//was ambiguous
	ap_uint<1> const zero = 0;
	ap_uint<CNT_SIZE> const zero_wide = 0;
	ap_uint<1> const one = 1;
	ap_uint<CNT_SIZE> const one_wide = 1;

	pause_out = ((log_cnt_i != zero_wide) || (drop_cnt_i != zero_wide)) ? zero : pause_i;
	log_out = (log_cnt_i != zero_wide) ? one : zero;
	drop_out = (drop_cnt_i != zero_wide) ? one : zero;
	inject_TVALID = inject_i;
	inject_TDATA = inject_data;

	if (latch == 1 && platch == 0) { //Find rising edge of latch
		pause_i = pause;
		log_cnt_i = log_cnt;
		drop_cnt_i = drop_cnt;
		inject_i = inject;
	} else {
		log_cnt_i = (log_cnt_i == zero_wide) ?
				ap_uint<CNT_SIZE> (0) :
				ap_uint<CNT_SIZE> (log_cnt_i - log_flit_rcvd); //I hope that works...
		drop_cnt_i = (drop_cnt_i == zero_wide) ?
				ap_uint<CNT_SIZE> (0)  :
				ap_uint<CNT_SIZE> (drop_cnt_i - mst_flit_sent); //I hope that works...
		if (inject_TREADY) inject_i = zero;
		//I hope this works!!!!!!
	}

	platch = latch;
}
