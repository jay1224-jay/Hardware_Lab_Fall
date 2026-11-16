typedef enum logic [4:0] { 
    key_1   = 5'd1,
    key_2   = 5'd2,
    key_3   = 5'd3,
    key_4   = 5'd4,
    key_5   = 5'd5,
    key_6   = 5'd6,
    key_7   = 5'd7,
    key_8   = 5'd8,

    key_t   = 5'd9,
    key_y   = 5'd10,
    key_u   = 5'd11,
    key_i   = 5'd12,
    key_g   = 5'd13,
    key_h   = 5'd14,
    key_j   = 5'd15,
    key_k   = 5'd16,
    key_b   = 5'd17,
    key_n   = 5'd18,
    key_m   = 5'd19,
    key_comma = 5'd20,

    key_enter = 5'd21,
    key_none = 5'd31
} key_pressed_t;

module lab5_2 (
    input logic clk,
    input logic rst,
    input logic start,
    input logic [2:0] sw,

    inout logic PS2_CLK,
    inout logic PS2_DATA,

    output logic [3:0] vgaRed,
    output logic [3:0] vgaGreen,
    output logic [3:0] vgaBlue,
    output logic hsync,
    output logic vsync,
    output logic [15:0] led
);

    // ============================================================
    // 1. PARAMETERS
    // ============================================================

    localparam INIT   = 2'b00;
    localparam SHOW   = 2'b01;
    localparam GAME   = 2'b10;
    localparam FINISH = 2'b11;

    // VGA dimensions
    localparam H_DISPLAY = 640;
    localparam V_DISPLAY = 480;

    localparam CELL_W = 160;
    localparam CELL_H = 120;

    // ============================================================
    // 2. STATE REGISTERS
    // ============================================================

    logic clk_25M;

    clock_divider #(.n(2)) my_clk_div(clk, clk_25M);

    logic [1:0] state, next_state;

    logic start_deb;
    logic start_pulse;

    debounce my_deb(.clk(clk), .pb(start), .pb_debounced(start_deb));
    one_pulse my_one(clk, start_deb, start_pulse);

    // ============================================================
    // 3. GAME DATA
    // ============================================================

    logic [2:0] image_id [0:15];
    logic [15:0] positive;
    logic [2:0] selected_game;

    // ============================================================
    // 4. KEYBOARD INTERFACE
    // ============================================================

    logic [511:0] key_down;
    logic [8:0]   last_change;
    logic         key_valid;
    key_pressed_t key_pressed;

    logic key_event;
    assign key_event = key_valid && (key_pressed != 5'd0) && (key_down[last_change] == 1'b1);

    always_comb begin
        case (last_change[7:0])
            // Number row (1 - 8)
            8'h16   : key_pressed = key_1;
            8'h1E   : key_pressed = key_2;
            8'h26   : key_pressed = key_3;
            8'h25   : key_pressed = key_4;
            8'h2E   : key_pressed = key_5;
            8'h36   : key_pressed = key_6;
            8'h3D   : key_pressed = key_7;
            8'h3E   : key_pressed = key_8;

            // Top letter row (T, Y, U, I)
            8'h2C   : key_pressed = key_t;
            8'h35   : key_pressed = key_y;
            8'h3C   : key_pressed = key_u;
            8'h43   : key_pressed = key_i;

            // Home row (G, H, J, K)
            8'h34   : key_pressed = key_g;
            8'h33   : key_pressed = key_h;
            8'h3B   : key_pressed = key_j;
            8'h42   : key_pressed = key_k;

            // Bottom row (B, N, M, comma)
            8'h32   : key_pressed = key_b;
            8'h31   : key_pressed = key_n;
            8'h3A   : key_pressed = key_m;
            8'h41   : key_pressed = key_comma;

            // Enter key
            8'h5A   : key_pressed = key_enter;
            
            default : key_pressed = key_none;
        endcase
    end

    KeyboardDecoder gg (
        .key_down(key_down),
        .last_change(last_change),
        .key_valid(key_valid),
        .PS2_DATA(PS2_DATA),
        .PS2_CLK(PS2_CLK),
        .rst(rst),
        .clk(clk)
    );

    logic [9:0] h_cnt;
    logic [9:0] v_cnt;
    logic video_valid;

    vga_controller my_vga(
        .pclk(clk_25M),
        .reset(rst),
        .hsync(hsync),
        .vsync(vsync),
        .valid(video_valid),
        .h_cnt(h_cnt),
        .v_cnt(v_cnt)
    );

    // ============================================================
    // 5. GAME COMMAND PARSER & LOGIC FSM
    // ============================================================

    typedef enum logic [1:0] {
        PARSE_IDLE       = 2'd0,
        PARSE_WAIT_OP_ENT= 2'd1,
        PARSE_WAIT_TARGET= 2'd2,
        PARSE_WAIT_TAR_ENT= 2'd3
    } parse_state_t;

    parse_state_t parse_state;
    logic [1:0] op_type; // 1 for Op 1, 2 for Op 2
    key_pressed_t saved_target;

    function [3:0] get_grid_idx(input key_pressed_t k);
        case (k)
            key_5: return 4'd0;
            key_6: return 4'd1;
            key_7: return 4'd2;
            key_8: return 4'd3;
            key_t: return 4'd4;
            key_y: return 4'd5;
            key_u: return 4'd6;
            key_i: return 4'd7;
            key_g: return 4'd8;
            key_h: return 4'd9;
            key_j: return 4'd10;
            key_k: return 4'd11;
            key_b: return 4'd12;
            key_n: return 4'd13;
            key_m: return 4'd14;
            key_comma: return 4'd15;
            default: return 4'd0;
        endcase
    endfunction

    function [2:0] get_img_id(input key_pressed_t k);
        case (k)
            key_1: return 3'd1;
            key_2: return 3'd2;
            key_3: return 3'd3;
            key_4: return 3'd4;
            default: return 3'd1;
        endcase
    endfunction

    // ============================================================
    // 6. IMAGE MEMORY / ROM & RENDERING SIGNALS
    // ============================================================

    logic [16:0] image_addr;
    logic [11:0] image_pixel;

    // Coordinate mapping for current pixel
    logic [1:0] grid_col, grid_row;
    logic [3:0] cell_idx;
    logic [7:0] local_x;
    logic [6:0] local_y;

    assign grid_col  = h_cnt / CELL_W;
    assign grid_row  = v_cnt / CELL_H;
    assign cell_idx  = {grid_row, grid_col};
    assign local_x   = h_cnt - (grid_col * CELL_W);
    assign local_y   = v_cnt - (grid_row * CELL_H);

    logic [2:0] active_img_id;
    logic active_positive;

    always_comb begin
        if (state == SHOW) begin
            if (grid_row == 2'd0) begin
                active_img_id   = grid_col + 3'd1;
                active_positive = 1'b0; // Negative film
            end else if (grid_row == 2'd1) begin
                active_img_id   = grid_col + 3'd1;
                active_positive = 1'b1; // Positive film
            end else begin
                active_img_id   = 3'd1;
                active_positive = 1'b1;
            end
        end else if (state == GAME || state == FINISH) begin
            active_img_id   = image_id[cell_idx];
            active_positive = positive[cell_idx];
        end else begin
            active_img_id   = 3'd1;
            active_positive = 1'b1;
        end
    end

    // ROM address calculation: 19200 pixels per image (160 x 120)
    assign image_addr = ((active_img_id >= 3'd1 ? active_img_id - 3'd1 : 3'd0) * 17'd19200) + (local_y * 17'd160 + local_x);

    blk_mem_gen_0 mem_inst(
        .clka(clk_25M),
        .wea(1'b0),
        .addra(image_addr),
        .dina(12'h000),
        .douta(image_pixel)
    );

    // ============================================================
    // 7. FSM & GAME UPDATE LOGIC
    // ============================================================

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= INIT;
            parse_state <= PARSE_IDLE;
            op_type <= 2'd0;
            selected_game <= 3'd0;
            for (int i = 0; i < 16; i = i + 1) begin
                image_id[i] <= 3'd1;
                positive[i] <= 1'b1;
            end
        end else begin
            state <= next_state;

            // Capture selected game switch configuration in SHOW state before entering GAME
            if (state == SHOW) begin
                if (sw[0]) selected_game <= 3'd1;
                else if (sw[1]) selected_game <= 3'd2;
                else if (sw[2]) selected_game <= 3'd3;
                else selected_game <= 3'd1;
            end

            // Initialize puzzle grid upon entering GAME state
            if (state != GAME && next_state == GAME) begin
                case (selected_game)
                    3'd1: begin
                        // Game 1 initial state[cite: 9]
                        image_id[0] = 1; positive[0] = 1;  image_id[1] = 1; positive[1] = 1;  image_id[2] = 1; positive[2] = 1;  image_id[3] = 1; positive[3] = 1;
                        image_id[4] = 2; positive[4] = 1;  image_id[5] = 2; positive[5] = 1;  image_id[6] = 2; positive[6] = 1;  image_id[7] = 2; positive[7] = 0;
                        image_id[8] = 3; positive[8] = 0;  image_id[9] = 3; positive[9] = 0;  image_id[10] = 3; positive[10] = 0; image_id[11] = 3; positive[11] = 0;
                        image_id[12] = 4; positive[12] = 1; image_id[13] = 4; positive[13] = 1; image_id[14] = 4; positive[14] = 1; image_id[15] = 4; positive[15] = 0;
                    end
                    3'd2: begin
                        // Game 2 initial state[cite: 9]
                        image_id[0] = 1; positive[0] = 1;  image_id[1] = 2; positive[1] = 1;  image_id[2] = 3; positive[2] = 1;  image_id[3] = 4; positive[3] = 1;
                        image_id[4] = 2; positive[4] = 1;  image_id[5] = 3; positive[5] = 1;  image_id[6] = 4; positive[6] = 0;  image_id[7] = 1; positive[7] = 1;
                        image_id[8] = 3; positive[8] = 1;  image_id[9] = 4; positive[9] = 0;  image_id[10] = 1; positive[10] = 1; image_id[11] = 2; positive[11] = 0;
                        image_id[12] = 4; positive[12] = 0; image_id[13] = 1; positive[13] = 1; image_id[14] = 2; positive[14] = 1; image_id[15] = 4; positive[15] = 0;
                    end
                    3'd3: begin
                        // Game 3 initial state[cite: 9]
                        image_id[0] = 3; positive[0] = 1;  image_id[1] = 1; positive[1] = 1;  image_id[2] = 4; positive[2] = 1;  image_id[3] = 2; positive[3] = 1;
                        image_id[4] = 4; positive[4] = 1;  image_id[5] = 2; positive[5] = 0;  image_id[6] = 3; positive[6] = 0;  image_id[7] = 1; positive[7] = 0;
                        image_id[8] = 1; positive[8] = 1;  image_id[9] = 3; positive[9] = 0;  image_id[10] = 2; positive[10] = 0; image_id[11] = 4; positive[11] = 0;
                        image_id[12] = 2; positive[12] = 0; image_id[13] = 4; positive[13] = 1; image_id[14] = 1; positive[14] = 1; image_id[15] = 3; positive[15] = 0;
                    end
                    default: begin
                        for (int i = 0; i < 16; i = i + 1) begin
                            image_id[i] <= 1; positive[i] <= 1;
                        end
                    end
                endcase
            end

            // Keyboard command processing during GAME state
            if (state == GAME) begin
                if (key_event) begin
                    case (parse_state)
                        PARSE_IDLE: begin
                            if (key_pressed == key_1 || key_pressed == key_2) begin
                                op_type <= (key_pressed == key_1) ? 2'd1 : 2'd2;
                                parse_state <= PARSE_WAIT_OP_ENT;
                            end
                        end
                        PARSE_WAIT_OP_ENT: begin
                            if (key_pressed == key_enter) begin
                                parse_state <= PARSE_WAIT_TARGET;
                            end else begin
                                parse_state <= PARSE_IDLE;
                            end
                        end
                        PARSE_WAIT_TARGET: begin
                            if (op_type == 2'd1) begin
                                if (key_pressed >= key_5 && key_pressed <= key_comma) begin
                                    saved_target <= key_pressed;
                                    parse_state <= PARSE_WAIT_TAR_ENT;
                                end
                            end else begin
                                if (key_pressed >= key_1 && key_pressed <= key_4) begin
                                    saved_target <= key_pressed;
                                    parse_state <= PARSE_WAIT_TAR_ENT;
                                end
                            end
                        end
                        PARSE_WAIT_TAR_ENT: begin
                            if (key_pressed == key_enter) begin
                                if (op_type == 2'd1) begin
                                    // Operation 1: Change image ID in one cell (1 -> 2 -> 3 -> 4 -> 1)[cite: 9]
                                    logic [3:0] idx;
                                    idx = get_grid_idx(saved_target);
                                    image_id[idx] <= (image_id[idx] == 3'd4) ? 3'd1 : image_id[idx] + 1'b1;
                                end else begin
                                    // Operation 2: Invert all cells containing selected image[cite: 9]
                                    logic [2:0] target_img;
                                    target_img = get_img_id(saved_target);
                                    for (int i = 0; i < 16; i = i + 1) begin
                                        if (image_id[i] == target_img) begin
                                            positive[i] <= ~positive[i];
                                        end
                                    end
                                end
                            end
                            parse_state <= PARSE_IDLE;
                        end
                        default: parse_state <= PARSE_IDLE;
                    endcase
                end
            end else begin
                parse_state <= PARSE_IDLE;
            end
        end
    end

    // State transition logic
    always_comb begin
        next_state = state;

        case (state)
            INIT: begin
                if (start_pulse)
                    next_state = SHOW;
            end

            SHOW: begin
                if (start_pulse)
                    next_state = GAME;
            end

            GAME: begin
                if (&positive)
                    next_state = FINISH;
            end

            FINISH: begin
                if (start_pulse)
                    next_state = INIT;
            end

            default: next_state = INIT;
        endcase
    end

    // ============================================================
    // 8. VGA DISPLAY OUTPUT LOGIC
    // ============================================================

    always_comb begin
        // Default: black
        vgaRed   = 4'b0000;
        vgaGreen = 4'b0000;
        vgaBlue  = 4'b0000;

        if (video_valid) begin
            case (state)
                INIT: begin
                    // Black screen
                end

                SHOW: begin
                    if (grid_row < 2'd2) begin
                        // Row 0: negative film, Row 1: positive film[cite: 8]
                        logic [11:0] final_px;
                        final_px = active_positive ? image_pixel : ~image_pixel;
                        vgaRed   = final_px[11:8];
                        vgaGreen = final_px[7:4];
                        vgaBlue  = final_px[3:0];
                    end
                end

                GAME, FINISH: begin
                    if (grid_row < 4 && grid_col < 4) begin
                        logic [11:0] final_px;
                        final_px = active_positive ? image_pixel : ~image_pixel;
                        vgaRed   = final_px[11:8];
                        vgaGreen = final_px[7:4];
                        vgaBlue  = final_px[3:0];
                    end
                end

                default: begin
                    // Black
                end
            endcase
        end
    end

    // ============================================================
    // 9. LED FLASH & STATUS LOGIC
    // ============================================================

    logic flash_en, t1;
    logic [31:0] cnt;

    always_ff @(posedge clk, posedge rst) begin
        if (rst) 
            cnt <= 0;
        else if (state == FINISH) begin
            if (cnt >= 100_000_000)
                cnt <= 0;
            else 
                cnt <= cnt + 1; 
        end else
            cnt <= 0;
    end

    assign t1 = (cnt == 100_000_000) && (state == FINISH);

    always_ff @(posedge clk, posedge rst) begin
        if (rst)
            flash_en <= 0;
        else if (state == FINISH) begin
            if (t1)
                flash_en <= ~flash_en;
        end
    end

    always_comb begin : blockName
        case (state)
            INIT: begin
                led = 16'h0000;
            end

            SHOW: begin
                led = 16'h0000;
            end

            GAME: begin
                for (int i = 0 ; i < 16 ; i = i + 1)
                    led[i] = positive[i]; // LED[i] maps to grid i+1[cite: 9]
            end

            FINISH: begin
                if (flash_en)
                    led = {16{1'b1}};
                else
                    led = 16'h0000;
            end

            default: begin
                led = 16'h0000;
            end
        endcase
    end

endmodule
