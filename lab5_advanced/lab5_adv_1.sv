`timescale 1ns / 1ps

module lab5_1 (
    input logic clk,
    input logic rst,
    input logic dir_left,
    input logic dir_up,
    input logic vmir,
    input logic speed,
    input logic rotate_cw,
    input logic rotate_ccw,
    output logic [3:0] vgaRed,
    output logic [3:0] vgaGreen,
    output logic [3:0] vgaBlue,
    output logic hsync,
    output logic vsync
);

    logic clk_25M;
    logic clk_22;
    logic [11:0] pixel;
    logic [16:0] pixel_addr;
    logic [9:0] h_cnt, v_cnt;
    logic [7:0] x_position, y_position;
    logic display_valid;

    clock_divider #(.n(2)) clk_div(clk, clk_25M);
    clock_divider #(.n(22)) clk_di22(clk, clk_22);

    assign {vgaRed, vgaGreen, vgaBlue} = 
                (display_valid && (x_position <= h_cnt && h_cnt < (x_position + 320)) && (y_position <= v_cnt && v_cnt < (y_position + 240))) ?
                pixel : 0;

    vga_controller my_vga(
        .pclk(clk_25M),
        .reset(rst),
        .hsync(hsync),
        .vsync(vsync),
        .valid(display_valid),
        .h_cnt(h_cnt),
        .v_cnt(v_cnt)
    );

    blk_mem_gen_0 mem_inst(
        .clka(clk_25M),
        .wea(0),
        .addra(pixel_addr),
        .dina(0),
        .douta(pixel)
    );

    // === memory address generation ===
    
    // scale up 4x
    // (0, 0), (0, 1)
    // (1, 0), (1, 1)
    // display same pixel from (0, 0) in image

    // (x, y) + position * 320 -> this postiion display the bit under it -> image move upward

    assign pixel_addr = ((h_cnt - x_position) + 320 * (v_cnt - y_position)) % 76800;

    always_ff @( posedge clk_22, posedge rst ) begin
        if (rst) begin // TODO: Center on screen when reset
            x_position <= 160;
            y_position <= 120;
        end
        else begin
            if (dir_up) begin
                if (y_position > 0)
                    y_position <= y_position - 1;
                else
                    y_position <= 240 - 1; 
            end
            if (dir_left) begin
                if (x_position > 0)
                    x_position <= x_position - 1;
                else
                    x_position <= 320 - 1;
            end
        end
    end
    // === memory address generation ===

endmodule
