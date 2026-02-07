# =============================================================================
# create_project.tcl
# -----------------------------------------------------------------------------
# Recreate Vivado project for AXI-based Stereo Delay (KV260)
# Target Tool : Vivado 2024.1
# Board       : Kria KV260
# =============================================================================

# -------------------------------------------------
# User-configurable parameters
# -------------------------------------------------
set PROJECT_NAME "delay_axis_proj"
set PART_NAME    "xck26-sfvc784-2LV-c"
set BOARD_PART   "xilinx.com:kv260_som:part0:1.4"

set ORIGIN_DIR   [file normalize [file dirname [info script]]]
set RTL_DIR      [file normalize "$ORIGIN_DIR/../rtl"]
set SIM_DIR      [file normalize "$ORIGIN_DIR/../sim"]

# -------------------------------------------------
# Create project
# -------------------------------------------------
create_project $PROJECT_NAME ./$PROJECT_NAME -part $PART_NAME -force
set_property board_part $BOARD_PART [current_project]

# -------------------------------------------------
# Add RTL sources
# -------------------------------------------------
add_files -fileset sources_1 \
    $RTL_DIR/delay_core.v \
    $RTL_DIR/delay_axis.v

# -------------------------------------------------
# Add simulation sources
# -------------------------------------------------
add_files -fileset sim_1 \
    $SIM_DIR/tb_delay_core.sv \
    $SIM_DIR/tb_delay_axis.sv

set_property file_type SystemVerilog [get_files *.sv]

set_property top tb_delay_axis [get_filesets sim_1]

# -------------------------------------------------
# Create Block Design
# -------------------------------------------------
create_bd_design "design_1"

# --- Processing System ---
set ps [create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e:3.5 ps]
apply_bd_automation -rule xilinx.com:bd_rule:zynq_ultra_ps_e -config {apply_board_preset "1"} $ps

# --- AXI DMA ---
set dma [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 axi_dma]
set_property -dict [list CONFIG.c_include_sg {0}] $dma

# --- AXI SmartConnect ---
set smc_mm2s [create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 smc_mm2s]
set_property CONFIG.NUM_SI {1} $smc_mm2s

set smc_s2mm [create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 smc_s2mm]
set_property CONFIG.NUM_SI {1} $smc_s2mm

# --- Reset ---
set rst [create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst]

# --- Custom Delay IP (RTL Module) ---
set delay [create_bd_cell -type module -reference delay_axis delay_axis_0]

# -------------------------------------------------
# Clock & Reset
# -------------------------------------------------
connect_bd_net [get_bd_pins ps/pl_clk0] \
               [get_bd_pins delay/aclk] \
               [get_bd_pins dma/m_axi_mm2s_aclk] \
               [get_bd_pins dma/m_axi_s2mm_aclk]

connect_bd_net [get_bd_pins ps/pl_resetn0] [get_bd_pins rst/ext_reset_in]
connect_bd_net [get_bd_pins rst/peripheral_aresetn] \
               [get_bd_pins delay/aresetn] \
               [get_bd_pins dma/axi_resetn]

# -------------------------------------------------
# AXI Stream Connections
# -------------------------------------------------
connect_bd_intf_net [get_bd_intf_pins dma/M_AXIS_MM2S] \
                    [get_bd_intf_pins delay/s_axis]

connect_bd_intf_net [get_bd_intf_pins delay/m_axis] \
                    [get_bd_intf_pins dma/S_AXIS_S2MM]

# -------------------------------------------------
# AXI Memory Mapped Connections
# -------------------------------------------------
connect_bd_intf_net [get_bd_intf_pins dma/M_AXI_MM2S] \
                    [get_bd_intf_pins smc_mm2s/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins smc_mm2s/M00_AXI] \
                    [get_bd_intf_pins ps/S_AXI_HP1_FPD]

connect_bd_intf_net [get_bd_intf_pins dma/M_AXI_S2MM] \
                    [get_bd_intf_pins smc_s2mm/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins smc_s2mm/M00_AXI] \
                    [get_bd_intf_pins ps/S_AXI_HP0_FPD]

# AXI-Lite control
connect_bd_intf_net [get_bd_intf_pins ps/M_AXI_HPM0_FPD] \
                    [get_bd_intf_pins delay/s_axi]

# -------------------------------------------------
# Address Map
# -------------------------------------------------
assign_bd_address
assign_bd_address -target_address_space [get_bd_addr_spaces ps/Data] \
                   [get_bd_addr_segs delay/s_axi/reg0]

# -------------------------------------------------
# Finalize BD
# -------------------------------------------------
validate_bd_design
save_bd_design

# -------------------------------------------------
# Generate HDL wrapper
# -------------------------------------------------
make_wrapper -files [get_files *.bd] -top
add_files -norecurse [glob *.v]

puts "INFO: Project '$PROJECT_NAME' created successfully."
