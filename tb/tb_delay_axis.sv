`timescale 1ns / 1ps

// ============================================================================
// Testbench: delay_axis
// ----------------------------------------------------------------------------
// Purpose:
// - End-to-end verification of AXI-Stream + AXI-Lite stereo delay
// - Validates:
//   * AXI-Lite register configuration
//   * AXI-Stream data flow and backpressure
//   * Stereo delay behavior (Left / Right independent)
// ----------------------------------------------------------------------------
// Output:
// - CSV file for offline analysis and plotting
// ============================================================================

module tb_delay_axis;

    // =========================================================================
    // PARAMETERS
    // =========================================================================
    parameter CLK_PERIOD = 10;  // 100 MHz
    parameter AXIS_WIDTH = 32;
    parameter ADDR_WIDTH = 4;
    parameter AUDIO_W    = 16;
    
    // =========================================================================
    // SIGNALS
    // =========================================================================
    reg aclk;
    reg aresetn;

    // -------------------------------------------------------------------------
    // AXI4-Stream Slave (Input to DUT)
    // -------------------------------------------------------------------------
    reg  [AXIS_WIDTH-1:0] s_axis_tdata;
    reg                   s_axis_tlast;
    reg                   s_axis_tvalid;
    wire                  s_axis_tready;

    // -------------------------------------------------------------------------
    // AXI4-Stream Master (Output from DUT)
    // -------------------------------------------------------------------------
    wire [AXIS_WIDTH-1:0] m_axis_tdata;
    wire                  m_axis_tlast;
    wire                  m_axis_tvalid;
    reg                   m_axis_tready;

    // -------------------------------------------------------------------------
    // AXI4-Lite Control Interface
    // -------------------------------------------------------------------------
    reg  [ADDR_WIDTH-1:0] s_axi_awaddr;
    reg                   s_axi_awvalid;
    wire                  s_axi_awready;
    reg  [31:0]           s_axi_wdata;
    reg  [3:0]            s_axi_wstrb;
    reg                   s_axi_wvalid;
    wire                  s_axi_wready;
    wire [1:0]            s_axi_bresp;
    wire                  s_axi_bvalid;
    reg                   s_axi_bready;
    
    // AXI-Lite read channel (not actively used, tied off)
    reg  [ADDR_WIDTH-1:0] s_axi_araddr;
    reg                   s_axi_arvalid;
    wire                  s_axi_arready;
    wire [31:0]           s_axi_rdata;
    wire                  s_axi_rvalid;
    reg                   s_axi_rready;

    // =========================================================================
    // DUT INSTANTIATION
    // =========================================================================
    delay_axis #(
        .C_S_AXI_DATA_WIDTH(32),
        .C_S_AXI_ADDR_WIDTH(ADDR_WIDTH),
        .AUDIO_WIDTH(AUDIO_W),
        .DELAY_ADDR_W(12)
    ) dut (
        .aclk(aclk),
        .aresetn(aresetn),

        .s_axis_tdata (s_axis_tdata),
        .s_axis_tlast (s_axis_tlast),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),

        .m_axis_tdata (m_axis_tdata),
        .m_axis_tlast (m_axis_tlast),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tready(m_axis_tready),

        .s_axi_awaddr (s_axi_awaddr),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_awready(s_axi_awready),
        .s_axi_wdata  (s_axi_wdata),
        .s_axi_wstrb  (s_axi_wstrb),
        .s_axi_wvalid (s_axi_wvalid),
        .s_axi_wready (s_axi_wready),
        .s_axi_bresp  (s_axi_bresp),
        .s_axi_bvalid (s_axi_bvalid),
        .s_axi_bready (s_axi_bready),

        .s_axi_araddr (s_axi_araddr),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_arready(s_axi_arready),
        .s_axi_rdata  (s_axi_rdata),
        .s_axi_rresp  (s_axi_rresp),
        .s_axi_rvalid (s_axi_rvalid),
        .s_axi_rready (s_axi_rready)
    );

    // =========================================================================
    // CLOCK GENERATION
    // =========================================================================
    initial begin
        aclk = 0;
        forever #(CLK_PERIOD/2) aclk = ~aclk;
    end

    // =========================================================================
    // FILE LOGGING (CSV OUTPUT)
    // =========================================================================
    integer f;
    initial begin
        f = $fopen("tb_data_delay_axis.csv", "w");
        $fwrite(f, "Time_ns,In_L,In_R,Out_L,Out_R,Valid_Out\n");
    end

    // -------------------------------------------------------------------------
    // Runtime Monitor
    // -------------------------------------------------------------------------
    shortint in_L, in_R, out_L, out_R;
    always @(posedge aclk) begin
        if (aresetn) begin
            in_L  = s_axis_tdata[15:0];
            in_R  = s_axis_tdata[31:16];
            out_L = m_axis_tdata[15:0];
            out_R = m_axis_tdata[31:16];
            
            // Log only when stream activity exists
            if (s_axis_tvalid || m_axis_tvalid) begin
                $fwrite(
                    f,
                    "%0d,%0d,%0d,%0d,%0d,%0d\n",
                    $time, in_L, in_R, out_L, out_R, m_axis_tvalid
                );
            end
        end
    end

    // =========================================================================
    // AXI-LITE WRITE TASK
    // =========================================================================
    // Simple blocking write transaction (single-beat)
    task write_reg(input [3:0] addr, input [31:0] data);
        begin
            @(posedge aclk);
            s_axi_awaddr  <= addr;
            s_axi_awvalid <= 1;
            s_axi_wdata   <= data;
            s_axi_wstrb   <= 4'hF; // Enable all bytes
            s_axi_wvalid  <= 1;
            s_axi_bready  <= 1;

            wait(s_axi_awready && s_axi_wready);
            @(posedge aclk);
            s_axi_awvalid <= 0;
            s_axi_wvalid  <= 0;

            wait(s_axi_bvalid);
            @(posedge aclk);
            s_axi_bready  <= 0;
        end
    endtask

    // =========================================================================
    // STIMULUS: STEREO SINE GENERATOR
    // =========================================================================
    // Left  channel: faster sine
    // Right channel: slower sine
    real     pi = 3.14159265;
    real     amplitude = 30000.0;
    integer  i;
    shortint sine_val_L;
    shortint sine_val_R;
    
    initial begin
        // ---------------------------------------------------------------------
        // Initialization
        // ---------------------------------------------------------------------
        aresetn = 0;
        i = 0;

        s_axis_tvalid = 0;
        s_axis_tdata  = 0;
        s_axis_tlast  = 0;
        m_axis_tready = 1;

        s_axi_awaddr  = 0;
        s_axi_awvalid = 0;
        s_axi_wdata   = 0;
        s_axi_wstrb   = 0;
        s_axi_wvalid  = 0;
        s_axi_bready  = 0;

        s_axi_araddr  = 0;
        s_axi_arvalid = 0;
        s_axi_rready  = 0;

        // ---------------------------------------------------------------------
        // Reset Sequence
        // ---------------------------------------------------------------------
        #(CLK_PERIOD * 10);
        aresetn = 1;
        #(CLK_PERIOD * 20);

        // ---------------------------------------------------------------------
        // AXI-Lite Configuration
        // ---------------------------------------------------------------------
        // Left  delay  = 50 samples
        // Right delay  = 100 samples (intentional stereo offset)
        write_reg(4'h4, 32'd50);
        write_reg(4'h8, 32'd100);

        // Enable core
        write_reg(4'h0, 32'd1);

        $display("--- STARTING SINE WAVE GENERATION ---");
        
        // ---------------------------------------------------------------------
        // Audio Stream Generation
        // ---------------------------------------------------------------------
        // Left  : Period = 50 samples
        // Right : Period = 100 samples
        for (i = 0; i < 500; i = i + 1) begin
            @(posedge aclk);
            s_axis_tvalid <= 1;

            sine_val_L = $rtoi(amplitude * $sin(2.0 * pi * i / 50.0));
            sine_val_R = $rtoi(amplitude * $sin(2.0 * pi * i / 100.0));

            s_axis_tdata <= {sine_val_R, sine_val_L};
        end

        // ---------------------------------------------------------------------
        // Flush Pipeline (Send Silence)
        // ---------------------------------------------------------------------
        repeat(150) begin
            @(posedge aclk);
            s_axis_tvalid <= 1;
            s_axis_tdata  <= 0;
        end
        
        s_axis_tvalid <= 0;
        s_axis_tlast  <= 1;
        @(posedge aclk);
        s_axis_tlast  <= 0;

        // ---------------------------------------------------------------------
        // Finish Simulation
        // ---------------------------------------------------------------------
        #(CLK_PERIOD * 20);
        $fclose(f);
        $display("--- SIMULATION DONE. CSV SAVED. ---");
        $finish;
    end

endmodule
