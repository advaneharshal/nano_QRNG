/*
 * QRNG Top-Level Module
 * 
 * Quantum Random Number Generator - Top Level Design
 * Target: Lattice iCE40HX8K
 * 
 * Author: Abhishek
 * License: MIT
 */
// =============================================================================
// Top-Level QRNG Module
// =============================================================================
`include "tdc_entropy.v"
module qrng_top #(
    parameter CLK_FREQ_MHZ = 100
)(
    input wire clk,
    input wire rst_n,
    
    // Photon detector
    input wire photon_pulse,
    
    // UART output
    output wire uart_tx,
    input wire uart_rx,
    
    // Status LEDs
    output wire led_activity,
    output wire led_error,
    output wire led_health_ok,
    output wire entropy_valid,
    output wire [3:0] digit_pos,
    output wire[7:0] entropy_seg_out
);

    // Internal signals
    reg entropy_ready;
    reg [7:0] entropy_seg_0; 
    reg [7:0] entropy_seg_1; 
    reg [7:0] entropy_seg_2; 
    reg [7:0] entropy_seg_3; 
    reg [7:0] entropy_seg; 
    wire [127:0] entropy_byte; 
    wire fifo_overflow;
    wire fifo_empty;
    wire [15:0] event_count;
    wire [15:0] rate_counter;
    reg [3:0]digit_pos_reg; 
    wire health_ok;
    wire [15:0] health_ones;
    wire [7:0] health_max_rep;
    
    // Use the upper bits of the counter to select the digit
    wire [1:0] active_digit = refresh_counter[18:17];
    reg [19:0] refresh_counter; 
    // TDC and entropy extraction
    tdc_entropy_extractor #(
        .CLK_FREQ_MHZ(CLK_FREQ_MHZ)
    ) tdc_inst (
        .clk(clk),
        .rst_n(rst_n),
        .photon_pulse(photon_pulse),
        .entropy_byte(entropy_byte),
        .entropy_valid(entropy_valid),
        .entropy_ready(entropy_ready),
        .fifo_overflow(fifo_overflow),
        .fifo_empty(fifo_empty),
        .event_count(event_count),
        .rate_counter(rate_counter),
        .last_timestamp(),
        .fifo_level()
    );
    
    // Health monitoring
    health_monitor health_inst (
        .clk(clk),
        .rst_n(rst_n),
        .entropy_byte(entropy_byte),
        .entropy_valid(entropy_valid),
        .health_ok(health_ok),
        .ones_count(health_ones),
        .max_repetition(health_max_rep),
        .health_fail_repetition(),
        .health_fail_proportion()
    );
    
    // LED outputs
    assign led_activity = ~fifo_empty;
    assign led_error = fifo_overflow;
    assign led_health_ok = health_ok;
    
    // Simple entropy ready - always accept when valid
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            entropy_ready <= 1;
        end else begin
            entropy_ready <= 1;  // Always ready to accept
        end
    end
    
    // TODO: Add UART transmitter for output
    // TODO: Add SHA-3 conditioner (can use external MCU)
    
    assign uart_tx = 1'b1;  // Idle high (placeholder)
        always @(posedge clk) begin
            case (entropy_byte[3:0])
            4'h0: entropy_seg_0 = 8'b00000011; // Display 0 (g off)
            4'h1: entropy_seg_0 = 8'b10011111; // Display 1 (b, c on)
            4'h2: entropy_seg_0 = 8'b00100101; // Display 2
            4'h3: entropy_seg_0 = 8'b00001101; // Display 3
            4'h4: entropy_seg_0 = 8'b10011001; // Display 4
            4'h5: entropy_seg_0 = 8'b01001001; // Display 5
            4'h6: entropy_seg_0 = 8'b01000001; // Display 6
            4'h7: entropy_seg_0 = 8'b00011111; // Display 7
            4'h8: entropy_seg_0 = 8'b00000001; // Display 8
            4'h9: entropy_seg_0 = 8'b00001001; // Display 9
            4'hA: entropy_seg_0 = 8'b00010001; // Display A
            4'hB: entropy_seg_0 = 8'b11000001; // Display B
            4'hC: entropy_seg_0 = 8'b01100011; // Display C
            4'hD: entropy_seg_0 = 8'b10000101; // Display D
            4'hE: entropy_seg_0 = 8'b01100001; // Display E
            4'hF: entropy_seg_0 = 8'b01110001; // Display F
            default: entropy_seg_0 = 8'b11111111; // Blank for other inputs
        endcase
    end
    always @(posedge clk) begin
            case (entropy_byte[7:4])
            4'h0: entropy_seg_1 = 8'b00000011; // Display 0 (g off)
            4'h1: entropy_seg_1 = 8'b10011111; // Display 1 (b, c on)
            4'h2: entropy_seg_1 = 8'b00100101; // Display 2
            4'h3: entropy_seg_1 = 8'b00001101; // Display 3
            4'h4: entropy_seg_1 = 8'b10011001; // Display 4
            4'h5: entropy_seg_1 = 8'b01001001; // Display 5
            4'h6: entropy_seg_1 = 8'b01000001; // Display 6
            4'h7: entropy_seg_1 = 8'b00011111; // Display 7
            4'h8: entropy_seg_1 = 8'b00000001; // Display 8
            4'h9: entropy_seg_1 = 8'b00001001; // Display 9
            4'hA: entropy_seg_1 = 8'b00010001; // Display A
            4'hB: entropy_seg_1 = 8'b11000001; // Display B
            4'hC: entropy_seg_1 = 8'b01100011; // Display C
            4'hD: entropy_seg_1 = 8'b10000101; // Display D
            4'hE: entropy_seg_1 = 8'b01100001; // Display E
            4'hF: entropy_seg_1 = 8'b01110001; // Display F
            default: entropy_seg_1 = 8'b11111111; // Blank for other inputs
        endcase
    end
    always @(posedge clk) begin
            case (entropy_byte[11:8])
            4'h0: entropy_seg_2 = 8'b00000011; // Display 0 (g off)
            4'h1: entropy_seg_2 = 8'b10011111; // Display 1 (b, c on)
            4'h2: entropy_seg_2 = 8'b00100101; // Display 2
            4'h3: entropy_seg_2 = 8'b00001101; // Display 3
            4'h4: entropy_seg_2 = 8'b10011001; // Display 4
            4'h5: entropy_seg_2 = 8'b01001001; // Display 5
            4'h6: entropy_seg_2 = 8'b01000001; // Display 6
            4'h7: entropy_seg_2 = 8'b00011111; // Display 7
            4'h8: entropy_seg_2 = 8'b00000001; // Display 8
            4'h9: entropy_seg_2 = 8'b00001001; // Display 9
            4'hA: entropy_seg_2 = 8'b00010001; // Display A
            4'hB: entropy_seg_2 = 8'b11000001; // Display B
            4'hC: entropy_seg_2 = 8'b01100011; // Display C
            4'hD: entropy_seg_2 = 8'b10000101; // Display D
            4'hE: entropy_seg_2 = 8'b01100001; // Display E
            4'hF: entropy_seg_2 = 8'b01110001; // Display F
            default: entropy_seg_2 = 8'b11111111; // Blank for other inputs
        endcase
    end
    always @(posedge clk) begin
            case (entropy_byte[15:12])
            4'h0: entropy_seg_3 = 8'b00000011; // Display 0 (g off)
            4'h1: entropy_seg_3 = 8'b10011111; // Display 1 (b, c on)
            4'h2: entropy_seg_3 = 8'b00100101; // Display 2
            4'h3: entropy_seg_3 = 8'b00001101; // Display 3
            4'h4: entropy_seg_3 = 8'b10011001; // Display 4
            4'h5: entropy_seg_3 = 8'b01001001; // Display 5
            4'h6: entropy_seg_3 = 8'b01000001; // Display 6
            4'h7: entropy_seg_3 = 8'b00011111; // Display 7
            4'h8: entropy_seg_3 = 8'b00000001; // Display 8
            4'h9: entropy_seg_3 = 8'b00001001; // Display 9
            4'hA: entropy_seg_3 = 8'b00010001; // Display A
            4'hB: entropy_seg_3 = 8'b11000001; // Display B
            4'hC: entropy_seg_3 = 8'b01100011; // Display C
            4'hD: entropy_seg_3 = 8'b10000101; // Display D
            4'hE: entropy_seg_3 = 8'b01100001; // Display E
            4'hF: entropy_seg_3 = 8'b01110001; // Display F
            default: entropy_seg_3 = 8'b11111111; // Blank for other inputs
        endcase
    end
    // Refresh counter to cycle through digits (~1ms per digit)
    always @(posedge clk) refresh_counter <= refresh_counter + 1;

    always @(posedge clk) begin
        case(active_digit)
            2'b00: begin // Digit 0 (Rightmost) - Display 'D'
                digit_pos_reg = 4'b1000;
                entropy_seg = entropy_seg_0; // Segments: g f e d c b a (0 = ON)
            end
            2'b01: begin // Digit 1 - Display 'B'
                digit_pos_reg = 4'b0010;
                entropy_seg = entropy_seg_1; 
            end
            2'b10: begin // Digit 2 - OFF
                digit_pos_reg = 4'b0100;
                entropy_seg = entropy_seg_2; // All segments OFF
            end
            2'b11: begin // Digit 3 (Leftmost) - OFF
                digit_pos_reg = 4'b0001;
                entropy_seg = entropy_seg_3;
            end
        endcase
    end
    assign digit_pos = digit_pos_reg; 
    assign entropy_seg_out = entropy_seg;
endmodule
/*
module qrng_top (
    // Clock and Reset
    input  wire        clk_12m,        // 12 MHz external oscillator
    input  wire        rst_n,          // Active-low reset
    
    // Entropy Source Interface
    input  wire        apd_pulse,      // Avalanche photodiode pulse input
    
    // SPI Interface (to MCU)
    input  wire        spi_clk,
    input  wire        spi_mosi,
    output wire        spi_miso,
    input  wire        spi_cs_n,
    
    // UART Interface (debug)
    input  wire        uart_rx,
    output wire        uart_tx,
    
    // Status LEDs
    output wire        led_health,     // Health status (green)
    output wire        led_data,       // Data available (blue)
    output wire        led_error,      // Error indicator (red)
    
    // Debug outputs
    output wire        dbg_tdc_pulse,
    output wire        dbg_entropy_valid
);

    //=========================================================================
    // Clock Generation (PLL)
    //=========================================================================
    
    wire clk_100m;
    wire clk_locked;
    
    // iCE40 PLL - 12MHz to 100MHz
    SB_PLL40_CORE #(
        .FEEDBACK_PATH("SIMPLE"),
        .DIVR(4'b0000),         // DIVR = 0
        .DIVF(7'b1000010),      // DIVF = 66
        .DIVQ(3'b011),          // DIVQ = 3
        .FILTER_RANGE(3'b001)   // FILTER_RANGE = 1
    ) pll_inst (
        .LOCK(clk_locked),
        .RESETB(rst_n),
        .BYPASS(1'b0),
        .REFERENCECLK(clk_12m),
        .PLLOUTCORE(clk_100m)
    );
    
    // System clock and reset
    wire sys_clk = clk_100m;
    wire sys_rst = ~rst_n | ~clk_locked;
    
    //=========================================================================
    // Input Synchronization
    //=========================================================================
    
    reg [2:0] apd_sync;
    always @(posedge sys_clk) begin
        apd_sync <= {apd_sync[1:0], apd_pulse};
    end
    wire apd_sync_pulse = apd_sync[1] & ~apd_sync[2];  // Rising edge detect
    
    //=========================================================================
    // TDC Entropy Source
    //=========================================================================
    
    wire [31:0] tdc_timestamp;
    wire        tdc_valid;
    wire [7:0]  entropy_byte;
    wire        entropy_valid;
    wire        health_ok;
    wire [7:0]  rep_count;
    wire [15:0] adapt_count;
    
    tdc_entropy #(
        .TDC_BITS(32),
        .FIFO_DEPTH(64)
    ) tdc_inst (
        .clk(sys_clk),
        .rst(sys_rst),
        .pulse_in(apd_sync_pulse),
        .timestamp_out(tdc_timestamp),
        .timestamp_valid(tdc_valid),
        .entropy_byte(entropy_byte),
        .entropy_valid(entropy_valid),
        .health_ok(health_ok),
        .rep_count(rep_count),
        .adapt_count(adapt_count)
    );
    
    //=========================================================================
    // Entropy Buffer (FIFO)
    //=========================================================================
    
    wire [7:0]  fifo_data_out;
    wire        fifo_empty;
    wire        fifo_full;
    wire        fifo_rd_en;
    reg  [10:0] fifo_count;
    
    entropy_fifo #(
        .WIDTH(8),
        .DEPTH(1024)
    ) entropy_fifo_inst (
        .clk(sys_clk),
        .rst(sys_rst),
        .wr_en(entropy_valid & ~fifo_full),
        .wr_data(entropy_byte),
        .rd_en(fifo_rd_en),
        .rd_data(fifo_data_out),
        .empty(fifo_empty),
        .full(fifo_full),
        .count(fifo_count)
    );
    
    //=========================================================================
    // SPI Slave Interface
    //=========================================================================
    
    wire [7:0]  spi_rx_data;
    wire        spi_rx_valid;
    wire [7:0]  spi_tx_data;
    wire        spi_tx_load;
    wire        spi_tx_ready;
    
    spi_slave spi_inst (
        .clk(sys_clk),
        .rst(sys_rst),
        .spi_clk(spi_clk),
        .spi_mosi(spi_mosi),
        .spi_miso(spi_miso),
        .spi_cs_n(spi_cs_n),
        .rx_data(spi_rx_data),
        .rx_valid(spi_rx_valid),
        .tx_data(spi_tx_data),
        .tx_load(spi_tx_load),
        .tx_ready(spi_tx_ready)
    );
    
    //=========================================================================
    // Command Processor
    //=========================================================================
    
    // SPI Commands
    localparam CMD_NOP        = 8'h00;
    localparam CMD_READ_BYTE  = 8'h01;
    localparam CMD_READ_MULTI = 8'h02;
    localparam CMD_STATUS     = 8'h10;
    localparam CMD_HEALTH     = 8'h11;
    localparam CMD_COUNT      = 8'h12;
    localparam CMD_RESET      = 8'hFF;
    
    reg [7:0] cmd_reg;
    reg [7:0] response_data;
    reg       response_valid;
    
    always @(posedge sys_clk or posedge sys_rst) begin
        if (sys_rst) begin
            cmd_reg <= CMD_NOP;
            response_data <= 8'h00;
            response_valid <= 1'b0;
        end else begin
            response_valid <= 1'b0;
            
            if (spi_rx_valid) begin
                cmd_reg <= spi_rx_data;
                
                case (spi_rx_data)
                    CMD_READ_BYTE: begin
                        response_data <= fifo_data_out;
                        response_valid <= ~fifo_empty;
                    end
                    CMD_STATUS: begin
                        response_data <= {health_ok, ~fifo_empty, fifo_full, 5'b0};
                        response_valid <= 1'b1;
                    end
                    CMD_HEALTH: begin
                        response_data <= rep_count;
                        response_valid <= 1'b1;
                    end
                    CMD_COUNT: begin
                        response_data <= fifo_count[7:0];
                        response_valid <= 1'b1;
                    end
                    default: begin
                        response_data <= 8'hFF;
                        response_valid <= 1'b1;
                    end
                endcase
            end
        end
    end
    
    assign spi_tx_data = response_data;
    assign spi_tx_load = response_valid;
    assign fifo_rd_en = spi_rx_valid & (spi_rx_data == CMD_READ_BYTE) & ~fifo_empty;
    
    //=========================================================================
    // UART Debug Interface
    //=========================================================================
    
    wire [7:0] uart_rx_data;
    wire       uart_rx_valid;
    reg  [7:0] uart_tx_data;
    reg        uart_tx_start;
    wire       uart_tx_busy;
    
    uart #(
        .CLK_FREQ(100_000_000),
        .BAUD_RATE(115200)
    ) uart_inst (
        .clk(sys_clk),
        .rst(sys_rst),
        .rx(uart_rx),
        .tx(uart_tx),
        .rx_data(uart_rx_data),
        .rx_valid(uart_rx_valid),
        .tx_data(uart_tx_data),
        .tx_start(uart_tx_start),
        .tx_busy(uart_tx_busy)
    );
    
    //=========================================================================
    // LED Status
    //=========================================================================
    
    // Blink rate divider (100MHz / 2^24 ≈ 6Hz)
    reg [23:0] led_counter;
    always @(posedge sys_clk) led_counter <= led_counter + 1;
    
    // Health LED: solid green when healthy, blinking when warning
    assign led_health = health_ok ? 1'b1 : led_counter[23];
    
    // Data LED: on when FIFO has data, blink when nearly full
    assign led_data = fifo_full ? led_counter[22] : ~fifo_empty;
    
    // Error LED: on when health failed
    assign led_error = ~health_ok;
    
    //=========================================================================
    // Debug Outputs
    //=========================================================================
    
    assign dbg_tdc_pulse = apd_sync_pulse;
    assign dbg_entropy_valid = entropy_valid;

endmodule
*/
