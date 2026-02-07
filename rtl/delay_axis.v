`timescale 1 ns / 1 ps

// ============================================================================
// AXI-Stream Stereo Delay with AXI-Lite Control
// ----------------------------------------------------------------------------
// - Stereo delay (Left / Right independent)
// - AXI4-Stream for audio data
// - AXI4-Lite for runtime control
// - Built on top of delay_core (BRAM-based circular buffer)
// ----------------------------------------------------------------------------
// Notes:
// - No feedback, no interpolation
// - Fixed 1-cycle processing latency (BRAM read)
// - Designed for simple echo / stereo widening use cases
// ============================================================================

module delay_axis #(
    // ------------------------------------------------------------------------
    // AXI-Lite Parameters
    // ------------------------------------------------------------------------
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 4, 
    
    // ------------------------------------------------------------------------
    // Audio Parameters
    // ------------------------------------------------------------------------
    parameter integer AUDIO_WIDTH  = 16,
    parameter integer DELAY_ADDR_W = 12   // 2^12 = 4096 samples max
)(
    // ------------------------------------------------------------------------
    // Global Clock & Reset
    // ------------------------------------------------------------------------
    input  wire aclk,
    input  wire aresetn,

    // ------------------------------------------------------------------------
    // AXI4-Stream Slave (Input Audio)
    // ------------------------------------------------------------------------
    input  wire [31:0] s_axis_tdata,   // [31:16] Right, [15:0] Left
    input  wire        s_axis_tlast,
    input  wire        s_axis_tvalid,
    output wire        s_axis_tready,

    // ------------------------------------------------------------------------
    // AXI4-Stream Master (Output Audio)
    // ------------------------------------------------------------------------
    output wire [31:0] m_axis_tdata,
    output wire        m_axis_tlast,
    output wire        m_axis_tvalid,
    input  wire        m_axis_tready,

    // ------------------------------------------------------------------------
    // AXI4-Lite Slave (Control Interface)
    // ------------------------------------------------------------------------
    input  wire [C_S_AXI_ADDR_WIDTH-1:0] s_axi_awaddr,
    input  wire                          s_axi_awvalid,
    output reg                           s_axi_awready,
    input  wire [C_S_AXI_DATA_WIDTH-1:0] s_axi_wdata,
    input  wire [3:0]                    s_axi_wstrb, // Byte strobe
    input  wire                          s_axi_wvalid,
    output reg                           s_axi_wready,
    output reg  [1:0]                    s_axi_bresp,
    output reg                           s_axi_bvalid,
    input  wire                          s_axi_bready,
    input  wire [C_S_AXI_ADDR_WIDTH-1:0] s_axi_araddr,
    input  wire                          s_axi_arvalid,
    output reg                           s_axi_arready,
    output reg  [C_S_AXI_DATA_WIDTH-1:0] s_axi_rdata,
    output reg  [1:0]                    s_axi_rresp,
    output reg                           s_axi_rvalid,
    input  wire                          s_axi_rready
);

    // =========================================================================
    // 1. AXI-LITE REGISTER MAP
    // =========================================================================
    // 0x00 : Control Register
    //        Bit [0] = Core Enable (1 = Active, 0 = Freeze)
    //
    // 0x04 : Left Channel Delay (samples)
    // 0x08 : Right Channel Delay (samples)
    
    reg [31:0] reg_ctrl;
    reg [31:0] reg_delay_l;
    reg [31:0] reg_delay_r;
    
    // Word-aligned address decoding (0x0, 0x4, 0x8 ...)
    wire [1:0] addr_w = s_axi_awaddr[3:2];
    wire [1:0] addr_r = s_axi_araddr[3:2];

    // =========================================================================
    // 2. AXI-LITE WRITE CHANNEL
    // =========================================================================
    // - Single-beat write
    // - Supports byte strobes (WSTRB)
    // - Simple ready/valid handshake
    always @(posedge aclk) begin
        if (!aresetn) begin
            s_axi_awready <= 0;
            s_axi_wready  <= 0;
            s_axi_bvalid  <= 0;
            s_axi_bresp   <= 0;
            
            // Default register values
            reg_ctrl    <= 32'd1;     // Enabled by default
            reg_delay_l <= 32'd200;   // 200 samples
            reg_delay_r <= 32'd400;   // 400 samples (stereo offset)
        end else begin
            // Accept write when address and data are both valid
            if (!s_axi_awready && s_axi_awvalid && s_axi_wvalid) begin
                s_axi_awready <= 1'b1;
                s_axi_wready  <= 1'b1;
                
                // Register write with byte-level masking
                case (addr_w)
                    2'h0: begin // REG_CTRL
                        if (s_axi_wstrb[0]) reg_ctrl[7:0]   <= s_axi_wdata[7:0];
                        if (s_axi_wstrb[1]) reg_ctrl[15:8]  <= s_axi_wdata[15:8];
                        if (s_axi_wstrb[2]) reg_ctrl[23:16] <= s_axi_wdata[23:16];
                        if (s_axi_wstrb[3]) reg_ctrl[31:24] <= s_axi_wdata[31:24];
                    end
                    2'h1: begin // REG_DELAY_L
                        if (s_axi_wstrb[0]) reg_delay_l[7:0]   <= s_axi_wdata[7:0];
                        if (s_axi_wstrb[1]) reg_delay_l[15:8]  <= s_axi_wdata[15:8];
                        if (s_axi_wstrb[2]) reg_delay_l[23:16] <= s_axi_wdata[23:16];
                        if (s_axi_wstrb[3]) reg_delay_l[31:24] <= s_axi_wdata[31:24];
                    end
                    2'h2: begin // REG_DELAY_R
                        if (s_axi_wstrb[0]) reg_delay_r[7:0]   <= s_axi_wdata[7:0];
                        if (s_axi_wstrb[1]) reg_delay_r[15:8]  <= s_axi_wdata[15:8];
                        if (s_axi_wstrb[2]) reg_delay_r[23:16] <= s_axi_wdata[23:16];
                        if (s_axi_wstrb[3]) reg_delay_r[31:24] <= s_axi_wdata[31:24];
                    end
                endcase
            end else begin
                s_axi_awready <= 1'b0;
                s_axi_wready  <= 1'b0;
            end

            // Write response channel
            if (s_axi_awready && s_axi_wready && !s_axi_bvalid) begin
                s_axi_bvalid <= 1'b1;
                s_axi_bresp  <= 2'b00; // OKAY
            end else if (s_axi_bready && s_axi_bvalid) begin
                s_axi_bvalid <= 1'b0;
            end
        end
    end

    // =========================================================================
    // 3. AXI-LITE READ CHANNEL
    // =========================================================================
    always @(posedge aclk) begin
        if (!aresetn) begin
            s_axi_arready <= 0;
            s_axi_rvalid  <= 0;
            s_axi_rdata   <= 0;
            s_axi_rresp   <= 0;
        end else begin
            if (!s_axi_arready && s_axi_arvalid) begin
                s_axi_arready <= 1'b1;
                s_axi_rvalid  <= 1'b1;
                s_axi_rresp   <= 2'b00; // OKAY
                
                // Readback mux
                case (addr_r)
                    2'h0: s_axi_rdata <= reg_ctrl;
                    2'h1: s_axi_rdata <= reg_delay_l;
                    2'h2: s_axi_rdata <= reg_delay_r;
                    default: s_axi_rdata <= 32'd0;
                endcase
            end else begin
                s_axi_arready <= 1'b0;
                // Clear RVALID after master accepts data
                if (s_axi_rvalid && s_axi_rready)
                    s_axi_rvalid <= 1'b0;
            end
        end
    end

    // =========================================================================
    // 4. STREAM FLOW CONTROL (SKID BUFFER)
    // =========================================================================
    reg valid_d;
    reg last_d;
    
    // Ready when downstream is ready OR pipeline is empty
    wire stream_ready = m_axis_tready || !valid_d;
    
    // Core enable condition:
    // - Stream can advance
    // - Input data valid
    // - Core enabled via control register
    wire core_en = stream_ready & s_axis_tvalid & reg_ctrl[0];

    assign s_axis_tready = stream_ready;

    // =========================================================================
    // 5. DELAY CORE INSTANTIATION
    // =========================================================================
    wire signed [15:0] w_out_l;
    wire signed [15:0] w_out_r;

    // Left Channel (Bits [15:0])
    delay_core #(
        .DATA_W(AUDIO_WIDTH),
        .ADDR_W(DELAY_ADDR_W)
    ) u_core_l (
        .clk        (aclk),
        .rst_n      (aresetn),
        .en         (core_en),
        .bypass     (1'b0),
        .base_delay (reg_delay_l[DELAY_ADDR_W-1:0]),
        .mod_val    (16'sd0),
        .din        (s_axis_tdata[15:0]),
        .dout       (w_out_l)
    );

    // Right Channel (Bits [31:16])
    delay_core #(
        .DATA_W(AUDIO_WIDTH),
        .ADDR_W(DELAY_ADDR_W)
    ) u_core_r (
        .clk        (aclk),
        .rst_n      (aresetn),
        .en         (core_en),
        .bypass     (1'b0),
        .base_delay (reg_delay_r[DELAY_ADDR_W-1:0]),
        .mod_val    (16'sd0),
        .din        (s_axis_tdata[31:16]),
        .dout       (w_out_r)
    );

    // =========================================================================
    // 6. OUTPUT PIPELINE ALIGNMENT
    // =========================================================================
    // delay_core uses synchronous BRAM read → 1-cycle latency.
    // Control signals (valid / last) are delayed to match data path.
    always @(posedge aclk) begin
        if (!aresetn) begin
            valid_d <= 0;
            last_d  <= 0;
        end else if (stream_ready) begin
            valid_d <= s_axis_tvalid;
            last_d  <= s_axis_tlast;
        end
    end

    // Pack stereo output: {Right, Left}
    assign m_axis_tdata  = {w_out_r, w_out_l};
    assign m_axis_tvalid = valid_d;
    assign m_axis_tlast  = last_d;

endmodule
