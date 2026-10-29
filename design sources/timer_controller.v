`timescale 1ns / 1ps

module timer_controller (
    input wire clk,
    input wire reset,
    output reg [31:0] timer_count
);

    always @(posedge clk) begin
        if (reset)
            timer_count <= 32'd0;
        else
            timer_count <= timer_count + 1'b1;
    end

endmodule