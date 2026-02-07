`timescale 1 ns / 1 ps

// ============================================================================
// Testbench: delay_core
// ----------------------------------------------------------------------------
// Purpose:
// - Functional verification of delay_core
// - Covers static delay, signal integrity, modulation, boundary conditions,
//   and bypass behavior
// ----------------------------------------------------------------------------
// Output:
// - CSV log for offline inspection / plotting
// ============================================================================

module tb_delay_core;

    // ------------------------------------------------------------------------
    // Parameters
    // ------------------------------------------------------------------------
    parameter DATA_W      = 16;
    parameter ADDR_W      = 8;   // 2^8 = 256 samples (sufficient for simulation)
    parameter CLK_PERIOD  = 20;  // 50 MHz clock

    // ------------------------------------------------------------------------
    // DUT Signals
    // ------------------------------------------------------------------------
    reg                 clk;
    reg                 rst_n;
    reg                 en;
    reg                 bypass;
    
    // Delay control
    reg  [ADDR_W-1:0]   base_delay; // Base delay in samples
    reg  signed [15:0]  mod_val;    // Modulation input (e.g. LFO)
    
    // Audio data
    reg  signed [DATA_W-1:0] din;
    wire signed [DATA_W-1:0] dout;

    // ------------------------------------------------------------------------
    // File I/O
    // ------------------------------------------------------------------------
    integer file_h;

    // ------------------------------------------------------------------------
    // Unit Under Test
    // ------------------------------------------------------------------------
    delay_core #(
        .DATA_W(DATA_W),
        .ADDR_W(ADDR_W)
    ) uut (
        .clk        (clk),
        .rst_n      (rst_n),
        .en         (en),
        .bypass     (bypass),
        .base_delay (base_delay),
        .mod_val    (mod_val),
        .din        (din),
        .dout       (dout)
    );

    // ------------------------------------------------------------------------
    // Clock Generation
    // ------------------------------------------------------------------------
    always #(CLK_PERIOD/2) clk = ~clk;

    // ------------------------------------------------------------------------
    // CSV Logging
    // ------------------------------------------------------------------------
    // Logs input, output, and control parameters per clock cycle
    initial begin
        file_h = $fopen("tb_data_delay_core.csv", "w");
        $fdisplay(file_h, "time,din,dout,base_delay,mod_val,bypass");
        
        forever begin
            @(posedge clk);
            if (rst_n) begin
                $fdisplay(
                    file_h,
                    "%t,%d,%d,%d,%d,%b",
                    $time, din, dout, base_delay, mod_val, bypass
                );
            end
        end
    end

    // ------------------------------------------------------------------------
    // Test Stimulus
    // ------------------------------------------------------------------------
    integer i;
    real    phi;
    real    freq;
    
    initial begin
        // --------------------------------------------------------------------
        // Initialization
        // --------------------------------------------------------------------
        clk   = 0;
        rst_n = 0;
        en    = 1;
        bypass = 0;
        i     = 0;
        
        // Default delay configuration
        base_delay = 8'd50;   // 50 samples base delay
        mod_val    = 16'sd0;  // No modulation
        din        = 0;

        #(CLK_PERIOD * 5);
        rst_n = 1;
        #(CLK_PERIOD * 5);

        // --------------------------------------------------------------------
        // TEST 1: Impulse Response (Static Delay)
        // --------------------------------------------------------------------
        // Expectation:
        // - Output impulse appears after base_delay samples
        $display("TEST 1: Impulse Response (Static Delay)");
        din = 16'sd10000;
        @(posedge clk);
        din = 0;
        #(CLK_PERIOD * 100);

        // --------------------------------------------------------------------
        // TEST 2: Sine Wave Integrity (Static Delay)
        // --------------------------------------------------------------------
        // Expectation:
        // - Clean delayed sine wave
        // - No distortion or instability
        $display("TEST 2: Sine Wave (Static Delay)");
        freq = 0.05;
        for (i = 0; i < 100; i = i + 1) begin
            phi = 2.0 * 3.14159 * freq * i;
            din = $signed(16'sd8000 * $sin(phi));
            @(posedge clk);
        end

        // --------------------------------------------------------------------
        // TEST 3: Dynamic Delay Modulation
        // --------------------------------------------------------------------
        // Simulates vibrato / chorus-style modulation:
        // - base_delay = 50
        // - mod_val sweeps approximately from +50 to -50
        $display("TEST 3: Dynamic Modulation");
        for (i = 0; i < 200; i = i + 1) begin
            // Audio signal
            phi = 2.0 * 3.14159 * freq * i;
            din = $signed(16'sd8000 * $sin(phi));
            
            // Simple triangle-like modulation
            if (i < 50)
                mod_val = mod_val + 1;
            else if (i < 150)
                mod_val = mod_val - 1;
            else
                mod_val = mod_val + 1;
            
            @(posedge clk);
        end
        mod_val = 0;

        // --------------------------------------------------------------------
        // TEST 4: Boundary / Saturation Check
        // --------------------------------------------------------------------
        // Purpose:
        // - Ensure negative or excessive delay values are safely clamped
        $display("TEST 4: Saturation Check (Negative Delay)");
        mod_val = -16'sd100;  // base_delay + mod_val < 0
        din     = 16'sd20000;
        @(posedge clk);
        din = 0;
        #(CLK_PERIOD * 20);

        // --------------------------------------------------------------------
        // TEST 5: Bypass Mode
        // --------------------------------------------------------------------
        // Expectation:
        // - Output follows input directly
        $display("TEST 5: Bypass Mode");
        bypass = 1;
        din = 16'sd5000;
        @(posedge clk);
        din = 0;
        #(CLK_PERIOD * 10);

        // --------------------------------------------------------------------
        // Finish Simulation
        // --------------------------------------------------------------------
        $fclose(file_h);
        $display("Simulation complete. Output saved to tb_data_delay_core.csv");
        $finish;
    end

endmodule
