`timescale 1ns / 1ps

module led_controller (
    input wire clk,
    input wire reset,
    input wire write_enable,
    input wire [31:0] write_data,
    output reg [3:0] led
);

    // store led states
    always @(posedge clk) begin
        if (reset)
            led <= 4'b0000;
        else if (write_enable)
            led <= write_data[3:0];
    end

endmodule
