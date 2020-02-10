=============================
YE OLDE VERILOGGE REPOfITORIE
=============================

Welcome!

This is an assortment of smallish Verilog designs that I wanted to maintain 
separately. Usually, if there is something in here, it's because I needed it 
some bigger project.

All of these modules include testbenches designed to be used with Icarus 
Verilog and GTKWave. However, I also make sure that it will all work with 
Vivado as well. 

A small number of these modules are specifically written to take advantage of 
"Xilinx Synthesis Technology". Specifically, this means that I wanted a 
specific implementation in an FPGA, and to get it, I referenced this PDF:

https://www.xilinx.com/support/documentation/sw_manuals/xilinx11/xst.pdf

Most modules are "platform-independent"

========
CONTENTS
========

axis_governor
-------------
    A neat little core for debugging AXI Streams. Not complete yet, but I 
    figured I would start saving it into github. Allows pausing, dropping, 
    logging, or injecting into any AXI Stream and is pretty lightweight. For 
    the sake of completeness, I've also included some quick and dirty HLS code 
    I wrote that allows me to test it from inside an ARM (in an SoC).

buffered_handshake
------------------
    More or less identical to an AXI Stream register slice. Has come in handy 
    more often that I expected.

mux_tree
--------
    A fully pipelined and completely generic MUX tree. It is copied straight 
    out of another one of my projects, but should work in the general case.

ye_olde_trafficke_generator
---------------------------
    Generates AXI Stream traffic. Has runtime-configurable bandwidth, and obeys 
    backpressure. Generates data in a fixed pattern, which I will decide at 
    some point.

