MODULE :=alu

IVERILOG_INCLUDE = -I../../../macros/
IVERILOG_INCLUDE += -I../../
IVERILOG_WARNS=-Wall -Wno-timescale

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

syntax_check:
	iverilog ${IVERILOG_WARNS} -DICARUS_VERILOG ${IVERILOG_INCLUDE} -g2012 -o $(MODULE).vvp $(MODULE).v
	rm -rf $(MODULE).vvp
 
