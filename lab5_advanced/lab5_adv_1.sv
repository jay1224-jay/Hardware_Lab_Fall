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
    logic [11:0] pixel;
    logic [16:0] pixel_addr;
    logic [9:0] h_cnt, v_cnt;
    logic [9:0] x_center, y_center;   
    logic display_valid;               
    logic vga_valid;
    logic in_window;

    logic [1:0] rot;                    // 0: 0deg, 1: 90deg cw, 2: 180deg, 3: 270deg cw
    logic cw_pulse, ccw_pulse;
    logic [19:0] move_cnt;
    logic move_tick;

    clock_divider #(.n(2)) clk_div(clk, clk_25M);

    assign {vgaRed, vgaGreen, vgaBlue} = display_valid ? pixel : 12'h0;

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

    deb_and_one gg_cw(clk_25M, rotate_cw, cw_pulse);
    deb_and_one gg_ccw(clk_25M, rotate_ccw, ccw_pulse);

    // === movement tick ===
    // slow : 100MHz / 2^22 -> 2^20 cycles of clk_25M
    // fast : 100MHz / 2^20 -> 2^18 cycles of clk_25M (4x faster)
    always_ff @( posedge clk_25M, posedge rst ) begin
        if (rst) move_cnt <= 0;
        else     move_cnt <= move_cnt + 1;
    end

    assign move_tick = speed ? &(move_cnt[17:0]) : &(move_cnt);

    // === position / rotation state ===
    always_ff @( posedge clk_25M, posedge rst ) begin
        if (rst) begin
            x_center <= 320;
            y_center <= 240;
            rot      <= 0;
        end
        else begin
            if (move_tick) begin
                if (dir_up) begin
                    if (y_center == 0) y_center <= 480 - 1;
                    else               y_center <= y_center - 1;
                end
                if (dir_left) begin
                    if (x_center == 0) x_center <= 640 - 1;
                    else               x_center <= x_center - 1;
                end
            end
            if (cw_pulse)       rot <= rot + 1;
            else if (ccw_pulse) rot <= rot - 1;
        end
    end

    // === memory address generation ===

    // The image is 320x240 (native size = 1/4 of the 640x480 screen, no scaling).
    // The displayed window is win_w x win_h around (x_center, y_center):
    //   rot 0/2 : 320 x 240
    //   rot 1/3 : 240 x 320
    // For each screen pixel: screen -> window coordinate (with wrap-around)
    //   -> vertical mirror (applied AFTER rotation) -> inverse rotation -> source pixel.

    logic [9:0] win_w, win_h, half_w, half_h;
    logic signed [11:0] raw_x, raw_y;
    logic [9:0] local_x, local_y;       // window coordinate
    logic [9:0] mir_y;          
    logic [9:0] src_x, src_y;           // image coordinate

    assign win_w  = rot[0] ? 240 : 320;
    assign win_h  = rot[0] ? 320 : 240;
    assign half_w = win_w >> 1;
    assign half_h = win_h >> 1;

    always_comb begin
        raw_x = h_cnt - x_center + half_w;
        raw_y = v_cnt - y_center + half_h;

        if (raw_x < 0)        raw_x = raw_x + 640;
        else if (raw_x >= 640) raw_x = raw_x - 640;
        if (raw_y < 0)        raw_y = raw_y + 480;
        else if (raw_y >= 480) raw_y = raw_y - 480;

        local_x = raw_x[9:0];
        local_y = raw_y[9:0];
    end

    assign in_window = (local_x < win_w) && (local_y < win_h);

    always_comb begin
        // vertical mirror of the (already rotated) displayed image
        mir_y = vmir ? (win_h - 1 - local_y) : local_y;

        case (rot)
            2'd0: begin
                src_x = local_x;
                src_y = mir_y;
            end
            2'd1: begin                 // 90 cw
                src_x = mir_y;
                src_y = 239 - local_x;
            end
            2'd2: begin                 // 180
                src_x = 319 - local_x;
                src_y = 239 - mir_y;
            end
            default: begin              // 270 cw
                src_x = 319 - mir_y;
                src_y = local_x;
            end
        endcase

        pixel_addr = (in_window) ? (src_y * 17'd320 + src_x) : 17'd0;
    end

    // BRAM has 1-cycle read latency: delay the valid flag to match pixel data
    always_ff @( posedge clk_25M, posedge rst ) begin
        if (rst) display_valid <= 0;
        else     display_valid <= vga_valid && in_window;
    end
    // === memory address generation ===

endmodule

module deb_and_one (
    input clk,
    input pb,
    output out
);

    logic [5:0] shift_reg;
    logic delay;

    always_ff @( posedge clk ) begin
        shift_reg <= {shift_reg[4:0], pb};
        delay <= &(shift_reg);
    end

    assign out = &(shift_reg) && ~delay;
    
endmodule
