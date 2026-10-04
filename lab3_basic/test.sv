module mux (
    input  logic [15:0] in0,
    input  logic [15:0] in1,
    input  logic [15:0] in2,
    input  logic [15:0] in3,
    input  logic [1:0]  sel,
    output logic [15:0] out
);

    always_comb begin
        case (sel)
            2'b00:
                out = in0;
            2'b01:
                out = in1;
            2'b10:
                out = in2;
            2'b11:
                out = in3; 
            default: 
                out = 0;
        endcase
    end
    

endmodule

module LOAD_led (
    input  logic clk,
    input  logic rst,
    input  logic enable,
    input  logic [1:0] state,
    output logic end_load,
    output logic [15:0] led_out
);

    logic [15:0] next_led;
    logic [4:0]  cnt;

    always_ff @( posedge clk, posedge rst ) begin
        if ( rst || state != 2'b01 ) begin
            led_out <= 0;
            cnt <= 0;
        end
        else if ( enable ) begin
            led_out <= next_led;
            cnt <= cnt + 1;
        end
    end
    assign end_load = (cnt == 16);
    assign next_led = (enable) ? (led_out << 1) + 1'b1 : led_out;

endmodule

module PLAY_led_slow (
    input  logic clk,
    input  logic rst,
    input  logic enable,
    input  logic [1:0] state,
    output logic [15:0] led_out
);

    always_ff @( posedge clk, posedge rst ) begin
        if ( rst || state != 2'b10 ) 
            led_out <= 0;
        else if ( enable ) begin
            if ( led_out[0] )
                led_out <= 0;
            else
                led_out <= 16'b0101_0101_0101_0101;
        end
        else
            led_out <= 0;
    end

endmodule

module PLAY_led_fast (
    input  logic clk,
    input  logic rst,
    input  logic enable,
    input  logic [1:0] state,
    output logic [15:0] led_out
);

    always_ff @( posedge clk, posedge rst ) begin
        if ( rst || state != 2'b10 ) 
            led_out <= 0;
        else if ( enable ) begin
            if ( led_out[15] )
                led_out <= 0;
            else
                led_out <= 16'b1010_1010_1010_1010;
        end
        else
            led_out <= 0;
    end

endmodule

module FINAl_led (
    input  logic clk,
    input  logic rst,
    input  logic enable,
    input  logic [1:0] state,
    output logic end_final,
    output logic [15:0] led_out
);

    logic [2:0] flash_cnt;

    always_ff @( posedge clk, posedge rst ) begin
        if ( rst || state != 2'b11 ) begin
            end_final <= 0;
            led_out <= 0;
            flash_cnt <= 0;
        end else if ( flash_cnt == 6 ) 
            end_final <= 1;
        else if ( enable ) begin
            if ( led_out[0] == 0 ) begin
                led_out <= {16{1'b1}};
            end else begin
                led_out <= 0;
            end
            flash_cnt <= flash_cnt + 1;
        end
    end

endmodule

module lab3_practice (
    input logic clk,
    input logic rst,        // SW15
    input logic slow,       // SW0
    input logic fast,       // SW1
    input logic end_light,  // SW2 
    output logic [15:0] led
);

    // led_out
    logic [15:0] load_out, play_out, final_out;
    logic [15:0] slow_out, fast_out;

    // States
    logic [1:0] state, next_state;
    logic end_load, end_final;
    parameter INIT  = 2'b00;
    parameter LOAD  = 2'b01;
    parameter PLAY  = 2'b10;
    parameter FINAL = 2'b11;

    // Timers
    logic p25_enable, p25_clk;
    logic p5_enable, p5_clk;

    assign p25_enable = (state == LOAD);
    assign p5_enable  = (state == FINAL);        
    timer #(.COUNT(5)) p25_timer (.clk(clk), .rst(rst), .enable(p25_enable), .tick(p25_clk));
    timer #(.COUNT(10)) p5_timer  (.clk(clk), .rst(rst), .enable(p5_enable), .tick(p5_clk));

    // Div clock
    logic div_28_clk, div_27_clk;
    logic play_enable;

    assign play_enable = (state == PLAY);
    clock_divider #(.n(28)) d28(.clk(clk), .rst(rst), .enable(play_enable), .clk_div(div_28_clk));
    clock_divider #(.n(27)) d27(.clk(clk), .rst(rst), .enable(play_enable), .clk_div(div_27_clk));

    // State register
    always_ff @( posedge clk, posedge rst ) begin
        if ( rst ) begin
            state <= INIT;
        end else begin 
            state <= next_state;
        end
    end

    // Next state logic 
    always_comb begin
        next_state = state;

        case (state) 
            INIT: begin
                next_state = LOAD;
            end
            LOAD: begin
                if ( end_load ) 
                    next_state = PLAY;
            end
            PLAY: begin
                if ( end_light )
                    next_state = FINAL;
            end
            FINAL: begin
                if ( end_final )
                    next_state = INIT;
            end
            default: next_state = INIT;
        endcase
    end

    LOAD_led      my_load (.clk(clk), .rst(rst), .enable(p25_clk), .state(state), .end_load(end_load), .led_out(load_out));
    PLAY_led_fast my_fast (.clk(div_27_clk), .rst(rst), .enable(fast), .state(state), .led_out(fast_out));
    PLAY_led_slow my_slow (.clk(div_28_clk), .rst(rst), .enable(slow), .state(state), .led_out(slow_out));
    FINAl_led     my_final(.clk(clk), .rst(rst), .enable(p5_clk), .state(state), .end_final(end_final), .led_out(final_out));
    assign play_out = fast_out | slow_out;
    
    mux my_mux(.in0({16{1'b1}}), .in1(load_out), .in2(play_out), .in3(final_out), .sel(state), .out(led));

endmodule

module timer #(
    parameter integer COUNT = 100_000_000
)(
    input logic clk,
    input logic rst,
    input logic enable,
    output logic tick
);

    logic [31:0] num;
    logic [31:0] next_num;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            num <= 32'd0;
        end else begin
            num <= next_num;
        end
    end

    assign next_num = (enable == 1'b0) ? 32'd0 :
                      (num == COUNT - 1) ? 32'd0 :
                      num + 1'b1;
    assign tick = enable && (num == COUNT - 1);
endmodule

module clock_divider #(
    parameter n = 10
)(
    input logic clk,
    input logic rst,
    input logic enable,
    output logic clk_div
);

    logic [n-1:0] num;
    logic [n-1:0] next_num;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            num <= {n{1'b0}};
        end else begin
            num <= next_num;
        end
    end

    assign next_num = (enable == 1'b1) ? num + 1'b1 : {n{1'b0}};
    assign clk_div = num[n-1];
endmodule
