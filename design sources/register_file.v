`timescale 1ns / 1ps

// writes and reads from registers
module register_file (
    input wire clk,
    input wire write_enable,

    input wire [4:0] rs1,
    input wire [4:0] rs2,
    input wire [4:0] rd,

    input wire [31:0] write_data,

    output wire [31:0] read_data1,
    output wire [31:0] read_data2
);

    // 32 registers, each 32 bits wide
    reg [31:0] registers [0:31];

    // reads source registers
    assign read_data1 = (rs1 == 0) ? 32'd0 : registers[rs1]; // x0 has to be 0
    assign read_data2 = (rs2 == 0) ? 32'd0 : registers[rs2];

    // if wite_enable and rd != 0, on next posedge writes to destination
    always @(posedge clk) begin
        if (write_enable && rd != 0)
            registers[rd] <= write_data;
    end

endmodule