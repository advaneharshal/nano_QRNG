/*
 * SPI Slave Interface
 * 
 * Mode 0: CPOL=0, CPHA=0
 * MSB first, active-low chip select
 * 
 * Author: Abhishek
 * License: MIT
 */

module spi_slave (
    input  wire       clk,          // System clock
    input  wire       rst,          // System reset
    
    // SPI signals
    input  wire       spi_clk,      // SPI clock from master
    input  wire       spi_mosi,     // Master Out Slave In
    output wire       spi_miso,     // Master In Slave Out
    input  wire       spi_cs_n,     // Chip select (active low)
    
    // Parallel interface
    output reg  [7:0] rx_data,      // Received data
    output reg        rx_valid,     // Received data valid pulse
    input  wire [7:0] tx_data,      // Data to transmit
    input  wire       tx_load,      // Load tx_data into shift register
    output wire       tx_ready      // Ready to accept new tx_data
);

    //=========================================================================
    // Input Synchronization
    //=========================================================================
    
    reg [2:0] spi_clk_sync;
    reg [2:0] spi_cs_sync;
    reg [1:0] spi_mosi_sync;
    
    always @(posedge clk) begin
        spi_clk_sync  <= {spi_clk_sync[1:0], spi_clk};
        spi_cs_sync   <= {spi_cs_sync[1:0], spi_cs_n};
        spi_mosi_sync <= {spi_mosi_sync[0], spi_mosi};
    end
    
    wire spi_clk_rise = spi_clk_sync[1] & ~spi_clk_sync[2];
    wire spi_clk_fall = ~spi_clk_sync[1] & spi_clk_sync[2];
    wire spi_active   = ~spi_cs_sync[2];
    wire spi_cs_rise  = spi_cs_sync[1] & ~spi_cs_sync[2];  // End of transfer
    wire mosi_data    = spi_mosi_sync[1];
    
    //=========================================================================
    // Shift Registers
    //=========================================================================
    
    reg [7:0] rx_shift;
    reg [7:0] tx_shift;
    reg [2:0] bit_count;
    
    // Receive shift register (sample on rising edge)
    always @(posedge clk) begin
        if (rst || !spi_active) begin
            rx_shift <= 8'h00;
            bit_count <= 3'b000;
        end else if (spi_clk_rise && spi_active) begin
            rx_shift <= {rx_shift[6:0], mosi_data};
            bit_count <= bit_count + 1;
        end
    end
    
    // Transmit shift register (shift on falling edge)
    always @(posedge clk) begin
        if (rst) begin
            tx_shift <= 8'hFF;
        end else if (tx_load) begin
            tx_shift <= tx_data;
        end else if (spi_clk_fall && spi_active) begin
            tx_shift <= {tx_shift[6:0], 1'b1};
        end else if (!spi_active) begin
            tx_shift <= tx_data;  // Pre-load for next transfer
        end
    end
    
    //=========================================================================
    // MISO Output
    //=========================================================================
    
    // Output MSB of shift register, directly from flip-flop for timing
    reg miso_reg;
    always @(posedge clk) begin
        if (rst || !spi_active) begin
            miso_reg <= 1'b1;
        end else if (spi_clk_fall || !spi_active) begin
            miso_reg <= tx_shift[7];
        end
    end
    
    // Tri-state when not selected
    assign spi_miso = spi_active ? miso_reg : 1'bz;
    
    //=========================================================================
    // Data Valid Detection
    //=========================================================================
    
    reg byte_complete;
    always @(posedge clk) begin
        if (rst) begin
            byte_complete <= 1'b0;
        end else begin
            byte_complete <= (bit_count == 3'b111) && spi_clk_rise && spi_active;
        end
    end
    
    // Output received byte
    always @(posedge clk) begin
        if (rst) begin
            rx_data <= 8'h00;
            rx_valid <= 1'b0;
        end else begin
            rx_valid <= byte_complete;
            if (byte_complete) begin
                rx_data <= {rx_shift[6:0], mosi_data};
            end
        end
    end
    
    //=========================================================================
    // Status
    //=========================================================================
    
    assign tx_ready = !spi_active;

endmodule
