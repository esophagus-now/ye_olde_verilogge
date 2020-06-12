#!/home/mahkoe/.conda/envs/sonar/bin/python

import os

from sonar.testbench import Testbench, Module, TestVector, Thread
from sonar.interfaces import AXIS, SAXILite


# create top-level entity for the testbench using the default constructor
# and set the Module_Name metadata tag to 'sample' as specified by the
# default constructor.
sample_TB = Testbench.default("dbg_guv_width_adapter")
filepath = os.path.join(os.path.dirname(__file__), "./")

# the DUT ------------------------------------------------------------------

# create a DUT module named 'DUT' and specify its signal ports
dut = Module.default("DUT")
dut.add_parameter("PAYLOAD_WORDS", 3)
dut.add_clock_port("clk", "10ns")
dut.add_reset_port("rst")
dut.add_port("header", size=32, direction="input")
sample_TB.add_module(dut)

# create an AXI-M interface with the default side channels and a data width
# of 64 and add it to the DUT.
adapted = AXIS("adapted", "master", "clk")
adapted.port.init_channels("default", 32)
dut.add_interface(adapted)

# create an AXI-S interface with the default side channels and a data width
# of 64 and add it to the DUT.
payload = AXIS("payload", "slave", "clk")
payload.port.init_channels("empty")
payload.port.add_channel('TDATA', 'tdata', 96)
payload.port.add_channel('TVALID', 'tvalid')
payload.port.add_channel('TREADY', 'tready')
payload.port.add_channel('TKEEP', 'tkeep', 12)
dut.add_interface(payload)

# test vectors -------------------------------------------------------------

test_vector_0 = TestVector()

timeout = Thread()
timeout.add_delay("5000ns")
timeout.display("Timed_out!")
timeout.end_vector()
# test_vector_0.add_thread(timeout)

# this thread just initializes signals. It could be reused in many test
# vectors so it's created differently from the other threads.
initT = Thread()
initT.init_signals()  # initialize all signals to zero
initT.set_signal("rst", 1)
initT.set_signal("adapted_tready", 1)
initT.set_signal("payload_tvalid", 0)
initT.wait_negedge("clk")  # wait for negedge of ap_clk
initT.add_delay("40ns")
test_vector_0.add_thread(initT)

# this thread is responsible for sending the stimulus (i.e. the driver)
inputT = test_vector_0.add_thread()
inputT.add_delay("100ns")
inputT.init_timer()  # zeros a timer that can be evaluated for runtime
inputT.set_signal("header", 0xCAFEBABE);
payload.write(inputT, 0xFAFFADAFFABEDAFFABACADAB) 
inputT.add_delay("110ns")
inputT.set_flag(0)  # sets flag 0 that another thread may be waiting on

# this thread will validate the behavior of the DUT (i.e. the monitor)
outputT = test_vector_0.add_thread()
adapted.read(outputT, 0xCAFEBABE, tlast=0)  # AXIS implicitly waits for valid data
adapted.read(outputT, 0xFAFFADAF, tlast=0)  # AXIS implicitly waits for valid data
adapted.read(outputT, 0xFABEDAFF, tlast=0)  # AXIS implicitly waits for valid data
adapted.read(outputT, 0xABACADAB, tlast=1)  # AXIS implicitly waits for valid data
outputT.wait_flag(0)  # waits for flag 0 to be set by another thread
outputT.print_elapsed_time("End")  # prints string + time since last init
outputT.display("The_simulation_is_finished")  # prints string
outputT.end_vector()  # terminates the test vector

tv1 = TestVector()

tv1.add_thread(initT)
inthd = tv1.add_thread()
inthd.add_delay("40ns")
inthd.init_timer()
inthd.set_signal("header", 0x1337BEEF)
payload.write(inthd, 0xBAD4BEEFFEE1DEADCAFEBABE, tkeep=0xFC0)

outthd = tv1.add_thread()
adapted.read(outthd, 0x1337BEEF, tlast=0)
adapted.read(outthd, 0xBAD4BEEF, tlast=0)
adapted.read(outthd, 0xFEE1DEAD, tlast=1)
outthd.display("The_following_AXI_Stream_read_should_time_out")
outthd.display("(You_will_need_to_hit_CTRL_C)")
adapted.read(outthd, 0xCAFEBABE, tlast=1)
outthd.add_delay("20ns")
outthd.end_vector()

tv1.add_thread(timeout)

# epilogue -----------------------------------------------------------------

# if there are many vectors, they can be selectively enabled by adding them
sample_TB.add_test_vector(test_vector_0)
sample_TB.add_test_vector(tv1)

# generate the output testbenches and data files for the specified languages
# at the designated path
sample_TB.generateTB(filepath, "sv")
