/*
 * UART Transceiver
 * 
 * Simple UART with configurable baud rate
 * 8N1 format (8 data bits, no parity, 1 stop bit)
 * 
 * Author: Abhishek
 * License: MIT
 */

module uart #(
    parameter CLK_FREQ  = 100_000_000,  // System clock frequency
    parameter BAUD_RATE = 115200         // Baud rate
)(
    input  wire       clk,
    input  wire       rst,
    
    // Serial interface
    input  wire       rx,
    output reg        tx,
    
    // Parallel interface - Receive
    output reg  [7:0] rx_data,
    output reg        rx_valid,
    
    // Parallel interface - Transmit
    input  wire [7:0] tx_data,
    input  wire       tx_start,
    output wire       tx_busy
);

    //=========================================================================
    // Baud Rate Generator
    //=========================================================================
    
    localparam BAUD_DIV = CLK_FREQ / BAUD_RATE;
    localparam BAUD_DIV_HALF = BAUD_DIV / 2;
    localparam DIV_WIDTH = $clog2(BAUD_DIV);
    
    //=========================================================================
    // Receiver
    //=========================================================================
    
    // Input synchronization
    reg [2:0] rx_sync;
    always @(posedge clk) rx_sync <= {rx_sync[1:0], rx};
    wire rx_bit = rx_sync[2];
    
    // RX state machine
    localparam RX_IDLE  = 2'b00;
    localparam RX_START = 2'b01;
    localparam RX_DATA  = 2'b10;
    localparam RX_STOP  = 2'b11;
    
    reg [1:0] rx_state;
    reg [DIV_WIDTH-1:0] rx_counter;
    reg [2:0] rx_bit_idx;
    reg [7:0] rx_shift;
    
    always @(posedge clk) begin
        if (rst) begin
            rx_state <= RX_IDLE;
            rx_counter <= 0;
            rx_bit_idx <= 0;
            rx_shift <= 0;
            rx_data <= 0;
            rx_valid <= 0;
        end else begin
            rx_valid <= 0;
            
            case (rx_state)
                RX_IDLE: begin
                    rx_counter <= 0;
                    rx_bit_idx <= 0;
                    if (!rx_bit) begin  // Start bit detected
                        rx_state <= RX_START;
                    end
                end
                
                RX_START: begin
                    if (rx_counter == BAUD_DIV_HALF - 1) begin
                        rx_counter <= 0;
                        if (!rx_bit) begin  // Verify start bit
                            rx_state <= RX_DATA;
                        end else begin
                            rx_state <= RX_IDLE;  // False start
                        end
                    end else begin
                        rx_counter <= rx_counter + 1;
                    end
                end
                
                RX_DATA: begin
                    if (rx_counter == BAUD_DIV - 1) begin
                        rx_counter <= 0;
                        rx_shift <= {rx_bit, rx_shift[7:1]};  // LSB first
                        if (rx_bit_idx == 7) begin
                            rx_state <= RX_STOP;
                        end else begin
                            rx_bit_idx <= rx_bit_idx + 1;
                        end
                    end else begin
                        rx_counter <= rx_counter + 1;
                    end
                end
                
                RX_STOP: begin
                    if (rx_counter == BAUD_DIV - 1) begin
                        rx_counter <= 0;
                        rx_state <= RX_IDLE;
                        if (rx_bit) begin  // Valid stop bit
                            rx_data <= rx_shift;
                            rx_valid <= 1;
                        end
                    end else begin
                        rx_counter <= rx_counter + 1;
                    end
                end
            endcase
        end
    end
    
    //=========================================================================
    // Transmitter
    //=========================================================================
    
    // TX state machine
    localparam TX_IDLE  = 2'b00;
    localparam TX_START = 2'b01;
    localparam TX_DATA  = 2'b10;
    localparam TX_STOP  = 2'b11;
    
    reg [1:0] tx_state;
    reg [DIV_WIDTH-1:0] tx_counter;
    reg [2:0] tx_bit_idx;
    reg [7:0] tx_shift;
    
    assign tx_busy = (tx_state != TX_IDLE);
    
    always @(posedge clk) begin
        if (rst) begin
            tx_state <= TX_IDLE;
            tx_counter <= 0;
            tx_bit_idx <= 0;
            tx_shift <= 0;
            tx <= 1;  // Idle high
        end else begin
            case (tx_state)
                TX_IDLE: begin
                    tx <= 1;
                    tx_counter <= 0;
                    tx_bit_idx <= 0;
                    if (tx_start) begin
                        tx_shift <= tx_data;
                        tx_state <= TX_START;
                    end
                end
                
                TX_START: begin
                    tx <= 0;  // Start bit
                    if (tx_counter == BAUD_DIV - 1) begin
                        tx_counter <= 0;
                        tx_state <= TX_DATA;
                    end else begin
                        tx_counter <= tx_counter + 1;
                    end
                end
                
                TX_DATA: begin
                    tx <= tx_shift[0];  // LSB first
                    if (tx_counter == BAUD_DIV - 1) begin
                        tx_counter <= 0;
                        tx_shift <= {1'b0, tx_shift[7:1]};
                        if (tx_bit_idx == 7) begin
                            tx_state <= TX_STOP;
                        end else begin
                            tx_bit_idx <= tx_bit_idx + 1;
                        end
                    end else begin
                        tx_counter <= tx_counter + 1;
                    end
                end
                
                TX_STOP: begin
                    tx <= 1;  // Stop bit
                    if (tx_counter == BAUD_DIV - 1) begin
                        tx_counter <= 0;
                        tx_state <= TX_IDLE;
                    end else begin
                        tx_counter <= tx_counter + 1;
                    end
                end
            endcase
        end
    end

endmodule
