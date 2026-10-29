`timescale 1ns / 1ps

module instruction_decoder (
    input wire [31:0] instruction, // fetches intruction

    output wire [6:0] opcode,
    output wire [4:0] rs1,
    output wire [4:0] rs2,
    output wire [4:0] rd,
    output wire [2:0] funct3,
    output wire [6:0] funct7,
    output wire [31:0] immediate,
    
    // outputs to support different type immediates
    output wire [31:0] branch_imm,
    output wire [31:0] store_imm,
    output wire [31:0] jump_imm,
    output wire [31:0] upper_imm
);

    // [funct7][rs2][rs1][funct3][rd][opcode]
    assign opcode = instruction[6:0];   // extract arithmetic instruction
    assign rd     = instruction[11:7];  // destination
    assign funct3 = instruction[14:12]; // identify exact operation
    assign rs1    = instruction[19:15]; // source register 1
    assign rs2    = instruction[24:20]; // source register 2
    assign funct7 = instruction[31:25]; // further defice operation

    // extends the immediate to 32 bits for alu operations depending on sign
    assign immediate = {{20{instruction[31]}}, instruction[31:20]};

    assign branch_imm = {{19{instruction[31]}},
        instruction[31],
        instruction[7],
        instruction[30:25],
        instruction[11:8],
        1'b0
    };
    
    assign store_imm = {
        {20{instruction[31]}},
        instruction[31:25],
        instruction[11:7]
    };
    
    assign jump_imm = {
        {11{instruction[31]}},
        instruction[31],
        instruction[19:12],
        instruction[20],
        instruction[30:21],
        1'b0
    };
    
    assign upper_imm = {instruction[31:12], 12'b0};

endmodule