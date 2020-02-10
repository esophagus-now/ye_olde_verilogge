#include <iostream>
#include "ap_int.h"
#include "guv_ctl.h"

using namespace std;

#define SHOW(X) cout << "\t" #X " = " << X << endl

#define DO_CYCLE() do {\
	guv_ctl (latch,inject_data,inject,log_cnt,drop_cnt,pause,pause_out,drop_out,log_out,inject_TDATA,inject_TVALID,inject_TREADY,mst_flit_sent,slv_flit_recv);\
	cout << "Clock cycle " << cycle++ << ":" << endl;\
	cout << "Inputs:" << endl;\
	SHOW(latch); SHOW(inject_data); SHOW(inject); SHOW(log_cnt); SHOW(drop_cnt); SHOW(pause); SHOW(inject_TREADY);\
	cout << "Outputs:" << endl;\
	SHOW(pause_out); SHOW(drop_out); SHOW(log_out); SHOW(inject_TDATA); SHOW(inject_TVALID);\
	cout << endl << endl;\
} while(0)

int main() {
	ap_uint<1> latch;
	ap_uint<10> inject_data;
	ap_uint<1> inject;
	ap_uint<CNT_SIZE> log_cnt;
	ap_uint<CNT_SIZE> drop_cnt;
	ap_uint<1> pause;

	ap_uint<1> pause_out;
	ap_uint<1> drop_out;
	ap_uint<1> log_out;
	ap_uint<10> inject_TDATA;
	ap_uint<1> inject_TVALID;
	ap_uint<1> inject_TREADY;
	ap_uint<1> mst_flit_sent = 1;
	ap_uint<1> slv_flit_recv = 1;

	int cycle = 0;

	cout << "Test 1: nothing latched" << endl;
	cout << "-----------------------" << endl;
	//Set inputs for this cycle
	latch = 0;
	inject_data = ap_uint<10>(305);
	inject = 1;
	log_cnt = 2;
	drop_cnt = 7;
	pause = 1;
	inject_TREADY = 1;
	DO_CYCLE();

	cout << "Test 2: Drop 2, Log 4, no pause after" << endl;
	cout << "-------------------------------------" << endl;
	//Set inputs for this cycle
	latch = 1;
	inject_data = ap_uint<10>(305);
	inject = 0;
	log_cnt = 4;
	drop_cnt = 2;
	pause = 0;
	inject_TREADY = 1;
	DO_CYCLE();

	latch = 0;
	DO_CYCLE();
	DO_CYCLE();
	DO_CYCLE();
	DO_CYCLE();
	DO_CYCLE();
	DO_CYCLE();


	cout << "Test 3: Drop 2, Log 4, pause after. Also injecting one flit" << endl;
	cout << "-----------------------------------------------------------" << endl;
	//Set inputs for this cycle
	latch = 1;
	inject_data = ap_uint<10>(305);
	inject = 1;
	log_cnt = 2;
	drop_cnt = 4;
	pause = 1;
	inject_TREADY = 0;
	DO_CYCLE();

	latch = 0;
	DO_CYCLE();
	cout << "(inject_TREADY has been asserted)" << endl;
	inject_TREADY = 1;
	DO_CYCLE();
	DO_CYCLE();
	DO_CYCLE();
	DO_CYCLE();
	DO_CYCLE();
	DO_CYCLE();


	cout << "Test 4: Pause and inject a flit" << endl;
	cout << "-------------------------------" << endl;
	latch = 1;
	inject_data = ap_uint<10>(305);
	inject = 1;
	log_cnt = 0;
	drop_cnt = 0;
	pause = 1;
	inject_TREADY = 1;
	DO_CYCLE();

	latch = 0;
	DO_CYCLE();
	DO_CYCLE();
	DO_CYCLE();
	return 0;
}
