# =============================================================================
# bd.tcl
# -----------------------------------------------------------------------------
# Block Design for AXI-based Stereo Delay
# Target Board : Kria KV260
# Tool         : Vivado 2024.1
# =============================================================================

# -------------------------------------------------
# Create Block Design
# -------------------------------------------------
set BD_NAME "delay_bd"
create_bd_design $BD_NAME
current_bd_design $BD_NAME

# -------------------------------------------------
# Processing System (Zynq MPSoC)
# -------------------------------------------------
set ps [create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e:3.5 ps]
apply_bd_automation -rule xilinx.com:bd_rule:zynq_ultra_ps_e \
    -config {apply_board_preset "1"} $ps

# -------------------------------------------------
# AXI DMA (MM2S + S2MM)
# -------------------------------------------------
set dma [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 axi_dma]
set_property CONFIG.c_include_sg {0} $dma

# -------------------------------------------------
# AXI SmartConnect (HP ports)
# -------------------------------------------------
set smc_mm2s [create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 smc_mm2s]
set_property CONFIG.NUM_SI {1} $smc_mm2s

set smc_s2mm [create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 smc_s2mm]
set_property CONFIG.NUM_SI {1} $smc_s2mm

# -------------------------------------------------
# AXI Lite Interconnect (Control)
# -------------------------------------------------
set axi_ctrl [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_ctrl]
set_property CONFIG.NUM_MI {2} $axi_ctrl

# -------------------------------------------------
# Reset Controller
# -------------------------------------------------
set rst [create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst]

# -------------------------------------------------
# Custom RTL Module
# -------------------------------------------------
set delay [create_bd_cell -type module -reference delay_axis delay_axis_0]

# -------------------------------------------------
# Clock & Reset
# -------------------------------------------------
connect_bd_net [get_bd_pins ps/pl_clk0] \
               [get_bd_pins dma/m_axi_mm2s_aclk] \
               [get_bd_pins dma/m_axi_s2mm_aclk] \
               [get_bd_pins dma/s_axi_lite_aclk] \
               [get_bd_pins axi_ctrl/ACLK] \
               [get_bd_pins delay/aclk] \
               [get_bd_pins rst/slowest_sync_clk]

connect_bd_net [get_bd_pins ps/pl_resetn0] [get_bd_pins rst/ext_reset_in]

connect_bd_net [get_bd_pins rst/peripheral_aresetn] \
               [get_bd_pins dma/axi_resetn] \
               [get_bd_pins axi_ctrl/ARESETN] \
               [get_bd_pins delay/aresetn] \
               [get_bd_pins smc_mm2s/aresetn] \
               [get_bd_pins smc_s2mm/aresetn]

# -------------------------------------------------
# AXI Stream Connections
# -------------------------------------------------
connect_bd_intf_net [get_bd_intf_pins dma/M_AXIS_MM2S] \
                    [get_bd_intf_pins delay/s_axis]

connect_bd_intf_net [get_bd_intf_pins delay/m_axis] \
                    [get_bd_intf_pins dma/S_AXIS_S2MM]

# -------------------------------------------------
# AXI Memory-Mapped (DMA <-> PS)
# -------------------------------------------------
connect_bd_intf_net [get_bd_intf_pins dma/M_AXI_MM2S] \
                    [get_bd_intf_pins smc_mm2s/S00_AXI]

connect_bd_intf_net [get_bd_intf_pins smc_mm2s/M00_AXI] \
                    [get_bd_intf_pins ps/S_AXI_HP1_FPD]

connect_bd_intf_net [get_bd_intf_pins dma/M_AXI_S2MM] \
                    [get_bd_intf_pins smc_s2mm/S00_AXI]

connect_bd_intf_net [get_bd_intf_pins smc_s2mm/M00_AXI] \
                    [get_bd_intf_pins ps/S_AXI_HP0_FPD]

# -------------------------------------------------
# AXI Lite Control Path
# -------------------------------------------------
connect_bd_intf_net [get_bd_intf_pins ps/M_AXI_HPM0_FPD] \
                    [get_bd_intf_pins axi_ctrl/S00_AXI]

connect_bd_intf_net [get_bd_intf_pins axi_ctrl/M00_AXI] \
                    [get_bd_intf_pins dma/S_AXI_LITE]

connect_bd_intf_net [get_bd_intf_pins axi_ctrl/M01_AXI] \
                    [get_bd_intf_pins delay/s_axi]

# -------------------------------------------------
# Address Map
# -------------------------------------------------
assign_bd_address
assign_bd_address -target_address_space [get_bd_addr_spaces ps/Data] \
                   [get_bd_addr_segs dma/S_AXI_LITE/Reg]

assign_bd_address -target_address_space [get_bd_addr_spaces ps/Data] \
                   [get_bd_addr_segs delay/s_axi/reg0]

# -------------------------------------------------
# Finalize
# -------------------------------------------------
validate_bd_design
save_bd_design

puts "INFO: Block design '$BD_NAME' created."
