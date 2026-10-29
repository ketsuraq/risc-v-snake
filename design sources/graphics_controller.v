`timescale 1ns / 1ps

module graphics_controller(
        input wire clk,
        input wire reset,
        input wire write_x,
        input wire write_y,
        input wire [31:0] write_data,
        
        output reg [9:0] square_x,
        output reg [9:0] square_y
    );
    
    // non-blocking assignments are used with sequential logic
    always @(posedge clk) begin
        if (reset) begin
            square_x <= 10'd240;
            square_y <= 10'd160;
        end
        else begin
            if (write_x) begin
                square_x <= write_data[9:0];
            end
            if (write_y) begin
                square_y <= write_data[9:0];
            end
        end
        
    end
    
endmodule
