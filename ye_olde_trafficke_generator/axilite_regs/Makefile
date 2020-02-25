dst_dir=$(HOME)/ip_repo
src_dir=.
ip_name=tg_axilite_intf
part_no=xczu19eg-ffvc1760-2-i

# Makes Makefile easier to read
out_dir=${dst_dir}/${ip_name}

default: clean
	vivado_hls -f hls.tcl -tclargs ${ip_name} ${part_no}
	mkdir -p ${dst_dir}
	cp -r tg_axilite_intf_tmp_proj/solution1/impl/ip ${out_dir}
	rm -rf tg_axilite_intf_tmp_proj
	rm -rf vivado*

clean:
	rm -rf ${out_dir}
	rm -rf tg_axilite_intf
	rm -rf vivado*
