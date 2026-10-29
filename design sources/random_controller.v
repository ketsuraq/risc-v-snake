`timescale 1ns / 1ps

module random_controller (
    input wire clk,
    input wire reset,
    output reg [31:0] random_value = 32'hA5C3E271
);

    wire feedback;

    // x^32 + x^22 + x^2 + x + 1
    assign feedback =
        random_value[31] ^
        random_value[21] ^
        random_value[1] ^
        random_value[0];

    always @(posedge clk) begin
        if (reset)
            random_value <= 32'hA5C3E271;
        else
            random_value <= {random_value[30:0], feedback};
    end

endmodule