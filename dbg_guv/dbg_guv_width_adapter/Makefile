sim: dbg_guv_width_adapter.v dbg_guv_width_adapter_tb.sv
	xvlog --sv dbg_guv_width_adapter_tb.sv --relax
	xvlog dbg_guv_width_adapter.v -i ../../macros
	xelab -debug typical dbg_guv_width_adapter_tb
	xsim dbg_guv_width_adapter_tb -R

dbg_guv_width_adapter_tb.sv:	tb.py
	python tb.py

clean_vivado:
	# Why does Vivado INSIST on leaving so much junk????
	rm -rf webtalk*
	rm -rf xelab*
	rm -rf xvlog*
	rm -rf xsim*
	rm -rf vivado*
	rm -rf .Xil

clean: clean_vivado
	rm -rf *sv
	rm -rf *json
	rm -rf *dat
	rm -rf *wdb

syntax_check:
	iverilog -Wall -Wno-timescale -I../../macros dbg_guv_width_adapter.v -o tmp.vvp
	rm -rf tmp.vvp

