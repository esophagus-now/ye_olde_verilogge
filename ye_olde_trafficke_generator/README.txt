Generates AXI Stream traffic. Has runtime-configurable bandwidth, and obeys 
backpressure. Generates data in a fixed pattern, which I will decide at some 
point.

The core has a number of config inputs, as described below:

mode
----
+------------------------------------------------------------------------------+
| Bit | NAME    | DESCRIPTION                                                  |
+------------------------------------------------------------------------------+
|   0 |      EN | Enables/Disables traffic generation                          |
+------------------------------------------------------------------------------+
| 2-1 |    FILL | 00: Fill with zeroes                                         |
|     |         | 01: Fill with header                                         |
|     |         | 10: Fill with LFSR (unimplemented)                           |
|     |         | 11: Fill with DEADBEEF                                       |
+------------------------------------------------------------------------------+
|   3 |    LOOP | 1: Keep looping forever; 0: stop after num_packets           |
+------------------------------------------------------------------------------+

num_packets
-----------
The number of packets to send in this burst. If mode.LOOP == 0, the generator 
will send out num_packets packets as soon as mode.EN goes high. Otherwise, the
generated packets will continue repeating until mode.EN goes low.

num_flits
---------
The number of flits to send per packet, before TLAST is asserted

last_flit_bytes
---------------
The number of bytes in the last flit of each packet. TKEEP will be set 
accordingly

M and N
-------
Used for throttling bandwidth. The core enforces maintains (as time -> infinity)
that (idle_cycles/active_cycles) = (M/N)

Header format
-------------
When mode.FILL == 01, the packet's body will be repeating copies of the 
following 14 byte "struct":

+------------------------------------------------------------------------------+
| Byte | NAME    | DESCRIPTION                                                 |
+------------------------------------------------------------------------------+
|  1-0 |  pkt_no | Packet number                                               |
+------------------------------------------------------------------------------+
|  3-2 | flit_no | Flit number                                                 |
+------------------------------------------------------------------------------+
|    4 |    mode | Mode bits used to generate packets (see above)              |
+------------------------------------------------------------------------------+
|  6-5 | num_pkt | Total number of packets in this "cycle"                     |
+------------------------------------------------------------------------------+
|  8-7 | num_flt | Total number of flits in this packet                        |
+------------------------------------------------------------------------------+
|    9 | num_lst | Total number of bytes in the last flit of a packet          |
+------------------------------------------------------------------------------+
|11-10 |       M | (See "M and N", above)                                      |
+------------------------------------------------------------------------------+
|13-12 |       N | (See "M and N", above)                                      |
+------------------------------------------------------------------------------+
