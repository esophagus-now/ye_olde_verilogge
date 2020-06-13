# These first few variables are for IP packaging

dst_dir=$(HOME)/ip_repo
src_dir=.
ip_name=dbg_guv
part_no=xczu19eg-ffvc1760-2-i
# Makes Makefile easier to read
out_dir=${dst_dir}/${ip_name}

# These variables are for running the testbench
MODULE := dbg_guv

IVERILOG_INCLUDE = -Iaxis_governor/
IVERILOG_INCLUDE += -I../macros/
IVERILOG_INCLUDE += -I../tkeep_to_len/
IVERILOG_INCLUDE += -Idbg_guv_width_adapter/
IVERILOG_WARNS=-Wall -Wno-timescale

# By default, package as an ip
default: ip

# This is to run the testbench
tb: $(MODULE).vcd

# This opens the testbench in gtkwave
open:	$(MODULE).vcd
	gtkwave $(MODULE).vcd --autosavename &

# Compile the Verilog into Icarus's special format
$(MODULE).vvp:	$(MODULE).v $(MODULE)_tb.v $(MODULE)_drivers.mem
	iverilog ${IVERILOG_WARNS} -DICARUS_VERILOG ${IVERILOG_INCLUDE} -o $(MODULE).vvp $(MODULE)_tb.v

# Run the Verilog simulator
$(MODULE).vcd:	$(MODULE).vvp
	vvp $(MODULE).vvp

clean:
	rm -rf $(MODULE).vvp
	rm -rf $(MODULE).vcd
	rm -rf ${out_dir}
	rm -rf ${ip_name}_tmp_proj

# Packages into a Vivado IP
ip: clean
	rm -rf ${out_dir}
	mkdir -p ${out_dir}/src
	cp dbg_guv.v axis_governor/axis_governor.v ../macros/macros.vh ../axis_headerizer/axis_headerizer.v ${out_dir}/src
	vivado -nolog -nojournal -notrace -mode batch -source ip_maker.tcl -tclargs ${out_dir} ${ip_name} ${part_no}
	rm -rf ${ip_name}_tmp_proj
	rm -f *log
	rm -rf .Xil
	rm -f vivado*

syntax_check:
	iverilog ${IVERILOG_WARNS} -DICARUS_VERILOG ${IVERILOG_INCLUDE} -g2012 -o $(MODULE).vvp $(MODULE).v
	rm -rf $(MODULE).vvp
 
