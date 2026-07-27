/**
 * QRNG - Time-to-Digital Converter (TDC) Module
 * FPGA Implementation for High-Resolution Timestamp Capture
 * 
 * Target: Lattice iCE40HX8K or similar
 * Clock: 100 MHz (10ns resolution)
 * 
 * Features:
 * - High-resolution timestamp capture
 * - LSB entropy extraction
 * - FIFO buffer for burst handling
 * - Health monitoring signals
 * 
 * Author: Abhishek
 * License: MIT
 */

module tdc_entropy_extractor #(
    parameter CLK_FREQ_MHZ = 100,        // Clock frequency
    parameter TIMESTAMP_BITS = 64,       // Timestamp counter width
    parameter ENTROPY_BITS = 128,          // Bits to extract per event
    parameter FIFO_DEPTH = 256           // Event FIFO depth
)(
    // Clock and reset
    input wire clk,                      // System clock
    input wire rst_n,                    // Active-low reset
    
    // Photon detector input
    input wire photon_pulse,             // TTL pulse from comparator
    
    // Entropy output interface
    output reg [127:0] entropy_byte,       // Extracted entropy byte
    output reg entropy_valid,            // Entropy byte valid
    input wire entropy_ready,            // Consumer ready for data
    
    // Status and health signals
    output wire fifo_overflow,           // FIFO overflow indicator
    output wire fifo_empty,              // FIFO empty indicator
    output reg [15:0] event_count,       // Total events counter
    output reg [15:0] rate_counter,      // Events per second
    
    // Debug outputs
    output wire [TIMESTAMP_BITS-1:0] last_timestamp,
    output wire [7:0] fifo_level
);

    // =========================================================================
    // Internal signals
    // =========================================================================
    
    // Timestamp counter (free-running)
    reg [TIMESTAMP_BITS-1:0] timestamp_counter;
    
    // Input synchronizer (2-stage for metastability)
    reg [2:0] photon_sync;
    wire photon_edge;
    
    // Captured timestamp
    reg [TIMESTAMP_BITS-1:0] captured_timestamp;
    reg capture_valid;
    
    // FIFO signals
    reg [TIMESTAMP_BITS-1:0] fifo_mem [0:FIFO_DEPTH-1];
    reg [$clog2(FIFO_DEPTH)-1:0] fifo_wr_ptr;
    reg [$clog2(FIFO_DEPTH)-1:0] fifo_rd_ptr;
    reg [$clog2(FIFO_DEPTH):0] fifo_count;
    reg fifo_overflow_reg;
    
    // Entropy extraction state machine
    reg [2:0] extract_state;
    localparam IDLE = 3'd0;
    localparam READ_FIFO = 3'd1;
    localparam EXTRACT = 3'd2;
    localparam OUTPUT = 3'd3;
    localparam WAIT_READY = 3'd4;
    
    // Entropy accumulator
    reg [TIMESTAMP_BITS-1:0] ts_for_extract;
    reg [31:0] bit_count;
    reg [127:0] entropy_accum;
    
    // Rate measurement
    reg [26:0] rate_timer;  // ~1 second at 100MHz
    reg [15:0] rate_events;
    
    // =========================================================================
    // Timestamp Counter
    // =========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            timestamp_counter <= 0;
        end else begin
            timestamp_counter <= timestamp_counter + 1;
        end
    end
    
    // =========================================================================
    // Input Synchronization & Edge Detection
    // =========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            photon_sync <= 3'b000;
        end else begin
            photon_sync <= {photon_sync[1:0], photon_pulse};
        end
    end
    
    // Detect rising edge
    assign photon_edge = photon_sync[1] & ~photon_sync[2];
    
    // =========================================================================
    // Timestamp Capture
    // =========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            captured_timestamp <= 0;
            capture_valid <= 0;
        end else begin
            capture_valid <= 0;
            
            if (photon_edge) begin
                captured_timestamp <= timestamp_counter;
                capture_valid <= 1;
            end
        end
    end
    
    // =========================================================================
    // FIFO Buffer
    // =========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fifo_wr_ptr <= 0;
            fifo_count <= 0;
            fifo_overflow_reg <= 0;
        end else begin
            fifo_overflow_reg <= 0;
            
            // Write to FIFO
            if (capture_valid) begin
                if (fifo_count < FIFO_DEPTH) begin
                    fifo_mem[fifo_wr_ptr] <= captured_timestamp;
                    fifo_wr_ptr <= fifo_wr_ptr + 1;
                    fifo_count <= fifo_count + 1;
                end else begin
                    fifo_overflow_reg <= 1;  // Overflow!
                end
            end
            
            // Read from FIFO (handled in extraction FSM)
            if (extract_state == READ_FIFO && fifo_count > 0) begin
                fifo_count <= fifo_count - 1;
            end
        end
    end
    
    assign fifo_overflow = fifo_overflow_reg;
    assign fifo_empty = (fifo_count == 0);
    assign fifo_level = fifo_count[7:0];
    assign last_timestamp = captured_timestamp;
    
    // =========================================================================
    // Entropy Extraction State Machine
    // =========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            extract_state <= IDLE;
            fifo_rd_ptr <= 0;
            ts_for_extract <= 0;
            bit_count <= 0;
            entropy_accum <= 0;
            entropy_byte <= 0;
            entropy_valid <= 0;
            event_count <= 0;
        end else begin
            entropy_valid <= 0;
            
            case (extract_state)
                IDLE: begin
                    if (fifo_count > 0) begin
                        extract_state <= READ_FIFO;
                    end
                end
                
                READ_FIFO: begin
                    ts_for_extract <= fifo_mem[fifo_rd_ptr];
                    fifo_rd_ptr <= fifo_rd_ptr + 1;
                    event_count <= event_count + 1;
                    extract_state <= EXTRACT;
                end
                
                EXTRACT: begin
                    // XOR multiple LSBs together for better uniformity
                    // Extract bits 0-3 and fold them
                    entropy_accum[bit_count] <= ts_for_extract[0] ^ 
                                                ts_for_extract[1] ^ 
                                                ts_for_extract[2] ^ 
                                                ts_for_extract[3];
                    
                    if (bit_count == 127) begin
                        bit_count <= 0;
                        extract_state <= OUTPUT;
                    end else begin
                        bit_count <= bit_count + 1;
                        extract_state <= IDLE;  // Need more timestamps
                    end
                end
                
                OUTPUT: begin
                    entropy_byte <= entropy_accum;
                    entropy_valid <= 1;
                    
                    if (entropy_ready) begin
                        extract_state <= IDLE;
                    end else begin
                        extract_state <= WAIT_READY;
                    end
                end
                
                WAIT_READY: begin
                    entropy_valid <= 1;
                    if (entropy_ready) begin
                        extract_state <= IDLE;
                    end
                end
                
                default: extract_state <= IDLE;
            endcase
        end
    end
    
    // =========================================================================
    // Rate Measurement (events per second)
    // =========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rate_timer <= 0;
            rate_events <= 0;
            rate_counter <= 0;
        end else begin
            if (rate_timer >= (CLK_FREQ_MHZ * 1000000 - 1)) begin
                // One second elapsed
                rate_counter <= rate_events;
                rate_events <= 0;
                rate_timer <= 0;
            end else begin
                rate_timer <= rate_timer + 1;
                if (capture_valid) begin
                    rate_events <= rate_events + 1;
                end
            end
        end
    end

