`timescale 1ns / 1ps

module fpga_top(
        input wire clk,
        input wire rst_n,
        input wire [3:0] btn,
        output wire [3:0] led,
        
        output wire [3:0] vga_r,
        output wire [3:0] vga_g,
        output wire [3:0] vga_b,
        output wire vga_hsync,
        output wire vga_vsync
    );
    
    wire reset = !rst_n;
    
    // vga signals
    wire video_active;
    wire [9:0] pixel_x;
    wire [9:0] pixel_y;
    
    wire tile_write_enable;
    wire [10:0] tile_write_address;
    wire [7:0] tile_write_data;
    
    // tile memory read signals
    wire [10:0] tile_read_address;
    wire [7:0] tile_read_data;
    
    wire [5:0] tile_x = pixel_x[9:4];
    wire [4:0] tile_y = pixel_y[8:4];
    
    wire [10:0] tile_y_extended = {6'b0, tile_y};
    
    // align display signals with tile memory read
    reg video_active_delayed = 0;
    reg hsync_delayed = 1;
    reg vsync_delayed = 1;
    
    wire hsync_raw;
    wire vsync_raw;
    
    always @(posedge clk) begin
        if (reset) begin
            video_active_delayed <= 0;
            hsync_delayed <= 1;
            vsync_delayed <= 1;
        end
        else begin
            video_active_delayed <= video_active;
            hsync_delayed <= hsync_raw;
            vsync_delayed <= vsync_raw;
        end
    end
    
    assign vga_hsync = hsync_delayed;
    assign vga_vsync = vsync_delayed;
    
    assign tile_read_address =
        video_active ?
        (tile_y_extended << 5) +
        (tile_y_extended << 3) +
        {5'b0, tile_x} :
        11'd0;

    // cpu inst
    cpu_top cpu_unit (
        .clk(clk),
        .reset(reset),
        .btn(btn),
        .pc(),
        .instruction(),
        .opcode(),
        .rs1(),
        .rs2(),
        .rd(),
        .funct3(),
        .funct7(),
        .immediate(),
        .led(led),
        .tile_write_enable(tile_write_enable),
        .tile_write_address(tile_write_address),
        .tile_write_data(tile_write_data)
    );
    
    vga_controller vga_unit (
        .clk(clk),
        .reset(reset),
        .hsync(hsync_raw),
        .vsync(vsync_raw),
        .video_active(video_active),
        .pixel_x(pixel_x),
        .pixel_y(pixel_y)
    );
    
    vga_renderer renderer_unit (
        .clk(clk),
        .reset(reset),
        .video_active(video_active_delayed),
        .tile_read_data(tile_read_data),
        .red(vga_r),
        .green(vga_g),
        .blue(vga_b)
    );
    
    tile_memory tmem_unit (
        .clk(clk),
        .reset(reset),
        .write_enable(tile_write_enable),
        .write_address(tile_write_address),
        .write_data(tile_write_data),
        .read_address(tile_read_address),
        .read_data(tile_read_data)
    );
    
        
endmodule
