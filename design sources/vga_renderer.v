`timescale 1ns / 1ps

module vga_renderer (
    input wire clk,
    input wire reset,
    input wire video_active,
    input wire [7:0] tile_read_data,

    output reg [3:0] red,
    output reg [3:0] green,
    output reg [3:0] blue
);

    // select colour based on tile type
    always @(*) begin
        red   = 4'h0;
        green = 4'h0;
        blue  = 4'h0;

        if (video_active) begin
            case (tile_read_data)
                8'd0: begin // empty
                    red   = 4'h0;
                    green = 4'h0;
                    blue  = 4'h0;
                end

                8'd1: begin // snake body
                    green = 4'hA;
                end

                8'd2: begin // snake head
                    green = 4'hF;
                end

                8'd3: begin // food
                    red = 4'hF;
                end

                8'd4: begin // wall
                    red   = 4'hF;
                    green = 4'hF;
                    blue  = 4'hF;
                end

                default: begin
                    red   = 4'h0;
                    green = 4'h0;
                    blue  = 4'h0;
                end
            endcase
        end
    end

endmodule