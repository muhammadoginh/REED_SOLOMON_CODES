# run_xsim.tcl — Vivado xsim batch runner for tb_reed_solomon_encode
#
# Invoke from the directory holding tb_reed_solomon_encode.sv and the
# per-variant packed vectors. The variant directory is selected via the
# first tclarg.
#
# Example (Windows Vivado tcl shell):
#   vivado -mode batch -nojournal -nolog -source run_xsim.tcl -tclargs hqc-5
#   vivado -mode batch -nojournal -nolog -source run_xsim.tcl -tclargs hqc-3
#   vivado -mode batch -nojournal -nolog -source run_xsim.tcl -tclargs hqc-1

if {[llength $argv] >= 1} {
    set vec_dir [lindex $argv 0]
} else {
    set vec_dir "hqc-5"
}

switch -- $vec_dir {
    "hqc-1" { set pset "hqc128" }
    "hqc-3" { set pset "hqc192" }
    "hqc-5" { set pset "hqc256" }
    default { set pset "hqc256" }
}

set rtl_root "../../../Reference_HQC/pqc-hqc-hardware-master/hardware"

create_project -force tb_reed_solomon_encode_prj ./tb_reed_solomon_encode_prj -part xc7a200tfbg676-1
set_property target_language verilog [current_project]

add_files -norecurse $rtl_root/encap/gf_mul.v
add_files -norecurse $rtl_root/encap/cdw_xor_tmp.v
add_files -norecurse $rtl_root/encap/reed_solomon_encode.v
add_files -fileset sim_1 -norecurse ./tb_reed_solomon_encode.sv
add_files -fileset sim_1 -norecurse ./$vec_dir/inputs.mem
add_files -fileset sim_1 -norecurse ./$vec_dir/outputs.mem

set_property top tb_reed_solomon_encode [get_filesets sim_1]
set_property generic "parameter_set=$pset" [get_filesets sim_1]
set_property -name {xsim.simulate.runtime} -value {-1} -objects [get_filesets sim_1]
set_property -name {xsim.simulate.xsim.more_options} -value "-testplusarg VEC_DIR=$vec_dir" -objects [get_filesets sim_1]

launch_simulation
run all
