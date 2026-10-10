`timescale 1ns / 1ps

module seg_display (
    input  logic slow_clk,
    input  logic p5_clk,
    input  logic rst,
    input  logic [1:0] state,
    input  logic [3:0] display_numbers[3:0],
    output logic [7:0] DISPLAY,
    output logic [3:0] digit
);

    logic [3:0] value, mask;
    logic toggle;
    
    always_comb begin
        if (state == 2'b01)
            if (toggle)
                mask = 4'b0000;
            else
                mask = 4'b1100;
        else if (state == 2'b10)
            if (toggle)
                mask = 4'b0000;
            else
                mask = 4'b0011;
        else
            mask = 4'b0000;
    end
    

    always_ff @( posedge slow_clk, posedge rst ) begin
        if ( rst )
            toggle <= 0;
        else if ( p5_clk )
            toggle <= ~toggle;
    end

    always_ff @( posedge slow_clk, posedge rst ) begin
        if ( rst || state == 2'b00 ) begin
            value <= 4'd7;
            digit <= 4'b0000;
        end else begin
            case (digit)
                4'b1110: begin
                    value <= display_numbers[1];
                    digit <= 4'b1101;
                end
                4'b1101: begin
                    value <= display_numbers[2];
                    digit <= 4'b1011;         
                end
                4'b1011: begin
                    value <= display_numbers[3];
                    digit <= 4'b0111;
                end
                4'b0111: begin
                    value <= display_numbers[0];
                    digit <= 4'b1110;
                end
                default: begin
                    value <= 0;
                    digit <= 4'b1110;
                end
            endcase
        end
    end

    always_comb begin
        case (value)
            //                  ABC_DEFG (neg)
            4'd0: DISPLAY = 8'b1100_0000;
            4'd1: DISPLAY = 8'b1111_1001;
            4'd2: DISPLAY = 8'b1010_0100;
            4'd3: DISPLAY = 8'b1011_0000;
            4'd4: DISPLAY = 8'b1001_1001;
            4'd5: DISPLAY = 8'b1001_0010;
            4'd6: DISPLAY = 8'b1000_0010;
            4'd7: DISPLAY = 8'b1111_1000;
            4'd8: DISPLAY = 8'b1000_0000;
            4'd9: DISPLAY = 8'b1001_0000;
            default: DISPLAY = 8'b1000_0000;
        endcase
    end
    
endmodule

module lab3_advanced_1 (
    input  logic clk,
    input  logic rst,
    input  logic [7:0] number,
    input  logic set,
    output logic [1:0] mode_state,
    output logic [7:0] DISPLAY,
    output logic [3:0] DIGIT
);

    parameter INIT   = 2'b00;
    parameter SET1   = 2'b01;
    parameter SET2   = 2'b10;
    parameter RESULT = 2'b11;

    logic [1:0] state, next_state;
    logic [3:0] display_numbers [3:0];
    logic slow_clk, p5_enable;

    logic [7:0] num1, num2;
    logic [8:0] sum;

    logic debounced_set, one_pulse_set;

    clock_divider #(.n(15)) display_clk(clk, rst, 1, slow_clk);
    debounce my_deb(clk, set, debounced_set);
    one_pulse my_one(clk, rst, debounced_set, one_pulse_set);
    
    timer #(.n(50_000_000)) my_timer(clk, rst, state == SET1 || state == SET2, p5_enable);

    always_ff @( posedge clk, posedge rst ) begin
        if (rst) state <= INIT;
        else if ( state == INIT || one_pulse_set ) state <= next_state;
    end

    always_comb begin
        next_state = state;
        mode_state = 0;
        case (state)
            INIT: begin
                next_state = SET1;
                mode_state = 2'b00;
            end
            SET1: begin
                next_state = SET2;
                mode_state = 2'b01;
            end 
            SET2: begin
                next_state = RESULT;
                mode_state = 2'b10;
            end 
            RESULT: begin
                next_state = SET1;
                mode_state = 2'b11;
            end 
            default: begin
                next_state = INIT;
                mode_state = 2'b00;
            end
        endcase
    end

    // display_numbers decision
    assign sum = num1 + num2;
    always_ff @( posedge clk, posedge rst ) begin
        if ( rst ) begin
            display_numbers[0] <= 0;
            display_numbers[1] <= 0;
            display_numbers[2] <= 0;
            display_numbers[3] <= 0;
        end else begin
            case (state)
                INIT: begin
                    display_numbers[0] <= 0;
                    display_numbers[1] <= 0;
                    display_numbers[2] <= 0;
                    display_numbers[3] <= 0;
                end
                SET1: begin
                    display_numbers[0] <= 0;
                    display_numbers[1] <= 0;
                    display_numbers[2] <= number[3:0];
                    display_numbers[3] <= number[7:4];
                    num1 <= number[7:4] * 10 + number[3:0];
                end 
                SET2: begin
                    display_numbers[0] <= number[3:0];
                    display_numbers[1] <= number[7:4];
                    display_numbers[2] <= num1 % 10;
                    display_numbers[3] <= num1 / 10;
                    num2 <= number[7:4] * 10 + number[3:0];
                end 
                RESULT: begin
                    display_numbers[0] <= sum % 10;
                    display_numbers[1] <= (sum % 100) / 10;
                    display_numbers[2] <= sum / 100;
                    display_numbers[3] <= 0;
                end 
                default: begin
                    display_numbers[0] <= 0;
                    display_numbers[1] <= 0;
                    display_numbers[2] <= 0;
                    display_numbers[3] <= 0;
                end
            endcase
        end
    end

    seg_display my_seg(slow_clk, p5_enable, rst, state, display_numbers, DISPLAY, DIGIT);

endmodule

module timer #(
    parameter integer n = 100_000_000
) (
    input  logic clk,
    input  logic rst,
    input  logic enable,
    output logic time_clk
);

    logic [31:0] counter, next_counter;

    always_ff @( posedge clk, posedge rst ) begin
        if (rst) counter <= 0;
        else counter <= next_counter;
    end

    always_comb begin
        if ( enable ) 
            if ( counter == n ) 
                next_counter = 0;
            else
                next_counter = counter + 1;
        else
            next_counter = 0;
    end

    assign time_clk = enable && (counter == n);
    
endmodule

module clock_divider #(
    parameter integer n = 15
) (
    input  logic clk,
    input  logic rst,
    input  logic enable,
    output logic div_clk
);

    logic [n-1:0] num, next_num;

    always_ff @( posedge clk, posedge rst ) begin
        if ( rst ) num <= 0;
        else num <= next_num;
    end

    assign next_num = (enable) ? (num + 1) : 0;
    assign div_clk  = num[n-1];
    
endmodule

module debounce (
    input  logic clk,
    input  logic pb,
    output logic pb_debounced
);

    logic [3:0] pb_reg;

    always_ff @( posedge clk ) begin
        pb_reg <= {pb_reg[2:0], pb};
    end

    assign pb_debounced = &pb_reg;
    
endmodule

module one_pulse (
    input  logic clk,
    input  logic rst,
    input  logic pb_debounced,
    output logic pb_1_pusle
);
    logic delay;
    always_ff @( posedge clk ) begin
        delay <= pb_debounced;
    end
    assign pb_1_pusle = ~delay & pb_debounced;
    
endmodule
