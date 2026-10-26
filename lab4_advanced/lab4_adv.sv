typedef enum logic [1:0] {
    S_INITIAL = 2'd0,
    S_PLAY    = 2'd1,
    S_FINAL   = 2'd2
} state_t;

typedef enum logic [2:0] {
    key_UP      = 3'd0,
    key_DOWN    = 3'd1,
    key_LEFT    = 3'd2,
    key_RIGHT   = 3'd3,

    key_W = 3'd4,
    key_S = 3'd5,
    key_ENTER = 3'd6,
    key_SPACE = 3'd7
} key_pressed_t;

module LFSR (
    input logic clk,
    input logic rst,
    input logic enable,
    output logic [4:0] out
);

    always_ff @( posedge clk, posedge rst ) begin
        if (rst) out <= 5'b00001;
        else if (enable) out <= {out[3:0], out[4] ^ out[1]};
    end
    
endmodule

module lab4_adv (
    input  logic clk,
    input  logic rst,
    inout  logic PS2_DATA,
    inout  logic PS2_CLK,
    output logic [15:0] led,
    output logic audio_mclk,
    output logic audio_lrck,
    output logic audio_sck,
    output logic audio_sdin,
    output logic [6:0] DISPLAY,
    output logic [0:3] DIGIT
);

    // TODO: Note Frequency Divider Constants
    localparam [21:0] DIV_C5  = 0;          // TODO
    localparam [21:0] DIV_SIL = 22'd1;      // silence

    logic [4:0] lfsr;
    LFSR lfsr_gg (
        .clk(clk),
        .rst(rst),
        .enable(1'b1),
        .out(lfsr)
    );

    // ========= Keyboard Input ===========

    logic [511:0] key_down;
    logic [8:0]   last_change;
    logic         key_valid;
    logic         key_press_event;
    key_pressed_t key_pressed;

    KeyboardDecoder key_de (
		.key_down(key_down),
		.last_change(last_change),
		.key_valid(key_valid),
		.PS2_DATA(PS2_DATA),
		.PS2_CLK(PS2_CLK),
		.rst(rst),
		.clk(clk)
	);

    always_comb begin
		case (last_change[7:0])
			8'h75 : key_pressed = key_UP;
            8'h72 : key_pressed = key_DOWN;
            8'h6B : key_pressed = key_LEFT;
            8'h74 : key_pressed = key_RIGHT;

            8'h1D : key_pressed = key_W;
            8'h1B : key_pressed = key_S;
            8'h5A : key_pressed = key_ENTER;
            8'h29 : key_pressed = key_SPACE;
            
			default : key_pressed = key_W;
		endcase
	end
    assign key_press_event = key_valid && key_down[last_change];
                        
    // ========= Keyboard Input ===========

    state_t game_state, game_state_prev;    
    always_ff @(posedge clk or posedge rst) begin
        if (rst) game_state_prev <= S_INITIAL;
        else game_state_prev <= game_state;
    end

    logic [25:0] clk_cnt;
    logic game_step;
    assign game_step = &clk_cnt;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) clk_cnt <= 26'd0;
        else
        begin
            if (game_state != game_state_prev) clk_cnt <= 26'd0;
            else clk_cnt <= clk_cnt + 1;
        end
    end

    logic meat_blink_on;
    assign meat_blink_on = ~clk_cnt[24]; // start with ON phase

    logic [2:0] volume;

    logic [23:0] audio_beat;
    logic [2:0]  audio_seq_idx; // note index in sequence

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            audio_beat    <= 24'd0;
            audio_seq_idx <= 3'd0;
        end else begin
            // State transition → reset audio
            if (game_state != game_state_prev) begin
                audio_beat    <= 24'd0;
                audio_seq_idx <= 3'd0;
            end else begin
                audio_beat <= audio_beat + 24'd1;
                // TODO: update audio_seq_idx according to state
            end
        end
    end

    // Frequency selection based on state and sequence index
    logic [21:0] freq_div;
    always_comb begin
        case (game_state)
        // TODO: update freq_div according to state
            S_INITIAL: begin
                case (audio_seq_idx)
                    3'd0: freq_div = DIV_C5;
                    default: freq_div = DIV_SIL;
                endcase
            end
            default: freq_div = DIV_SIL;
        endcase
    end

    /*
    always_comb begin
        freq_div = DIV_SIL;
        case (game_state)
            S_INITIAL: case (audio_seq_idx)
                3'd0: freq_div = DIV_C5;
                3'd1: freq_div = DIV_D5;
                3'd2: freq_div = DIV_E5;
                3'd3: freq_div = DIV_F5;
                default: freq_div = DIV_SIL;
            endcase
            S_PLAY:  if (sfx_active) freq_div = DIV_G5;
            S_FINAL: case (audio_seq_idx)
                3'd0: freq_div = DIV_E4;
                3'd1: freq_div = DIV_D4;
                3'd2: freq_div = DIV_C4;
                default: freq_div = DIV_SIL;
            endcase
            default: ;
        endcase
    end
    */



    logic [4:0]  score;
    logic        meat_active;
    logic [4:0]  meat_node; // [4:3] = digit, [2:0] = segment
    logic        ate_meat;

    logic [1:0] input_direction; // 00:Up, 01:Right, 10:Down, 11:Left
    always_comb begin
        if (key_press_event && (key_pressed == key_UP || key_pressed == key_DOWN || key_pressed == key_LEFT || key_pressed == key_RIGHT)) begin
            case (key_pressed)
                key_UP:    input_direction = 2'b00;
                key_RIGHT: input_direction = 2'b01;
                key_DOWN:  input_direction = 2'b10;
                key_LEFT:  input_direction = 2'b11;
                default:   input_direction = 2'b00; // should not happen
            endcase
        end else begin
            input_direction = 2'b00; // default direction
        end
    end

    logic [6:0] snake_body_display [0:3];
    logic [4:0] snake_length;

    snake_7seg_graph_core gg(
        .clk(clk),
        .rst(rst),
        .start_game(key_press_event && key_pressed == key_ENTER),
        .restart(key_press_event && (key_pressed == key_SPACE || key_pressed == key_ENTER)),
        .step(game_step),
        .lfsr_candidate(lfsr-1), // 5-bit LFSR
        .dir_input_valid(key_press_event && (key_pressed == key_UP || key_pressed == key_DOWN || key_pressed == key_LEFT || key_pressed == key_RIGHT)),
        .input_direction(input_direction),
        .score(score),
        .meat_active(meat_active),
        .meat_node(meat_node),
        .ate_meat(ate_meat),
        .snake_length(snake_length),
        .game_state(game_state),
        .DISPLAY(snake_body_display)
    );

    logic [1:0]  disp_mux_sel; // display digit selector
    assign disp_mux_sel = clk_cnt[17:16];

    assign DIGIT = ~(4'b1 << (2'd3 - disp_mux_sel));

    logic [6:0] score_num1_display, score_num0_display;
    logic score_blink;
    assign score_blink = clk_cnt[25];

    always_comb begin
    	case (score/10)
    		4'd0: score_num1_display = 7'b1000000;
            4'd1: score_num1_display = 7'b1111001;
            4'd2: score_num1_display = 7'b0100100;
            4'd3: score_num1_display = 7'b0110000;
            4'd4: score_num1_display = 7'b0011001;
            4'd5: score_num1_display = 7'b0010010;
            4'd6: score_num1_display = 7'b0000010;
            4'd7: score_num1_display = 7'b1111000;
            4'd8: score_num1_display = 7'b0000000;
            4'd9: score_num1_display = 7'b0010000;
			default : score_num1_display = 7'b1111111;
    	endcase
    end
    always_comb begin
    	case (score%10)
    		4'd0: score_num0_display = 7'b1000000;
            4'd1: score_num0_display = 7'b1111001;
            4'd2: score_num0_display = 7'b0100100;
            4'd3: score_num0_display = 7'b0110000;
            4'd4: score_num0_display = 7'b0011001;
            4'd5: score_num0_display = 7'b0010010;
            4'd6: score_num0_display = 7'b0000010;
            4'd7: score_num0_display = 7'b1111000;
            4'd8: score_num0_display = 7'b0000000;
            4'd9: score_num0_display = 7'b0010000;
			default : score_num0_display = 7'b1111111;
    	endcase
    end



    always_comb begin
        DISPLAY = 7'b1111111;
        case (game_state)
            S_INITIAL: begin // Display __00
                case(DIGIT)
                    4'b1110: DISPLAY = 7'b1000000; 
                    4'b1101: DISPLAY = 7'b1000000;
                    default: DISPLAY = 7'b1111111;
                endcase
            end
            S_PLAY: begin // PLAY: display_grid + meat blink
                case (DIGIT)
                    4'b1110: DISPLAY = snake_body_display[3];
                    4'b1101: DISPLAY = snake_body_display[2];
                    4'b1011: DISPLAY = snake_body_display[1];
                    4'b0111: DISPLAY = snake_body_display[0];
                    default: DISPLAY = 7'b1111111;
                endcase
                case (DIGIT)
                    4'b1110: begin
                        if (meat_active && meat_blink_on && meat_node[4:3] == 3)
                            DISPLAY &= ~(7'b0000001 << (meat_node[2:0]));
                    end
                    4'b1101: begin
                        if (meat_active && meat_blink_on && meat_node[4:3] == 2)
                            DISPLAY &= ~(7'b0000001 << (meat_node[2:0]));
                    end
                    4'b1011: begin
                        if (meat_active && meat_blink_on && meat_node[4:3] == 1)
                            DISPLAY &= ~(7'b0000001 << (meat_node[2:0]));
                    end
                    4'b0111: begin
                        if (meat_active && meat_blink_on && meat_node[4:3] == 0)
                            DISPLAY &= ~(7'b0000001 << (    meat_node[2:0]));
                    end
                    default: DISPLAY &= 7'b1111111;
                endcase
            end
            S_FINAL: begin
                case (DIGIT)
                    4'b1110: begin
                        if (score_blink)
                            DISPLAY = score_num0_display;
                    end
                    4'b1101: begin
                        if (score_blink)
                            DISPLAY = score_num1_display;
                    end
                    4'b1011: begin
                        if (~score_blink)
                            DISPLAY = score_num0_display;
                    end
                    4'b0111: begin
                        if (~score_blink)
                            DISPLAY = score_num1_display;
                    end
                    default: DISPLAY = 7'b1111111;
                endcase
            end
            default: ;
        endcase
    end

    always_ff @( posedge clk, posedge rst ) begin
        if (rst) volume <= 3'b011;
        else if (key_valid && key_pressed == key_W) begin
            if (volume < 3'b111)
                volume <= (volume << 1) + 3'b1;
        end
        else if (key_valid && key_pressed == key_S) begin
            if (volume > 0)
                volume <= (volume >> 1);
        end
            
    end

    always_comb begin
        led[15:13] = volume;
        led[12] = 0; // 0
        led[11:10] = snake_length / 10;
        led[9] = 0; // 0
        led[8:0] = snake_length % 10;
    end

endmodule

// Snake Core Module – Game logic only
module snake_7seg_graph_core (
    input  logic        clk,
    input  logic        rst,
    input  logic        start_game,      // INITIAL→PLAY
    input  logic        restart,         // FINAL→INITIAL
    input  logic        step,
    input  logic [4:0]  lfsr_candidate,
    // Player input
    input  logic        dir_input_valid,
    input  logic [1:0]  input_direction, // 00:Up, 01:Right, 10:Down, 11:Left
    // Outputs
    output logic [4:0]  score,
    output logic        meat_active,
    output logic [4:0]  meat_node, // [4:3] = digit, [2:0] = segment
    output logic        ate_meat,
    output logic [4:0]  snake_length,
    output state_t      game_state,
    output logic [6:0]  DISPLAY [0:3]
);

    state_t state;
    assign game_state = state;

    logic [1:0] curr_digit, next_digit;
    logic [2:0] curr_seg,   next_seg;
    logic [1:0] direction, next_direction; // 00:Up, 01:Right, 10:Down, 11:Left

    // Input Buffer – latch last valid direction, consume on step
    logic       action_valid;
    logic [1:0] action;

    localparam SEG_DEAD = 3'd7;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            action       <= 2'b01;
            action_valid <= 1'b0;
        end else if (state == S_FINAL && restart) begin
            // Reinitialize on FINAL→INITIAL
            action       <= 2'b01;
            action_valid <= 1'b0;
        end else if (state == S_PLAY) begin
            if (dir_input_valid) begin
                action       <= input_direction;
                action_valid <= 1'b1;
            end else if (step) begin
                action_valid <= 1'b0; // consume on step
            end
        end
    end

    // Snake Body (FIFO)
    logic [4:0] snake_body [0:31]; // Queue
    logic [4:0] head_ptr, tail_ptr;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            curr_digit <= 2'd2;
            curr_seg   <= 3'd0;
            direction  <= 2'b01;
        end else if (state == S_INITIAL) begin
            curr_digit <= 2'd2;
            curr_seg   <= 3'd0;
            direction  <= 2'b01;
        end else if (state == S_PLAY && step && !dead) begin
            curr_digit <= next_digit;
            curr_seg   <= next_seg;
            direction  <= next_direction;
        end
    end

    logic eating_meat;

    logic meat_candidate_occupied;
    integer candidate_index;
    always_comb begin
        meat_candidate_occupied = 1'b0;
        for (candidate_index = 0; candidate_index < 32; candidate_index = candidate_index + 1) begin
            if (candidate_index < snake_length &&
                snake_body[(tail_ptr + candidate_index) % 32] == lfsr_candidate)
                meat_candidate_occupied = 1'b1;
        end
    end

    logic dead;
    integer collision_index;
    always_comb begin
        dead = 1'b0;
        if (state == S_PLAY) begin
            if (next_seg == SEG_DEAD)
                dead = 1'b1;
            for (collision_index = 0; collision_index < 32; collision_index = collision_index + 1) begin
                if (collision_index < snake_length &&
                    (eating_meat || collision_index != 0) &&
                    snake_body[(tail_ptr + collision_index) % 32] == {next_digit, next_seg})
                    dead = 1'b1;
            end
        end
    end

    // Routing LUT – determines next_node from current position + input
    always_comb begin
        next_digit     = curr_digit;
        next_seg       = curr_seg;
        next_direction = direction;

        case (curr_seg)
            // TODO: complete the following routing logic for 28 segments
            // Horizontal Segments: a(0), d(3), g(6)
            3'd0: begin // 'a' – top horizontal
                case ({action_valid, action})
                    3'b110: begin // Down
                        next_seg       = direction[1] /*inertia is left*/ ? 3'd5 : 3'd1; // Left→f, Right→b
                        next_direction = action;
                    end 
                    default: begin // straight (continue left/right)
                        next_digit = direction[1] ? curr_digit - 2'd1 : curr_digit + 2'd1;
                        next_seg   = 3'd0;
                    end
                endcase
            end

            3'd3: begin // 'd' – top horizontal
                case ({action_valid, action})
                    3'b100: begin // Up
                        next_seg       = direction[1] ? 3'd4 : 3'd2; 
                        next_direction = action;
                    end 
                    default: begin // straight (continue left/right)
                        next_digit = direction[1] ? curr_digit - 2'd1 : curr_digit + 2'd1;
                        next_seg   = 3'd3;
                    end
                endcase
            end

            3'd6: begin // 'g' – top horizontal
                case ({action_valid, action})
                    3'b110: begin // Down
                        next_seg       = direction[1] ? 3'd4 : 3'd2; 
                        next_direction = action;
                    end
                    3'b100: begin // Up
                        next_seg       = direction[1] ? 3'd5 : 3'd1;
                        next_direction = action;
                    end 
                    default: begin // straight (continue left/right)
                        next_digit = direction[1] ? curr_digit - 2'd1 : curr_digit + 2'd1;
                        next_seg   = 3'd6;
                    end
                endcase
            end

            // Vertical Segments: b(1), c(2), e(4), f(5)
            3'd1: begin // 'b' – upper-right vertical
                case ({action_valid, action})
                    3'b101: begin // Right → cross to next digit
                        next_digit     = curr_digit + 2'd1;
                        next_seg       = direction[1] ? 3'd6 : 3'd0; // Down→g, Up→a
                        next_direction = action;
                    end
                    3'b111: begin // Left → stay same digit
                        next_seg       = direction[1] ? 3'd6 : 3'd0;
                        next_direction = action;
                    end
                    default: begin // straight (Up/Down)
                        next_seg = direction[1] ? 3'd2 : -1/*TODO: dead end*/; // Down→c, Up→dead-end
                    end
                endcase
            end
            3'd2: begin // 'c' – upper-right vertical
                case ({action_valid, action})
                    3'b101: begin // Right → cross to next digit
                        next_digit     = curr_digit + 2'd1;
                        next_seg       = direction[1] ? 3'd3 : 3'd6; // Down→g, Up→a
                        next_direction = action;
                    end
                    3'b111: begin // Left → stay same digit
                        next_seg       = direction[1] ? 3'd3 : 3'd6;
                        next_direction = action;
                    end
                    default: begin // straight (Up/Down)
                        next_seg = direction[1] ? -1 : 3'd1; // Down→c, Up→dead-end
                    end
                endcase
            end
            3'd4: begin // 'e' – upper-right vertical
                case ({action_valid, action})
                    3'b101: begin // Right → stay
                        next_seg       = direction[1] ? 3'd3 : 3'd6; // Down→g, Up→a
                        next_direction = action;
                    end
                    3'b111: begin // Left → cross
                        next_seg       = direction[1] ? 3'd3 : 3'd6;
                        next_digit     = curr_digit - 1;
                        next_direction = action;
                    end
                    default: begin // straight (Up/Down)
                        next_seg = direction[1] ? -1 : 3'd5; // Down→c, Up→dead-end
                    end
                endcase
            end
            3'd5: begin // 'f' – upper-right vertical
                case ({action_valid, action})
                    3'b101: begin // Right → cross to next digit
                        next_seg       = direction[1] ? 3'd6 : 3'd0; // Down→g, Up→a
                        next_direction = action;
                    end
                    3'b111: begin // Left → stay same digit
                        next_seg       = direction[1] ? 3'd6 : 3'd0;
                        next_digit     = curr_digit - 2'd1;
                        next_direction = action;
                    end
                    default: begin // straight (Up/Down)
                        next_seg = direction[1] ? 3'd4 : -1/*TODO: dead end*/; // Down→c, Up→dead-end
                    end
                endcase
            end
            default: ;
        endcase
    end

    assign snake_length = (head_ptr >= tail_ptr) ? 
                          head_ptr - tail_ptr + 1'b1:
                          6'd32 - tail_ptr + head_ptr + 1'b1;

    assign eating_meat = meat_active && (next_digit == meat_node[4:3]) && (next_seg == meat_node[2:0]);

    // Main FSM & snake_body / Grid / Meat Update
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= S_INITIAL;
            score <= 5'd0;
            meat_active <= 1'b0;
            ate_meat <= 1'b0;
            head_ptr <= 5'd2;
            tail_ptr <= 5'd0;
            snake_body[0] <= {2'd0, 3'd3};
            snake_body[1] <= {2'd1, 3'd3};
            snake_body[2] <= {2'd2, 3'd3};
        end else begin
            ate_meat <= 1'b0; // default: clear pulse

            case (state)
                S_INITIAL: begin
                    if (start_game) state <= S_PLAY;
                    score <= 5'd0;
                    meat_active <= 1'b0;
                    snake_body[0] <= {2'd0, 3'd0};
                    snake_body[1] <= {2'd1, 3'd0};
                    snake_body[2] <= {2'd2, 3'd0};
                    head_ptr <= 5'd2;
                    tail_ptr <= 5'd0;
                end

                S_PLAY: begin
                    // --- Meat spawning (every clk) ---
                    if (!meat_active && lfsr_candidate[2:0] != 3'd7 &&
                        !meat_candidate_occupied) begin
                        meat_node   <= lfsr_candidate;
                        meat_active <= 1'b1;
                    end

                    // --- Step processing ---
                    if (step) begin
                        if (dead) begin
                            state <= S_FINAL;
                        end else begin
                            snake_body[head_ptr + 5'd1] <= {next_digit, next_seg};
                            head_ptr <= head_ptr + 5'd1;

                            // Eat meat or pop tail
                            if (eating_meat) begin
                                meat_active <= 1'b0;
                                ate_meat    <= 1'b1;
                                score       <= score + 5'd1;
                            end else begin
                                tail_ptr <= tail_ptr + 5'd1;
                                // snake_body[tail_ptr] <= 5'b11111;
                            end
                        end
                    end
                end 

                S_FINAL: begin
                    if (restart)
                        state <= S_INITIAL;
                end
                default: state <= S_INITIAL;
            endcase
        end
    end

    integer index_gg;
    integer digit_index;
    always_comb begin
        DISPLAY[0] = 7'b1111111;
        DISPLAY[1] = 7'b1111111;
        DISPLAY[2] = 7'b1111111;
        DISPLAY[3] = 7'b1111111;
        for (index_gg = 0; index_gg < 32; index_gg = index_gg + 1) begin
            for (digit_index = 0 ; digit_index < 4 ; digit_index = digit_index + 1) begin
                if (index_gg < snake_length && 
                    snake_body[(index_gg + tail_ptr) % 32][4:3] == digit_index) begin
                        DISPLAY[digit_index] &= ~(7'b0000001 << (snake_body[(index_gg + tail_ptr) % 32][2:0]));
                end
            end
        end
    end

endmodule
 
