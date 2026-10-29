`timescale 1ns / 1ps

module instruction_memory (
    input wire [31:0] address,
    output wire [31:0] instruction
);

    // init memory
    reg [31:0] memory [0:255];

    // assembly -> python assembler into hex -> read from hex file
    initial begin
        $readmemh("program.mem", memory);
    end
    
    

    // div by 4 to store in memory address
    assign instruction = memory[address[9:2]];

endmodule