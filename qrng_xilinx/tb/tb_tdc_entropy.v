/*
 * TDC Entropy Module Testbench
 * 
 * Unit test for the Time-to-Digital Converter entropy extraction
 * 
 * Author: Abhishek
 * License: MIT
 */

`timescale 1ns / 1ps
`include "../rtl/tdc_entropy.v"
   
module tb_tdc_entropy();

    //=========================================================================
    // Parameters
    //=========================================================================
    
    parameter CLK_PERIOD = 10;  // 100 MHz
     parameter CLK_FREQ_MHZ = 100;
    //=========================================================================
    // Signals
    //=========================================================================
    
    reg clk;
    reg rst;
    
    wire timestamp_valid;
    wire [7:0] rep_count;

    // Internal signals
    wire [127:0] entropy_byte;
    wire entropy_valid;
    wire entropy_ready;
    reg entropy_ready_reg; 
    wire fifo_overflow;
    wire fifo_empty;
    wire [15:0] event_count;
    wire [15:0] rate_counter;
    
    wire health_ok;
    wire [15:0] health_ones;
    wire [7:0] health_max_rep;
    // Photon detector
    reg photon_pulse;
    
    // UART output
    wire uart_tx;
    wire uart_rx;
    
    // Status LEDs
    wire led_activity;
    wire led_error;
    wire led_health_ok;
    //=========================================================================
    // DUT
    //=========================================================================
    
    // TDC and entropy extraction
    tdc_entropy_extractor #(
        .CLK_FREQ_MHZ(CLK_FREQ_MHZ)
    ) tdc_inst (
        .clk(clk),
        .rst_n(rst),
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
        .rst_n(rst),
        .entropy_byte(entropy_byte),
        .entropy_valid(entropy_valid),
        .health_ok(health_ok),
        .ones_count(health_ones),
        .max_repetition(health_max_rep),
        .health_fail_repetition(),
        .health_fail_proportion()
    );
    
    //=========================================================================
    // Clock
    //=========================================================================
    
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    //=========================================================================
    // Test
    //=========================================================================
    
    integer seed;
    integer i;
    integer entropy_count;
    real interval;
    
    initial begin
        seed = 42;
        rst = 1;
        photon_pulse = 0;
        entropy_count = 0;
        
        $display("TDC Entropy Testbench");
        $display("=====================");
        
        // Reset
        #100;
        rst = 0;
        #100;
        rst = 1; 
        $display("Generating random pulses...");
        
        // Generate 100 random pulses
        for (i = 0; i < 10000; i = i + 1) begin
            // Random interval between 1-10 µs
            interval = 1000 + ($urandom(seed) % 9000);
            #(interval);
            photon_pulse = 1;
            #50;
            photon_pulse = 0;
            seed = seed+interval;
        end
        
        // Wait for processing
        #100000000;
        
        $display("\n--- Results ---");
        $display("Entropy bytes generated: %d", entropy_count);
        $display("Health OK: %b", health_ok);
        $display("Rep count: %d", rep_count);
        
        $finish;
    end
    // Count entropy bytes
    always @(posedge clk) begin
        if (entropy_valid) begin
            entropy_count = entropy_count + 1;
            $display("%b",entropy_byte);
            entropy_ready_reg = 1;
        end
    end
    assign entropy_ready = entropy_ready_reg;
    // Dump waveforms
    initial begin
        $dumpfile("tb_tdc_entropy.vcd");
        $dumpvars(0, tb_tdc_entropy);
    end

endmodule
