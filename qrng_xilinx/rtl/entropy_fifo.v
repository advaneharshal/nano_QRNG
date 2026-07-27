/*
 * Entropy FIFO Buffer
 * 
 * Simple synchronous FIFO for buffering entropy bytes
 * Implemented using iCE40 block RAM
 * 
 * Author: Abhishek
 * License: MIT
 */

module entropy_fifo #(
    parameter WIDTH = 8,
    parameter DEPTH = 1024,
    parameter ADDR_WIDTH = $clog2(DEPTH)
)(
    input  wire                  clk,
    input  wire                  rst,
    
    // Write interface
    input  wire                  wr_en,
    input  wire [WIDTH-1:0]      wr_data,
    
    // Read interface
    input  wire                  rd_en,
    output reg  [WIDTH-1:0]      rd_data,
    
    // Status
    output wire                  empty,
    output wire                  full,
    output reg  [ADDR_WIDTH:0]   count
);

    //=========================================================================
    // Memory and Pointers
    //=========================================================================
    
    reg [WIDTH-1:0] mem [0:DEPTH-1];
    reg [ADDR_WIDTH-1:0] wr_ptr;
    reg [ADDR_WIDTH-1:0] rd_ptr;
    
    //=========================================================================
    // Status Flags
    //=========================================================================
    
    assign empty = (count == 0);
    assign full  = (count == DEPTH);
    
    //=========================================================================
    // Write Logic
    //=========================================================================
    
    always @(posedge clk) begin
        if (rst) begin
            wr_ptr <= 0;
        end else if (wr_en && !full) begin
            mem[wr_ptr] <= wr_data;
            wr_ptr <= wr_ptr + 1;
        end
    end
    
    //=========================================================================
    // Read Logic
    //=========================================================================
    
    always @(posedge clk) begin
        if (rst) begin
            rd_ptr <= 0;
            rd_data <= 0;
        end else if (rd_en && !empty) begin
            rd_data <= mem[rd_ptr];
            rd_ptr <= rd_ptr + 1;
        end
    end
    
    //=========================================================================
    // Count Logic
    //=========================================================================
    
    always @(posedge clk) begin
        if (rst) begin
            count <= 0;
        end else begin
            case ({wr_en && !full, rd_en && !empty})
                2'b10: count <= count + 1;  // Write only
                2'b01: count <= count - 1;  // Read only
                default: count <= count;     // Both or neither
            endcase
        end
    end

endmodule
