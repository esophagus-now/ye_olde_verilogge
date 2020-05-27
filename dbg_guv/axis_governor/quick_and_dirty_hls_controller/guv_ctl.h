#ifndef GUV_CTL_H
#define GUV_CTL_H 1

#define CNT_SIZE 8

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
);

#endif
