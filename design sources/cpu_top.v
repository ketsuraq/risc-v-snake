`timescale 1ns / 1ps

module cpu_top (
    input wire clk,
    input wire reset,
    input wire [3:0] btn,
    output wire [31:0] pc,
    output wire [31:0] instruction,

    output wire [6:0] opcode,
    output wire [4:0] rs1,
    output wire [4:0] rs2,
    output wire [4:0] rd,
    output wire [2:0] funct3,
    output wire [6:0] funct7,
    output wire [31:0] immediate,
    
    output wire [3:0] led,
    
    output wire tile_write_enable,
    output wire [10:0] tile_write_address,
    output wire [7:0] tile_write_data
        
);
    // constants
    // memory map
    localparam [31:0] RAM_BASE = 32'h00000000; // remember to change data_memory.v
    localparam [31:0] RAM_SIZE = 32'h00002000;
    localparam [31:0] LED_BASE = RAM_BASE + RAM_SIZE;
    localparam [31:0] BUTTON_BASE = LED_BASE + 32'd4;
    localparam [31:0] GRAPHICS_BASE = BUTTON_BASE + 32'd4;
    localparam [31:0] GRAPHICS_SIZE = 32'd1200;
    
    localparam [31:0] TIMER_BASE = 32'h00002500;
    localparam [31:0] RANDOM_BASE = TIMER_BASE + 32'd4;
    
    // cpu execution states for fsm
    localparam [2:0] FETCH     = 3'd0;
    localparam [2:0] DECODE    = 3'd1;
    localparam [2:0] EXECUTE   = 3'd2;
    localparam [2:0] MEMORY    = 3'd3;
    localparam [2:0] WRITEBACK = 3'd4;
    
    // current cpu state
    reg [2:0] state = FETCH;
    
    // intermediate cpu registers
    reg [31:0] ir = 0;
    reg [31:0] operand_a = 0;
    reg [31:0] operand_b = 0;
    reg [31:0] alu_out = 0;
    
    reg halted = 0;
    
    // fetch instruction
    always @(posedge clk) begin
        if (reset)
            ir <= 32'd0;
        else if (state == FETCH && !halted)
            ir <= instruction;
    end
    
    
    
    

    // values of operands
    wire [31:0] reg_data1;
    wire [31:0] reg_data2;

    // alu outputs
    wire [31:0] alu_result;
    wire alu_zero;

    // alu control
    wire [3:0] alu_control;
    wire alu_src;
    wire [31:0] alu_b;

    // register writing
    wire reg_write;
    wire reg_write_enable;
    wire [31:0] writeback_data;

    // branch instances
    wire branch;
    wire branch_taken;
    wire [31:0] branch_imm;
    wire [31:0] branch_target;

    assign branch_target = pc + branch_imm;

    assign branch_taken = branch && (
        ((funct3 == 3'b000) && (operand_a == operand_b)) ||
        ((funct3 == 3'b001) && (operand_a != operand_b)) ||
        ((funct3 == 3'b100) && ($signed(operand_a) < $signed(operand_b))) ||
        ((funct3 == 3'b101) && ($signed(operand_a) >= $signed(operand_b))) ||
        ((funct3 == 3'b110) && (operand_a < operand_b)) ||
        ((funct3 == 3'b111) && (operand_a >= operand_b))
    ); // beq // bne // blt // bge // bltu // bgeu

    // jump instances
    wire jal;
    wire jalr;
    wire [31:0] jump_imm;
    wire [31:0] jump_target;
    wire jump_taken;
    
    wire instruction_complete;

    assign jump_target =
        jal  ? (pc + jump_imm) :
        jalr ? (alu_out & 32'hFFFFFFFE) :
               branch_target;

    assign jump_taken =
        instruction_complete &&
        (branch_taken || jal || jalr);

    // u-type variables
    wire lui;
    wire auipc;
    wire [31:0] upper_imm;

    // memory variables
    wire mem_write;
    wire mem_read;
    wire mem_unsigned;
    wire mem_to_reg;
    wire [1:0] mem_size;
    wire [31:0] mem_read_data;

    // memory immediate
    wire [31:0] store_imm;
    wire [31:0] alu_imm;

    // correct imm for operation
    assign alu_imm = mem_write ? store_imm : immediate;

    // second alu operand
    assign alu_b = alu_src ? alu_imm : operand_b;

    // exception handling
    wire ecall;
    wire ebreak;
    

    always @(posedge clk) begin
        if (reset)
            halted <= 0;
        else if ((state == EXECUTE) && (ecall || ebreak))
            halted <= 1;
    end

    // bram
    wire mem_read_enable;
    wire mem_write_enable;
    
    
    
    // cpu state machine
    always @(posedge clk) begin
        if (reset)
            state <= FETCH;
        else if (halted)
            state <= FETCH;
        else begin
            case (state)
                FETCH:
                    state <= DECODE;
    
                DECODE:
                    state <= EXECUTE;
    
                EXECUTE: begin
                    if (mem_read || mem_write)
                        state <= MEMORY;
                    else if (reg_write)
                        state <= WRITEBACK;
                    else
                        state <= FETCH;
                end
    
                MEMORY: begin
                    if (mem_read)
                        state <= WRITEBACK;
                    else
                        state <= FETCH;
                end
    
                WRITEBACK:
                    state <= FETCH;
    
                default:
                    state <= FETCH;
            endcase
        end
    end
    
    // save intermediate values
    always @(posedge clk) begin
        if (reset) begin
            operand_a <= 32'd0;
            operand_b <= 32'd0;
            alu_out   <= 32'd0;
        end
        else begin
            if (state == DECODE) begin
                operand_a <= reg_data1;
                operand_b <= reg_data2;
            end
    
            if (state == EXECUTE)
                alu_out <= alu_result;
        end
    end
    
    

    assign instruction_complete =
        ((state == EXECUTE) && !mem_read && !mem_write && !reg_write) ||
        ((state == MEMORY) && mem_write) ||
        (state == WRITEBACK);
    
    
    
    // i/o
    wire ram_selected;
    wire led_selected;
    wire led_write_enable;
    wire button_selected;
    
    wire tile_selected;
    
    assign tile_selected = (alu_out >= GRAPHICS_BASE) && (alu_out < GRAPHICS_BASE + GRAPHICS_SIZE);
    
    // write one tile during the memory stage
    assign tile_write_enable =
        (state == MEMORY) &&
        mem_write &&
        tile_selected &&
        (mem_size == 2'b00) &&
        !reset && !halted;
    
    // convert cpu address to tile index
    assign tile_write_address =
        alu_out - GRAPHICS_BASE;
    
    // tile value comes from rs2
    assign tile_write_data = operand_b[7:0];
    
    

    assign ram_selected = (alu_out >= RAM_BASE) && (alu_out < RAM_BASE + RAM_SIZE);
    assign led_selected = (alu_out == LED_BASE);
    assign button_selected = (alu_out == BUTTON_BASE);
    
    // synchronising button inputs
    (* ASYNC_REG = "TRUE" *) reg [3:0] btn_meta = 0;
    (* ASYNC_REG = "TRUE" *) reg [3:0] btn_sync = 0;
    
    // two flip flops due to metastability inferred by buttons
    always @(posedge clk) begin
        btn_meta <= btn;
        btn_sync <= btn_meta;
    end
    
    // button read
    reg [31:0] button_read_data = 0;
    wire [31:0] load_read_data;
    
    always @(posedge clk) begin
        if (reset)
            button_read_data <= 0;
        else if ((state == MEMORY) && mem_read && button_selected && !halted)
            button_read_data <= {28'b0, btn_sync};
    end
    
    wire timer_selected;
    wire [31:0] timer_count;
    reg [31:0] timer_read_data = 0;
    
    // capture timer value on the first load cycle
    always @(posedge clk) begin
        if (reset)
            timer_read_data <= 0;
        else if ((state == MEMORY) && mem_read && timer_selected && !halted)
            timer_read_data <= timer_count;
    end
    
    assign timer_selected = (alu_out == TIMER_BASE);
    
    wire random_selected;
    wire [31:0] random_value;
    reg [31:0] random_read_data = 0;
    
    assign random_selected = (alu_out == RANDOM_BASE);
    
    
    always @(posedge clk) begin
        if (reset)
            random_read_data <= 32'd0;
        else if ((state == MEMORY) &&
                 mem_read && random_selected && !halted)
            random_read_data <= random_value;
    end
    
    // general assignments final stage
    assign load_read_data =
        button_selected ? button_read_data :
        timer_selected  ? timer_read_data  :
        random_selected ? random_read_data :
                          mem_read_data;

    // don't read during reset or halt
    assign mem_read_enable =
        (state == MEMORY) &&
        mem_read && ram_selected && !reset && !halted;

    // don't write during reset or halt
    assign mem_write_enable =
        (state == MEMORY) &&
        mem_write && ram_selected && !reset && !halted;
    
    assign led_write_enable =
        (state == MEMORY) &&
        mem_write && led_selected &&
        (mem_size == 2'b10) && !reset && !halted;

    // doesn't allow write on reset or halt
    assign reg_write_enable =
        (state == WRITEBACK) &&
        reg_write && !reset && !halted;

    // correct data to read into register (alu result or data loaded from memory or return address)
    assign writeback_data =
        lui           ? upper_imm :
        auipc         ? (pc + upper_imm) :
        (jal || jalr) ? (pc + 32'd4) :
        mem_to_reg    ? load_read_data :
                        alu_out;













    // ****** INSTANCES ****** 

    // instance of pc
    program_counter pc_unit (
        .clk(clk),
        .reset(reset),
        .enable(instruction_complete && !reset && !halted && !ecall && !ebreak),
        .jump_taken(jump_taken),
        .jump_target(jump_target),
        .pc(pc)
    );

    // instance of instruction memory
    instruction_memory imem_unit (
        .address(pc),
        .instruction(instruction)
    );

    // instance of decoder
    instruction_decoder decoder_unit (
        .instruction(ir),
        .opcode(opcode),
        .rs1(rs1),
        .rs2(rs2),
        .rd(rd),
        .funct3(funct3),
        .funct7(funct7),
        .immediate(immediate),
        .branch_imm(branch_imm),
        .store_imm(store_imm),
        .jump_imm(jump_imm),
        .upper_imm(upper_imm)
    );

    // instance of register file
    register_file registers_unit (
        .clk(clk),
        .write_enable(reg_write_enable),
        .rs1(rs1),
        .rs2(rs2),
        .rd(rd),
        .write_data(writeback_data),
        .read_data1(reg_data1),
        .read_data2(reg_data2)
    );

    // alu
    alu alu_unit (
        .a(operand_a),
        .b(alu_b),
        .alu_op(alu_control),     
        .result(alu_result),
        .zero(alu_zero)
    );
    
    // control unit
    control_unit control_unit_inst (
        .instruction(ir),
        .opcode(opcode),
        .funct3(funct3),
        .funct7(funct7),
        .alu_control(alu_control),
        .alu_src(alu_src),
        .reg_write(reg_write),
        .mem_write(mem_write),
        .mem_read(mem_read),
        .mem_unsigned(mem_unsigned),
        .mem_to_reg(mem_to_reg),
        .mem_size(mem_size),
        .branch(branch),
        .jal(jal),
        .jalr(jalr),
        .lui(lui),
        .auipc(auipc),
        .ecall(ecall),
        .ebreak(ebreak)
    );
    
    // data memory inst
    data_memory dmem_unit (
        .clk(clk),
        .mem_write(mem_write_enable),
        .mem_read(mem_read_enable),
        .mem_unsigned(mem_unsigned),
        .mem_size(mem_size),
        .address(alu_out),
        .write_data(operand_b),
        .read_data(mem_read_data)
    );
    
    // memory mapped leds
    led_controller led_unit (
        .clk(clk),
        .reset(reset),
        .write_enable(led_write_enable),
        .write_data(operand_b),
        .led(led)
    );
    
    // free running timer
    timer_controller timer_unit (
        .clk(clk),
        .reset(reset),
        .timer_count(timer_count)
    );
    
    random_controller random_unit (
        .clk(clk),
        .reset(reset),
        .random_value(random_value)
    );
    
    
endmodule