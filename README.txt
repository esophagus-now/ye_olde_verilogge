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

buffered_handshake
------------------
    More or less identical to an AXI Stream register slice. Has come in handy 
    more often that I expected.

ye_olde_trafficke_generator
---------------------------
    Generates AXI Stream traffic. Has runtime-configurable bandwidth, and obeys 
    backpressure. Generates data in a fixed pattern, which I will decide at 
    some point.

