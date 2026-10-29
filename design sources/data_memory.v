`timescale 1ns / 1ps

// harvard style memory implementation (data memory block and instruciton memory block)
// 1024 words, 32 bits wide (4 kib)
// synchonous bram, loading is 2 clock cycles

module data_memory (
    input wire clk,
    input wire mem_write,
    input wire mem_read,
    input wire mem_unsigned,
    input wire [1:0] mem_size,
    input wire [31:0] address,
    input wire [31:0] write_data,
    output reg [31:0] read_data
);

    // 1024 bytes
    (* ram_style = "block" *)
    reg [31:0] memory [0:2047];
    
    wire [10:0] word_address = address[12:2];
    wire [1:0] byte_offset = address[1:0];

    // select bytes to write
    wire [3:0] byte_enable =
        mem_size == 2'b00 ? (4'b0001 << byte_offset) :
        mem_size == 2'b01 ? (4'b0011 << byte_offset) :
        mem_size == 2'b10 ? 4'b1111 : 4'b0000;

    // move write data into selected byte positions
    wire [31:0] shifted_write = write_data << {byte_offset, 3'b000};

    // word returned by synchronous bram
    reg [31:0] read_word;

    // clocked RAM access
    always @(posedge clk) begin
        if (mem_write) begin
            if (byte_enable[0])
                memory[word_address][7:0] <= shifted_write[7:0];

            if (byte_enable[1])
                memory[word_address][15:8] <= shifted_write[15:8];

            if (byte_enable[2])
                memory[word_address][23:16] <= shifted_write[23:16];

            if (byte_enable[3])
                memory[word_address][31:24] <= shifted_write[31:24];
        end
        else if (mem_read) begin
            read_word <= memory[word_address];
        end
    end

    // select requested byte or halfword
    wire [31:0] selected_data =
        read_word >> {byte_offset, 3'b000};

    // sign or zero extension
    always @(*) begin
        read_data = 32'b0;

        case (mem_size)
            2'b00: begin
                if (mem_unsigned) // lbu
                    read_data = {24'b0, selected_data[7:0]};
                else // lb
                    read_data = {{24{selected_data[7]}},
                                  selected_data[7:0]};
            end

            2'b01: begin
                if (mem_unsigned) // lhu
                    read_data = {16'b0, selected_data[15:0]};
                else // lh
                    read_data = {{16{selected_data[15]}},
                                  selected_data[15:0]};
            end

            2'b10: begin // lw
                read_data = read_word;
            end

            default: read_data = 32'b0;
        endcase
    end
endmodule
