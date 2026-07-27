/*
 * QRNG Top-Level Testbench
 * 
 * Simulates the complete QRNG system with random pulse inputs
 * 
 * Author: Abhishek
 * License: MIT
 */

`timescale 1ns / 1ps
`include "../rtl/qrng_top.v"
module tb_qrng_top;

    //=========================================================================
    // Parameters
    //=========================================================================
    
    parameter CLK_PERIOD = 83.333;  // 12 MHz = 83.333ns
    parameter SIM_TIME = 1_000_000; // 1ms simulation
    
    //=========================================================================
    // Signals
    //=========================================================================
    
    // Clock and reset
    reg clk_12m;
    reg rst_n;
    
    // APD input
    reg apd_pulse;
    
    // SPI interface
    reg  spi_clk;
    reg  spi_mosi;
    wire spi_miso;
    reg  spi_cs_n;
    
    // UART interface
    reg  uart_rx;
    wire uart_tx;
    
    // LEDs
    wire led_health;
    wire led_data;
    wire led_error;
    
    // Debug
    wire dbg_tdc_pulse;
    wire dbg_entropy_valid;
    
    //=========================================================================
    // DUT Instantiation
    //=========================================================================
    
    qrng_top dut (
        .clk_12m(clk_12m),
        .rst_n(rst_n),
        .apd_pulse(apd_pulse),
        .spi_clk(spi_clk),
        .spi_mosi(spi_mosi),
        .spi_miso(spi_miso),
        .spi_cs_n(spi_cs_n),
        .uart_rx(uart_rx),
        .uart_tx(uart_tx),
        .led_health(led_health),
        .led_data(led_data),
        .led_error(led_error),
        .dbg_tdc_pulse(dbg_tdc_pulse),
        .dbg_entropy_valid(dbg_entropy_valid)
    );
    
    //=========================================================================
    // Clock Generation
    //=========================================================================
    
    initial begin
        clk_12m = 0;
        forever #(CLK_PERIOD/2) clk_12m = ~clk_12m;
    end
    
    //=========================================================================
    // Random Pulse Generation
    //=========================================================================
    
    // Simulate avalanche photodiode with random inter-arrival times
    integer seed;
    real mean_interval;
    real interval;
    
    initial begin
        seed = 12345;
        mean_interval = 10000;  // 10µs average inter-arrival time
        apd_pulse = 0;
        
        // Wait for reset
        @(posedge rst_n);
        #1000;
        
        forever begin
            // Exponential distribution for Poisson-like arrivals
            interval = -mean_interval * $ln(1.0 - $random(seed) / 4294967296.0);
            if (interval < 100) interval = 100;  // Minimum 100ns
            if (interval > 100000) interval = 100000;  // Maximum 100µs
            
            #(interval);
            apd_pulse = 1;
            #50;  // 50ns pulse width
            apd_pulse = 0;
        end
    end
    
    //=========================================================================
    // SPI Master Task
    //=========================================================================
    
    parameter SPI_PERIOD = 1000;  // 1 MHz SPI clock
    
    task spi_transfer;
        input [7:0] tx_byte;
        output [7:0] rx_byte;
        integer i;
        begin
            rx_byte = 8'h00;
            spi_cs_n = 0;
            #(SPI_PERIOD/2);
            
            for (i = 7; i >= 0; i = i - 1) begin
                spi_mosi = tx_byte[i];
                spi_clk = 0;
                #(SPI_PERIOD/2);
                spi_clk = 1;
                rx_byte[i] = spi_miso;
                #(SPI_PERIOD/2);
            end
            
            spi_clk = 0;
            #(SPI_PERIOD/2);
            spi_cs_n = 1;
            #(SPI_PERIOD);
        end
    endtask
    
    //=========================================================================
    // Test Sequence
    //=========================================================================
    
    reg [7:0] rx_data;
    integer i;
    integer entropy_count;
    
    initial begin
        // Initialize
        rst_n = 0;
        spi_clk = 0;
        spi_mosi = 0;
        spi_cs_n = 1;
        uart_rx = 1;
        entropy_count = 0;
        
        $display("===========================================");
        $display("QRNG Testbench Starting");
        $display("===========================================");
        
        // Reset sequence
        #1000;
        rst_n = 1;
        $display("[%0t] Reset released", $time);
        
        // Wait for PLL lock (simulated)
        #10000;
        $display("[%0t] PLL locked", $time);
        
        // Wait for some entropy to accumulate
        #100000;
        
        // Read status
        $display("\n--- SPI Status Read ---");
        spi_transfer(8'h10, rx_data);  // CMD_STATUS
        spi_transfer(8'h00, rx_data);  // Get response
        $display("[%0t] Status: 0x%02x (Health:%b, Data:%b, Full:%b)", 
                 $time, rx_data, rx_data[7], rx_data[6], rx_data[5]);
        
        // Read health
        spi_transfer(8'h11, rx_data);  // CMD_HEALTH
        spi_transfer(8'h00, rx_data);
        $display("[%0t] Rep Count: %d", $time, rx_data);
        
        // Read FIFO count
        spi_transfer(8'h12, rx_data);  // CMD_COUNT
        spi_transfer(8'h00, rx_data);
        $display("[%0t] FIFO Count: %d", $time, rx_data);
        
        // Read some entropy bytes
        $display("\n--- Reading Entropy Bytes ---");
        for (i = 0; i < 16; i = i + 1) begin
            spi_transfer(8'h01, rx_data);  // CMD_READ_BYTE
            spi_transfer(8'h00, rx_data);
            $display("[%0t] Entropy[%0d]: 0x%02x", $time, i, rx_data);
            if (rx_data != 8'hFF) entropy_count = entropy_count + 1;
        end
        
        // Continue simulation
        #(SIM_TIME - $time);
        
        // Final report
        $display("\n===========================================");
        $display("Simulation Complete");
        $display("===========================================");
        $display("Health LED: %b", led_health);
        $display("Data LED: %b", led_data);
        $display("Error LED: %b", led_error);
        $display("Entropy bytes read: %d", entropy_count);
        $display("===========================================");
        
        $finish;
    end
    
    //=========================================================================
    // Monitors
    //=========================================================================
    
    // Monitor entropy valid pulses
    always @(posedge dbg_entropy_valid) begin
        $display("[%0t] Entropy byte generated", $time);
    end
    
    // Monitor APD pulses
    integer pulse_count;
    initial pulse_count = 0;
    always @(posedge apd_pulse) begin
        pulse_count = pulse_count + 1;
        if (pulse_count % 10 == 0) begin
            $display("[%0t] APD pulse count: %d", $time, pulse_count);
        end
    end
    
    //=========================================================================
    // Waveform Dump
    //=========================================================================
    
    initial begin
        $dumpfile("tb_qrng_top.vcd");
        $dumpvars(0, tb_qrng_top);
    end

endmodule
