# These first few variables are for IP packaging

dst_dir=$(HOME)/ip_repo
src_dir=.
ip_name=tkeep_to_len
part_no=xczu19eg-ffvc1760-2-i
# Makes Makefile easier to read
out_dir=${dst_dir}/${ip_name}

MODULE := tkeep_to_len

default:	$(MODULE).vcd

$(MODULE).vcd:	$(MODULE).vvp
	vvp $(MODULE).vvp

$(MODULE).vvp:	$(MODULE).v $(MODULE)_tb.v
	iverilog -DICARUS_VERILOG -I../macros -g2012 -o $(MODULE).vvp $(MODULE)_tb.v

open:	$(MODULE).vcd
	gtkwave $(MODULE).vcd --autosavename &

clean:
	rm -rf $(MODULE).vvp
	rm -rf $(MODULE).vcd
	rm -rf ${out_dir}
	rm -rf ${ip_name}_tmp_proj

# Packages into a Vivado IP
ip: clean
	rm -rf ${out_dir}
	mkdir -p ${out_dir}/src
	cp tkeep_to_len.v ../macros/macros.vh ${out_dir}/src
	vivado -nolog -nojournal -notrace -mode batch -source ip_maker.tcl -tclargs ${out_dir} ${ip_name} ${part_no}
	rm -rf ${ip_name}_tmp_proj
	rm -f *log
	rm -rf .Xil
	rm -f vivado*

force:
	touch $(MODULE)_tb.v
	make

syntax_check:
	iverilog -Wall -Wno-timescale -DICARUS_VERILOG -I../macros -g2012 -o $(MODULE).vvp $(MODULE).v
	rm -rf $(MODULE).vvp
