`timescale 1ns / 1ps

module vga_controller (
    input wire clk,
    input wire reset,

    output wire hsync,
    output wire vsync,
    output wire video_active,
    output wire [9:0] pixel_x,
    output wire [9:0] pixel_y
);

    // 640x480 vga standard
    
    localparam H_VISIBLE = 640;
    localparam H_FRONT   = 16;
    localparam H_SYNC    = 96;
    localparam H_BACK    = 48;
    localparam H_TOTAL   = H_VISIBLE + H_FRONT + H_SYNC + H_BACK;
    
    // v-front – 10 blanks before v-sync, v-back – 33 blanks before new v-visible
    // v-sync is a 2 line synchronisarion pulse
    // originaly time needed to reposition electron beam
    localparam V_VISIBLE = 480;
    localparam V_FRONT   = 10;
    localparam V_SYNC    = 2;
    localparam V_BACK    = 33;
    localparam V_TOTAL   = V_VISIBLE + V_FRONT + V_SYNC + V_BACK;

    // 25 mhz pixel enable from 100 mhz clock
    reg [1:0] pixel_div = 0;
    // goes high when pixel_div == 2'b11
    wire pixel_tick = (pixel_div == 2'd3);

    // internal timer with overflow
    always @(posedge clk) begin
        if (reset)
            pixel_div <= 0;
        else
            pixel_div <= pixel_div + 1'b1;
    end

    // horizontal and vertical counters
    reg [9:0] h_count = 0;
    reg [9:0] v_count = 0;

    always @(posedge clk) begin
        if (reset) begin
            h_count <= 0;
            v_count <= 0;
        end
        else if (pixel_tick) begin
            if (h_count == H_TOTAL - 1) begin
                h_count <= 0;

                if (v_count == V_TOTAL - 1)
                    v_count <= 0;
                else
                    v_count <= v_count + 1'b1;
            end
            else
                h_count <= h_count + 1'b1;
        end
    end

    // active low synchronisation pulses
    assign hsync = ~((h_count >= H_VISIBLE + H_FRONT) &&
                     (h_count < H_VISIBLE + H_FRONT + H_SYNC));

    assign vsync = ~((v_count >= V_VISIBLE + V_FRONT) &&
                     (v_count < V_VISIBLE + V_FRONT + V_SYNC));

    // visible pixel area
    assign video_active = (h_count < H_VISIBLE) &&
                          (v_count < V_VISIBLE);

    // pixel coordinates
    assign pixel_x = h_count;
    assign pixel_y = v_count;

endmodule
