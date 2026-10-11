`timescale 1ns / 1ps

// states
`define INIT  2'b00
`define RUN   2'b01
`define PAUSE 2'b10

module display_controller (
    input logic clk, 
    input logic rst, 
    input logic speed,
    input logic en_left, 
    input logic en_right, 
    input logic en_pause,
    input logic [1:0] state,
    output logic [7:0] DISPLAY, 
    output logic [3:0] DIGIT
);

    logic t1_enable, t05_enable;
    logic n15_div_clk;

    logic [7:0] displayed_chars [3:0];
    logic [7:0] current_char;

    logic [3:0] display_index [3:0];
    logic [7:0] marquee_string [11:0];
    integer i;

    logic dir;

    timer #(.n(100_000_000)) t_1(
        .clk(clk), .rst(rst), .enable(state == `RUN), .tick(t1_enable)
    );
    timer #(.n(50_000_000)) t_05(
        .clk(clk), .rst(rst), .enable(state == `RUN), .tick(t05_enable)
    );

    clock_divider #(.n(15)) n15(
        .clk(clk), .rst(rst), .div_clk(n15_div_clk)
    );

    always_ff @( posedge clk, posedge rst ) begin
        if (rst) dir <= 0; // left
        else if (state == `RUN) begin
            if ( en_left )
                dir <= 0;
            else if ( en_right ) 
                dir <= 1; 
        end
    end

    always_ff @( posedge clk, posedge rst ) begin
        if (rst) begin
            display_index[3] <= 4'd11;
            display_index[2] <= 4'd10;
            display_index[1] <= 4'd9;
            display_index[0] <= 4'd8;
        end
        else if ((!speed && t1_enable) || (speed && t05_enable)) begin
            for ( i = 0 ; i < 4 ; i = i + 1 ) begin
                if ( dir ) begin // right
                    if ( display_index[i] >= 11 )
                        display_index[i] <= 0;
                    else
                        display_index[i] <= display_index[i] + 1;
                end
                else begin // left
                    if ( display_index[i] <= 0 )
                        display_index[i] <= 11;
                    else
                        display_index[i] <= display_index[i] - 1;
                end
            end
        end
    end

    always_comb begin
        marquee_string[11] = "n";
        marquee_string[10] = "t";
        marquee_string[9] = "h";
        marquee_string[8] = "u";
        marquee_string[7] = "E";
        marquee_string[6] = "E";
        marquee_string[5] = "C";
        marquee_string[4] = "S";
        marquee_string[3] = "2";
        marquee_string[2] = "0";
        marquee_string[1] = "2";
        marquee_string[0] = "6";
    end
    integer j;
    always_comb begin
        for ( j = 0 ; j < 4 ; j = j + 1 )
            displayed_chars[j] = marquee_string[display_index[j]];
    end

    always_ff @( posedge n15_div_clk, posedge rst ) begin
        if (rst) begin
            DIGIT <= 4'b1111;
            current_char <= "C";
        end
        else begin
            case (DIGIT)
                4'b1110: begin
                    DIGIT <= 4'b1101;
                    current_char <= displayed_chars[1];
                end
                4'b1101: begin
                    DIGIT <= 4'b1011;
                    current_char <= displayed_chars[2];
                end
                4'b1011: begin
                    DIGIT <= 4'b0111;
                    current_char <= displayed_chars[3];
                end
                4'b0111: begin
                    DIGIT <= 4'b1110;
                    current_char <= displayed_chars[0];
                end
                default: begin
                    DIGIT <= 4'b1110;
                    current_char <= "6";
                end
            endcase
        end
    end

    always_comb begin : display_single_digit
        case (current_char)
            //                DPGFE_DCBA 
            "n": DISPLAY = 8'b1010_1011;
            "t": DISPLAY = 8'b1000_0111;
            "h": DISPLAY = 8'b1000_1011;
            "u": DISPLAY = 8'b1110_0011;
            "E": DISPLAY = 8'b1000_0110;
            "C": DISPLAY = 8'b1100_0110;
            "S": DISPLAY = 8'b1001_0010;
            "2": DISPLAY = 8'b1010_0100;
            "0": DISPLAY = 8'b1100_0000;
            "6": DISPLAY = 8'b1000_0010;
            default: DISPLAY = 8'b0000_0000;
        endcase
    end
    
endmodule

module lab3_advanced_2(
    input logic clk, 
    input logic rst, 
    input logic speed,
    input logic left, 
    input logic right, 
    input logic pause,
    output logic [1:0] mode_state, 
    output logic dir,
    output logic [7:0] DISPLAY, 
    output logic [3:0] DIGIT
);

    logic [1:0] state, next_state;
    logic en_pause, en_left, en_right;

    debounce_and_pulse dp_pause(
        .clk(clk),
        .pb(pause),
        .pb_pulse(en_pause)
    );

    debounce_and_pulse dp_left(
        .clk(clk),
        .pb(left),
        .pb_pulse(en_left)
    );

    debounce_and_pulse dp_right(
        .clk(clk),
        .pb(right),
        .pb_pulse(en_right)
    );

    display_controller my_dc(
        .clk(clk),
        .rst(rst),
        .speed(speed),
        .en_left(en_left),
        .en_right(en_right),
        .en_pause(en_pause),
        .state(state),
        .DISPLAY(DISPLAY),
        .DIGIT(DIGIT)
    );

    always_ff @( posedge clk, posedge rst ) begin
        if (rst) state <= `INIT;
        else state <= next_state;
    end

    always_comb begin
        next_state = state;
        mode_state = 2'b00;
        case (state)
            `INIT: begin
                next_state = `RUN;
                mode_state = 2'b00;
            end
            `RUN: begin
                if (en_pause)
                    next_state = `PAUSE;
                mode_state = 2'b01;
            end
            `PAUSE: begin
                if (en_pause)
                    next_state = `RUN;
                mode_state = 2'b10;
            end
            default: begin
                next_state = `RUN;
                mode_state = 2'b00;
            end
        endcase
    end

    always_ff @( posedge clk, posedge rst ) begin
        if (rst) dir <= 0;
        else if (state == `RUN) begin
            if ( left ) 
                dir <= 0;
            else if ( right )
                dir <= 1; 
        end
    end

endmodule

module timer #(
    parameter integer n = 100_000_000 // 1 sec
) (
    input  logic clk,
    input  logic rst,
    input  logic enable,
    output logic tick
);

    logic [31:0] cnt;

    always_ff @( posedge clk, posedge rst ) begin
        if (rst) 
            cnt <= 0;
        else if (enable == 0)
            cnt <= 0;
        else if (cnt == n)
            cnt <= 0;
        else
            cnt <= cnt + 1;
    end

    assign tick = enable && (cnt == n);
    
endmodule

module clock_divider #(
    parameter integer n = 15
) (
    input  logic clk,
    input  logic rst,
    output logic div_clk
);

    logic [n-1:0] num;

    always_ff @( posedge clk, posedge rst ) begin
        if (rst) num <= 0;
        else num <= num + 1;
    end

    assign div_clk = num[n-1];
    
endmodule

module debounce_and_pulse (
    input  logic clk,
    input  logic pb,
    output logic pb_pulse
);
    
    logic [3:0] shift_reg;
    logic delay;

    always_ff @( posedge clk ) begin
        shift_reg <= {shift_reg[2:0], pb};
        delay <= (shift_reg == 4'b1111);
    end

    assign pb_pulse = ~delay & (shift_reg == 4'b1111);

endmodule
