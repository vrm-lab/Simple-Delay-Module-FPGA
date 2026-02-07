# ============================================================================
# Vivado Project Recreation Script
# Project : PEAK
# Board   : Kria KV260
# Device  : xck26-sfvc784-2LV-c
#
# Usage:
#   vivado -mode tcl -source scripts/create_project.tcl
#
# Notes:
# - Paths are relative to repository root
# - Intended for clean, reproducible builds
# ============================================================================

# ----------------------------------------------------------------------------
# Project Settings
# ----------------------------------------------------------------------------
set PROJ_NAME  "PEAK"
set PROJ_DIR   "./${PROJ_NAME}"
set PART_NAME  "xck26-sfvc784-2LV-c"
set BOARD_PART "xilinx.com:kv260_som:part0:1.4"

# ----------------------------------------------------------------------------
# Create Project
# ----------------------------------------------------------------------------
create_project ${PROJ_NAME} ${PROJ_DIR} -part ${PART_NAME}
set_property board_part ${BOARD_PART} [current_project]
set_property simulator_language Mixed [current_project]

# ----------------------------------------------------------------------------
# Source Files
# ----------------------------------------------------------------------------
add_files -fileset sources_1 {
    src/rms_peak_core.v
    src/rms_peak_axis.v
}

add_files -fileset sim_1 {
    sim/tb_rms_peak_core.sv
    sim/tb_rms_peak_axis.sv
}

set_property file_type SystemVerilog [get_files sim/*.sv]

set_property top PEAK_wrapper [get_filesets sources_1]
set_property top tb_rms_peak_core [get_filesets sim_1]

# ----------------------------------------------------------------------------
# Block Design
# ----------------------------------------------------------------------------
source scripts/bd/create_bd_peak.tcl

# Generate HDL wrapper
make_wrapper -files [get_files PEAK.bd] -top
add_files -norecurse PEAK.gen/sources_1/bd/PEAK/hdl/PEAK_wrapper.v

# ----------------------------------------------------------------------------
# Synthesis & Implementation Runs
# ----------------------------------------------------------------------------
if {[get_runs synth_1] eq ""} {
    create_run synth_1 -flow {Vivado Synthesis 2024} -strategy Default
}

if {[get_runs impl_1] eq ""} {
    create_run impl_1 -parent_run synth_1 \
        -flow {Vivado Implementation 2024} -strategy Default
}

current_run synth_1
current_run impl_1

puts "INFO: Project ${PROJ_NAME} successfully created."
