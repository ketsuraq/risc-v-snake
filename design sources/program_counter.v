`timescale 1ns / 1ps

module program_counter (
    input wire clk,
    input wire reset,
    input wire enable,
    input wire jump_taken,
    input wire [31:0] jump_target,
    output reg [31:0] pc
);

    // increment pc by 4 (32 bits for risc-v)
    always @(posedge clk) begin
        if (reset)
            pc <= 32'd0;
        else if (!enable)
            pc <= pc;
        else if (jump_taken)
            pc <= jump_target;
        else
            pc <= pc + 32'd4;
    end

endmodule
