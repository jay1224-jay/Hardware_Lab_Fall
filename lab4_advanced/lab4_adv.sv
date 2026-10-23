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
    logic single_key_valid;
    logic next_single_key_valid;
    key_pressed_t key_presseed;

    // Ensure only one key press at a time
    always_ff @(posedge clk or posedge rst) 
        single_key_valid <= rst ? 1'b1 : next_single_key_valid;
    assign next_single_key_valid = 
        single_key_valid ? !(key_valid && key_down[last_change]) : 
                            (key_valid && key_down == 512'b0);

    KeyboardDecoder key_de (
		.key_down(key_down),
		.last_change(last_change),
		.key_valid(single_key_valid),
		.PS2_DATA(PS2_DATA),
		.PS2_CLK(PS2_CLK),
		.rst(rst),
		.clk(clk)
	);

    always_comb begin
		case (last_change)
			9'h175 : key_pressed = key_UP;
            9'h172 : key_pressed = key_DOWN;
            9'h16B : key_pressed = key_LEFT;
            9'h174 : key_pressed = key_RIGHT;

            9'h01D : key_presseed = key_W;
            9'h01B : key_presseed = key_S;
            9'h05A : key_presseed = key_ENTER;
            9'h029 : key_presseed = key_SPACE;
            
			default : key_presseed = {9{1'b1}};
		endcase
	end
                        
    // ========= Keyboard Input ===========

    state_t game_state, game_state_prev;    
    always_ff @(posedge clk or posedge rst) begin
        if (rst) game_state_prev <= S_INITIAL;
        else game_state_prev <= game_state;
    end

    logic [25:0] clk_cnt;
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

    logic [4:0]  score;
    logic        meat_active;
    logic [4:0]  meat_node; // [4:3] = digit, [2:0] = segment
    logic        ate_meat;

    logic [1:0] input_direction; // 00:Up, 01:Right, 10:Down, 11:Left
    always_comb begin
        if (single_key_valid && (key_presseed == key_UP || key_presseed == key_DOWN || key_presseed == key_LEFT || key_presseed == key_RIGHT)) begin
            case (key_presseed)
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

    snake_7seg_graph_core gg(
        .clk(clk),
        .rst(rst),
        .start_game(key_presseed == key_ENTER), // Enter
        .restart(key_presseed == key_SPACE),     // Space
        .step(clk_cnt[25]),             // 1 step per 2^26 clk cycles
        .lfsr_candidate(lfsr), // 5-bit LFSR
        .dir_input_valid(single_key_valid && (key_presseed == key_UP || key_presseed == key_DOWN || key_presseed == key_LEFT || key_presseed == key_RIGHT)),
        .input_direction(input_direction),
        .score(score),
        .meat_active(meat_active),
        .meat_node(meat_node),
        .ate_meat(ate_meat),
        .game_state(game_state)
    );

    logic [1:0]  disp_mux_sel; // display digit selector
    assign disp_mux_sel = clk_cnt[17:16];

    assign DIGIT = ~(4'b1 << (2'd3 - disp_mux_sel));

    // TODO: assign DISPLAY
    always_comb begin
        case (game_state)
            S_INITIAL: begin // Display __00
                case(DIGIT)
                    4'b1110: DISPLAY = 7'b1000000; 
                    4'b1101: DISPLAY = 7'b1000000;
                    default: DISPLAY = 7'b1111111;
                endcase
            end
            S_PLAY: begin // PLAY: display_grid + meat blink
            end
            S_FINAL: begin
            end
            default: ;
        endcase
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
    output state_t      game_state,
    output // TODO: data for 7-segment display
);

    state_t state;
    assign game_state = state;

    logic [1:0] curr_digit, next_digit;
    logic [2:0] curr_seg,   next_seg;
    logic [1:0] direction, next_direction; // 00:Up, 01:Right, 10:Down, 11:Left

    // Input Buffer – latch last valid direction, consume on step
    logic       action_valid;
    logic [1:0] action;

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

    logic eating_meat;

    // Collision Detection 
    logic dead;
    always_comb begin
        dead = 1'b0;
        if (state == S_PLAY) begin
            // 1. Self-bite: next node occupied by snake body
            //    Exception: tail will be popped this step AND next_node is the tail
            if (snake_body[head_ptr])
            // 2. Dead-end
            if (next_seg == -1) dead = 1'b1;
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

    logic meat_node_occupied;
    logic [4:0] snake_length;

    assign snake_length = (head_ptr >= tail_ptr) ? 
                          head_ptr - tail_ptr + 1: 
                          32 - (tail_ptr - head_ptr - 1);
    integer index;
    always_comb begin
        meat_node_occupied = 1'b0;
        for (index = 0; index < 32; index = index + 1) begin
            if (snake_body[(tail_ptr + index) % 32] == meat_node && index < snake_length) 
            begin
                meat_node_occupied = 1'b1;
            end
        end
    end

    assign eating_meat = meat_node_occupied && meat_active && (next_digit == meat_node[4:3]) && (next_seg == meat_node[2:0]);

    // Main FSM & snake_body / Grid / Meat Update
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= S_INITIAL;
        end else begin
            ate_meat <= 1'b0; // default: clear pulse

            case (state)
                S_INITIAL: begin
                    if (start_game) state <= S_PLAY;
                end

                S_PLAY: begin
                    // --- Meat spawning (every clk) ---
                    if (!meat_active) begin
                        meat_node   <= lfsr_candidate;
                        if (!meat_node_occupied)
                            meat_active <= 1'b1;
                    end

                    // --- Step processing ---
                    if (step) begin
                        if (dead) begin
                            state <= S_FINAL;
                        end else begin
                            // Update direction
                            direction <= next_direction;

                            // TODO
                            // Push new head into snake_body
                            // Light new head segment
                            // Be careful about the off-by-one error
                            snake_body[head_ptr] <= {next_digit, next_seg};
                            head_ptr <= head_ptr + 5'd1;

                            // Eat meat or pop tail
                            if (eating_meat) begin
                                meat_active <= 1'b0;
                                ate_meat    <= 1'b1;
                            end else begin
                                tail_ptr <= tail_ptr + 5'd1;
                                snake_body[tail_ptr] <= 5'b11111;
                            end
                        end
                    end
                end 

                S_FINAL:
                default: state <= S_INITIAL;
            endcase
        end
    end
    assign score = 0; // TODO
endmodule