endmodule

// =============================================================================
// Health Monitor Module
// =============================================================================

module health_monitor #(
    parameter WINDOW_SIZE = 1024,
    parameter REPETITION_CUTOFF = 31,
    parameter PROPORTION_MIN = 400,
    parameter PROPORTION_MAX = 624
)(
    input wire clk,
    input wire rst_n,
    
    // Entropy input
    input wire [7:0] entropy_byte,
    input wire entropy_valid,
    
    // Health status
    output reg health_ok,
    output reg [15:0] ones_count,
    output reg [7:0] max_repetition,
    output reg health_fail_repetition,
    output reg health_fail_proportion
);

    reg [10:0] sample_count;
    reg [7:0] current_run;
    reg last_bit;
    reg [2:0] bit_idx;
    reg current_bit;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sample_count <= 0;
            ones_count <= 0;
            max_repetition <= 1;
            current_run <= 1;
            last_bit <= 0;
            bit_idx <= 0;
            health_ok <= 1;
            health_fail_repetition <= 0;
            health_fail_proportion <= 0;
        end else if (entropy_valid) begin
            // Process each bit in the byte
            if (bit_idx == 0) begin
                // Start of new byte
                bit_idx <= 1;
            end
            
            // Extract current bit
            current_bit = entropy_byte[bit_idx];
            
            // Count ones
            if (current_bit) begin
                ones_count <= ones_count + 1;
            end
            
            // Repetition test
            if (current_bit == last_bit) begin
                current_run <= current_run + 1;
                if (current_run + 1 > max_repetition) begin
                    max_repetition <= current_run + 1;
                end
            end else begin
                current_run <= 1;
            end
            last_bit <= current_bit;
            
            // Advance bit counter
            if (bit_idx == 7) begin
                bit_idx <= 0;
                sample_count <= sample_count + 8;
            end else begin
                bit_idx <= bit_idx + 1;
            end
            
            // Check health at window boundary
            if (sample_count >= WINDOW_SIZE - 8) begin
                // Repetition test
                if (max_repetition > REPETITION_CUTOFF) begin
                    health_fail_repetition <= 1;
                    health_ok <= 0;
                end else begin
                    health_fail_repetition <= 0;
                end
                
                // Proportion test
                if (ones_count < PROPORTION_MIN || ones_count > PROPORTION_MAX) begin
                    health_fail_proportion <= 1;
                    health_ok <= 0;
                end else begin
                    health_fail_proportion <= 0;
                end
                
                // Reset for next window
                sample_count <= 0;
                ones_count <= 0;
                max_repetition <= 1;
                current_run <= 1;
                
                if (!health_fail_repetition && !health_fail_proportion) begin
                    health_ok <= 1;
                end
            end
        end
    end

endmodule


