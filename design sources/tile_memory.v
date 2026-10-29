`timescale 1ns / 1ps

module tile_memory(
        input wire clk,
        input wire reset,
        input wire write_enable,
        input wire [10:0] write_address,
        input wire [7:0] write_data,
    
        input wire [10:0] read_address,
        output reg [7:0] read_data
    );
    
        reg [7:0] memory [0:1199];
        
        // cpu writes one tile
        always @(posedge clk) begin
            if (write_enable)
                memory[write_address] <= write_data;
        end
    
        // vga reads one tile
        always @(posedge clk) begin
            read_data <= memory[read_address];
        end
endmodule
