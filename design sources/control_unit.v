`timescale 1ns / 1ps

module control_unit (
    input wire [31:0] instruction,
    input wire [6:0] opcode,
    input wire [2:0] funct3,
    input wire [6:0] funct7,

    output reg [3:0] alu_control,
    output reg alu_src,
    output reg reg_write,
    
    output reg mem_write,
    output reg mem_read,
    output reg mem_unsigned,
    output reg mem_to_reg,
    output reg [1:0] mem_size,
    
    output reg branch,
    
    output reg jal,
    output reg jalr,
    
    output reg lui,
    output reg auipc,
    
    output reg ecall,
    output reg ebreak
);

    always @(*) begin
        // default state
        alu_control = 4'b0000;
        alu_src = 0;
        reg_write = 0;
        mem_write = 0;
        mem_read = 0;
        mem_unsigned = 0;
        mem_to_reg = 0;
        mem_size = 2'b00;
        branch = 0;
        
        jal = 0;
        jalr = 0;
        
        lui = 0;
        auipc = 0;
        
        ecall = 0;
        ebreak = 0;

        case (opcode)
        
            7'b0010011: begin // i-based instructions
                case (funct3)
                    3'b000: begin alu_control = 4'b0000; alu_src = 1; reg_write = 1; end // addi
                    3'b100: begin alu_control = 4'b0100; alu_src = 1; reg_write = 1; end // xori
                    3'b110: begin alu_control = 4'b0011; alu_src = 1; reg_write = 1; end // ori
                    3'b111: begin alu_control = 4'b0010; alu_src = 1; reg_write = 1; end // andi
                    3'b010: begin alu_control = 4'b1000; alu_src = 1; reg_write = 1; end // slti
                    3'b011: begin alu_control = 4'b1001; alu_src = 1; reg_write = 1; end // sltui
            
                    3'b001: begin // slli
                        if (funct7 == 7'b0000000) begin
                            alu_control = 4'b0101; alu_src = 1; reg_write = 1;
                        end
                    end
            
                    3'b101: begin
                        if (funct7 == 7'b0000000) begin // srli
                            alu_control = 4'b0110; alu_src = 1; reg_write = 1;
                        end
                        else if (funct7 == 7'b0100000) begin // srai
                            alu_control = 4'b0111; alu_src = 1; reg_write = 1;
                        end
                    end
                endcase
            end

            7'b0110011: begin // r-type instructions
                if (funct7 == 7'b0000000) begin
                    case (funct3)
                        3'b000: begin alu_control = 4'b0000; reg_write = 1; end // add
                        3'b100: begin alu_control = 4'b0100; reg_write = 1; end // xor
                        3'b110: begin alu_control = 4'b0011; reg_write = 1; end // or
                        3'b111: begin alu_control = 4'b0010; reg_write = 1; end // and
                        3'b001: begin alu_control = 4'b0101; reg_write = 1; end // sll
                        3'b101: begin alu_control = 4'b0110; reg_write = 1; end // srl
                        3'b010: begin alu_control = 4'b1000; reg_write = 1; end // slt
                        3'b011: begin alu_control = 4'b1001; reg_write = 1; end // sltu
                    endcase
                end
                else if (funct7 == 7'b0100000) begin
                    case (funct3)
                        3'b000: begin alu_control = 4'b0001; reg_write = 1; end // sub
                        3'b101: begin alu_control = 4'b0111; reg_write = 1; end // sra
                    endcase
                end
            end
            
            7'b1100011: begin // b-type instructions (pc loops)
                case (funct3)
                    3'b000: begin alu_control = 4'b0001; branch = 1; end // beq
                    3'b001: begin alu_control = 4'b0001; branch = 1; end // bne
                    3'b100: begin alu_control = 4'b1000; branch = 1; end // blt
                    3'b101: begin alu_control = 4'b1000; branch = 1; end // bge
                    3'b110: begin alu_control = 4'b1001; branch = 1; end // bltu
                    3'b111: begin alu_control = 4'b1001; branch = 1; end // bgeu
                endcase
            end
            
            7'b0100011: begin // s-type instructions (store)
                case (funct3)
                    3'b000: begin alu_control = 4'b0000; alu_src = 1; mem_write = 1; mem_size = 2'b00; end // sb
                    3'b001: begin alu_control = 4'b0000; alu_src = 1; mem_write = 1; mem_size = 2'b01; end // sh
                    3'b010: begin alu_control = 4'b0000; alu_src = 1; mem_write = 1; mem_size = 2'b10; end // sw
                endcase
            end
            
            7'b0000011: begin // l-type instructions (load)
                case (funct3)
                    3'b000: begin alu_control = 4'b0000; alu_src = 1; mem_read = 1; mem_size = 2'b00; reg_write = 1; mem_to_reg = 1; end // lb
                    3'b001: begin alu_control = 4'b0000; alu_src = 1; mem_read = 1; mem_size = 2'b01; reg_write = 1; mem_to_reg = 1; end // lh
                    3'b010: begin alu_control = 4'b0000; alu_src = 1; mem_read = 1; mem_size = 2'b10; reg_write = 1; mem_to_reg = 1; end // lw
                    3'b100: begin alu_control = 4'b0000; alu_src = 1; mem_read = 1; mem_size = 2'b00; reg_write = 1; mem_to_reg = 1; mem_unsigned = 1; end // lbu
                    3'b101: begin alu_control = 4'b0000; alu_src = 1; mem_read = 1; mem_size = 2'b01; reg_write = 1; mem_to_reg = 1; mem_unsigned = 1; end // lhu
                endcase
            end
            
            7'b1101111: begin // jal (jump and link), saves return address
                jal = 1; reg_write = 1;
            end
            
            7'b1100111: begin // jal (jump and link register) + imm
                if (funct3 == 3'b000) begin
                    alu_control = 4'b0000; alu_src = 1; jalr = 1; reg_write = 1;
                end
            end
            
            7'b0110111: begin // lui (operations with large numbers)
                lui = 1; reg_write = 1;
            end
            
            7'b0010111: begin // auipc (operations with pc and large numbers)
                auipc = 1; reg_write = 1;
            end
            
            7'b1110011: begin
                case (instruction)
                    32'h00000073: ecall = 1;  // ecall
                    32'h00100073: ebreak = 1; // ebreak
                endcase
            end
            
            7'b0001111: begin // fence
            
            end
        endcase
    end

endmodule