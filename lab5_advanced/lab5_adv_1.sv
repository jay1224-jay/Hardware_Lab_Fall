/*
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
    logic [9:0] x_position, y_position;
    logic display_valid;
    logic vga_valid;

    clock_divider #(.n(2)) clk_div(clk, clk_25M);
    clock_divider #(.n(22)) clk_di22(clk, clk_22);

    assign {vgaRed, vgaGreen, vgaBlue} = display_valid ? pixel : 0;

    vga_controller my_vga(
        .pclk(clk_25M),
        .reset(rst),
        .hsync(hsync),
        .vsync(vsync),
        .valid(vga_valid),
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

    logic [9:0] local_x, local_y;

    assign local_x = (h_cnt - x_position + 640) % 640;
    assign local_y = (v_cnt - y_position + 480) % 480;

    always_comb begin
        display_valid = 0;
        pixel_addr = 0;
        if (local_x < 320 && local_y < 240) begin
            display_valid = vga_valid;
            if (vmir) begin
                pixel_addr = local_x + (239 - local_y) * 320;
            end else begin
                pixel_addr = local_x + local_y * 320;
            end
        end
    end

    always_ff @( posedge clk_22, posedge rst ) begin
        if (rst) begin 
            x_position <= 160;
            y_position <= 120;
        end
        else begin
            if (dir_up) begin
                if (y_position >= 0)
                    y_position <= y_position - ((speed) ? 3 : 1);
                else
                    y_position <= 480 - 1; 
            end
            if (dir_left) begin
                if (x_position >= 0)
                    x_position <= x_position - ((speed) ? 3 : 1);
                else
                    x_position <= 640 - 1;
            end
            if (rotate_cw) begin
                ;
            end
            if (rotate_ccw) begin
                ;
            end
        end
    end
    // === memory address generation ===

endmodule
*/
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
    logic clk_20; // Faster clock for speed = 1
    logic [11:0] pixel;
    logic [16:0] pixel_addr;
    logic [9:0] h_cnt, v_cnt;
    logic [9:0] x_position, y_position;
    logic display_valid;
    logic vga_valid;

    // Clock dividers
    clock_divider #(.n(2)) clk_div(clk, clk_25M);
    clock_divider #(.n(22)) clk_di22(clk, clk_22);
    clock_divider #(.n(20)) clk_di20(clk, clk_20);

    assign {vgaRed, vgaGreen, vgaBlue} = display_valid ? pixel : 0;

    vga_controller my_vga(
        .pclk(clk_25M),
        .reset(rst),
        .hsync(hsync),
        .vsync(vsync),
        .valid(vga_valid),
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

    // === Button Edge Detection (One-Pulse) on 100MHz clk ===
    logic rot_cw_d, rot_ccw_d;
    logic rot_cw_trig, rot_ccw_trig;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            rot_cw_d  <= 0;
            rot_ccw_d <= 0;
        end else begin
            rot_cw_d  <= rotate_cw;
            rot_ccw_d <= rotate_ccw;
        end
    end

    assign rot_cw_trig  = rotate_cw && !rot_cw_d;
    assign rot_ccw_trig = rotate_ccw && !rot_ccw_d;

    // Rotation state: 0 = 0°, 1 = 90° CW, 2 = 180°, 3 = 270° CW
    logic [1:0] rot_state;

    // Display dimensions based on rotation state
    logic [9:0] disp_w, disp_h;
    assign disp_w = (rot_state[0]) ? 10'd240 : 10'd320;
    assign disp_h = (rot_state[0]) ? 10'd320 : 10'd240;

    // Movement clock selection
    logic movement_clk;
    assign movement_clk = speed ? clk_20 : clk_22;

    // Generate movement enable strobe from movement_clk
    logic mov_d;
    logic move_en;
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            mov_d <= 0;
        end else begin
            mov_d <= movement_clk;
        end
    end
    assign move_en = movement_clk && !mov_d;

    // === Unified Position & Rotation Update Logic (Clocked at 100MHz) ===
    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            x_position <= 160;
            y_position <= 120;
            rot_state  <= 2'd0;
        end else begin
            // 1. Rotation Handling (Immediate response on button press)
            if (rot_cw_trig) begin
                rot_state <= rot_state + 2'd1;
                // Center-invariant position offset adjustment on dimension swap
                if (rot_state == 2'd0 || rot_state == 2'd2) begin
                    x_position <= x_position + 40;
                    y_position <= y_position - 40;
                end else begin
                    x_position <= x_position - 40;
                    y_position <= y_position + 40;
                end
            end else if (rot_ccw_trig) begin
                rot_state <= rot_state - 2'd1;
                if (rot_state == 2'd0 || rot_state == 2'd2) begin
                    x_position <= x_position + 40;
                    y_position <= y_position - 40;
                end else begin
                    x_position <= x_position - 40;
                    y_position <= y_position + 40;
                end
            end

            // 2. Translation Handling (Synchronized with movement clock tick)
            if (move_en) begin
                if (dir_up) begin
                    if (y_position >= 1)
                        y_position <= y_position - 1;
                    else
                        y_position <= 480 - 1;
                end
                if (dir_left) begin
                    if (x_position >= 1)
                        x_position <= x_position - 1;
                    else
                        x_position <= 640 - 1;
                end
            end
        end
    end

    // === Memory Address Generation ===
    logic [9:0] local_x, local_y;
    assign local_x = (h_cnt - x_position + 640) % 640;
    assign local_y = (v_cnt - y_position + 480) % 480;

    logic [9:0] img_x, img_y;

    always_comb begin
        display_valid = 0;
        pixel_addr = 0;
        img_x = 0;
        img_y = 0;

        if (local_x < disp_w && local_y < disp_h) begin
            display_valid = vga_valid;

            // 1. Rotation mapping
            case (rot_state)
                2'd0: begin // 0 degrees
                    img_x = local_x;
                    img_y = local_y;
                end
                2'd1: begin // 90 degrees CW
                    img_x = local_y;
                    img_y = 240 - 1 - local_x;
                end
                2'd2: begin // 180 degrees
                    img_x = 320 - 1 - local_x;
                    img_y = 240 - 1 - local_y;
                end
                2'd3: begin // 270 degrees CW (90 CCW)
                    img_x = 320 - 1 - local_y;
                    img_y = local_x;
                end
            endcase

            // 2. Vertical mirroring (applied after rotation as specified)[cite: 2]
            if (vmir) begin
                img_y = 240 - 1 - img_y;
            end

            pixel_addr = img_x + img_y * 320;
        end
    end

endmodule
