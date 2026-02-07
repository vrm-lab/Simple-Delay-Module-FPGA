`timescale 1 ns / 1 ps

// ============================================================================
// Delay Core
// ----------------------------------------------------------------------------
// Simple circular-buffer based delay line.
// - Static delay via base_delay
// - Optional modulation via mod_val
// - Designed to infer Block RAM on Xilinx FPGA
// ----------------------------------------------------------------------------
// Notes:
// - No feedback path (pure delay)
// - Read pointer is derived from write pointer
// - Safe clamping is applied to avoid invalid memory access
// ============================================================================

module delay_core #(
    parameter DATA_W = 16,
    parameter ADDR_W = 12   // 2^12 = 4096 samples buffer
)(
    input  wire                 clk,
    input  wire                 rst_n,
    input  wire                 en,
    input  wire                 bypass,
    
    // ------------------------------------------------------------------------
    // Delay Control
    // ------------------------------------------------------------------------
    input  wire [ADDR_W-1:0]    base_delay, // Base delay (samples)
    input  wire signed [15:0]   mod_val,    // Modulation offset (0 = static)
    
    // ------------------------------------------------------------------------
    // Audio Data
    // ------------------------------------------------------------------------
    input  wire signed [DATA_W-1:0] din,
    output reg  signed [DATA_W-1:0] dout
);

    // ------------------------------------------------------------------------
    // 1. Memory (Circular Buffer)
    // ------------------------------------------------------------------------
    // Intended to be inferred as Block RAM by Vivado.
    reg signed [DATA_W-1:0] ram [0 : (1<<ADDR_W)-1];
    
    // ------------------------------------------------------------------------
    // Memory Initialization
    // ------------------------------------------------------------------------
    // Initialize buffer to zero at bitstream load:
    // - Avoids 'X' propagation in simulation
    // - Prevents audible artifacts ("clicks / crackles") on startup
    integer i;
    initial begin
        for (i = 0; i < (1<<ADDR_W); i = i + 1) begin
            ram[i] = {DATA_W{1'b0}};
        end
    end
    
    // ------------------------------------------------------------------------
    // 2. Read / Write Pointers
    // ------------------------------------------------------------------------
    reg [ADDR_W-1:0] wr_ptr;
    reg [ADDR_W-1:0] rd_ptr;

    // ------------------------------------------------------------------------
    // 3. Delay Calculation with Safety Clamp
    // ------------------------------------------------------------------------
    // Requested delay = base_delay + modulation
    // Computed as signed to allow negative modulation.
    wire signed [16:0] req_delay;
    
    // Sign extension for safe signed addition
    assign req_delay = {1'b0, base_delay} + {mod_val[15], mod_val};

    // ------------------------------------------------------------------------
    // Delay Clamping Logic
    // ------------------------------------------------------------------------
    // Ensures delay stays within valid RAM address range
    // - Prevents reading future samples
    // - Prevents address overflow
    reg [ADDR_W-1:0] safe_delay;
    localparam [ADDR_W-1:0] MAX_DELAY = {(ADDR_W){1'b1}}; // e.g. 4095

    always @(*) begin
        if (req_delay <= 0) begin
            // Minimum delay forced to 1 sample
            safe_delay = 12'd1;
        end else if (req_delay >= MAX_DELAY) begin
            // Maximum delay limited to buffer size
            safe_delay = MAX_DELAY;
        end else begin
            safe_delay = req_delay[ADDR_W-1:0];
        end
    end

    // ------------------------------------------------------------------------
    // 4. Main Sequential Process
    // ------------------------------------------------------------------------
    always @(posedge clk) begin
        if (!rst_n) begin
            // Reset state
            wr_ptr <= 0;
            rd_ptr <= 0;
            dout   <= 0;
        end else if (en) begin
            // A. Write incoming sample to buffer
            ram[wr_ptr] <= din;
            
            // B. Compute read pointer (circular wrap handled naturally)
            //    rd_ptr = wr_ptr - delay
            rd_ptr <= wr_ptr - safe_delay;
            
            // C. Output selection
            //    - bypass = direct path
            //    - normal = delayed sample
            if (bypass)
                dout <= din;
            else
                dout <= ram[rd_ptr]; // 1-cycle read latency
            
            // D. Advance write pointer
            wr_ptr <= wr_ptr + 1;
        end
    end

endmodule
